#!/usr/bin/env python3
"""
Parse an ESCOM Malawi loadshedding-programme PDF into structured CSV/JSON data.

Usage:
    python parse_escom_pdf.py <input.pdf> <output_dir>

Produces in <output_dir>:
    metadata.json        - title, date range, issue date, notices
    schedule_cells.csv   - one row per (date, group, time-slot) grid cell, as drawn
    power_windows.csv    - derived per-subgroup ON windows (see README for the inference rule)
    locations.csv        - one row per (group, region, location, affected areas)
    source.pdf           - copy of the input, for provenance

This script assumes the PDF keeps ESCOM's current template:
  - Page 1: a colour-coded grid (3 days x [Residential ABC / Industrial DEF] x 5 time
    slots), followed by a 3-column "LOAD SHEDDING GROUPS" location table.
  - Page 2 (optional): more of the same location table (used for D/E/F groups).
If ESCOM changes the template, the coordinate assumptions below will need updating -
see README.md for how to re-derive them.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import logging
import re
import shutil
from collections import defaultdict
from collections.abc import Iterable, Sequence
from datetime import date, datetime
from pathlib import Path
from typing import Annotated, Literal

import pymupdf as fitz
from pydantic import BaseModel, ConfigDict, StringConstraints

logger = logging.getLogger(__name__)

GROUP_LETTER_RE = re.compile(r"^[A-F][12]?$")
DURATION_RE = re.compile(r"^\d\.\d+hrs$")
HOUR_RE = re.compile(r"^(\d{2})[h:](\d{2})$")  # ESCOM uses both "21h00" and "21:00"
DAY_RE = re.compile(r"^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),$")

ColorName = Literal["red", "green", "orange", "black", "white", "blue", "lightgreen", "gray"]
TableType = Literal["residential", "industrial"]
Status = Literal["ON", "OFF"]

# The string fields below are constrained to match the regexes already used to
# *find* the underlying tokens (GROUP_LETTER_RE, HOUR_RE, DURATION_RE), plus a
# "?" escape hatch for the rare defensive fallback in extract_schedule. This is
# defense-in-depth, not a tightening: anything that fails these patterns was
# already a bug in the extraction above, not a new/valid ESCOM template quirk.
GroupLetter = Annotated[str, StringConstraints(pattern=r"^[A-F]$|^\?$")]
SubgroupLabel = Annotated[str, StringConstraints(pattern=r"^[A-F][12]?$|^\?$")]
HourBoundary = Annotated[str, StringConstraints(pattern=r"^\d{2}h\d{2}$")]
Duration = Annotated[str, StringConstraints(pattern=DURATION_RE.pattern)]


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------


class RecordModel(BaseModel):
    """Base for immutable, CSV/JSON-serializable output records."""

    model_config = ConfigDict(frozen=True)


class ScheduleCell(RecordModel):
    """One (date, group, time-slot) cell of the grid, exactly as drawn."""

    date: date | None
    table_type: TableType
    group: GroupLetter
    label: SubgroupLabel
    slot_index: int
    start_time: HourBoundary | None = None
    end_time: HourBoundary | None = None
    duration: Duration
    status: Status
    fill_color: ColorName


class PowerWindow(RecordModel):
    """Derived, interpreted view: a subgroup's status for one slot of one day."""

    date: date | None
    subgroup: SubgroupLabel
    slot_index: int
    start_time: HourBoundary | None = None
    end_time: HourBoundary | None = None
    status: Status


class LocationRow(RecordModel):
    """One (group, region, location, affected areas) row of the location table."""

    group: str
    region: str
    location: str
    affected_areas: str


class Metadata(RecordModel):
    title: str
    issue_date: str | None = None


def extract_hour_values(text: str) -> list[str]:
    """Normalize a token's text to zero or more 'HHhMM' boundary values.
    Handles the normal case, the ':' variant, and the rare case where two
    adjacent cell labels render with no whitespace between them and fuse into
    one PDF text run (e.g. '08h0008h00' = '08h00' twice, seen at the end of a
    short notice's last day when there's no trailing text to force a gap)."""
    t = text.replace(":", "h")
    if HOUR_RE.match(t):
        return [t]
    half = len(t) // 2
    if half and len(t) % 2 == 0 and t[:half] == t[half:] and HOUR_RE.match(t[:half]):
        return [t[:half], t[:half]]
    return []


# ESCOM's PDFs use at least two different day-header phrasings across weeks:
# "Monday, November 2, 2026" and "Monday, 28 September 2026".
DATE_HEADER_FORMATS = ("%A, %B %d, %Y", "%A, %d %B %Y", "%A, %B %d %Y", "%A %d %B %Y")


def parse_header_date_to_iso(text: str | None) -> str | None:
    """Normalize a day-header text (e.g. 'Monday, November 2, 2026') to 'YYYY-MM-DD'.
    Returns None if it doesn't match any known ESCOM phrasing."""
    if not text:
        return None
    cleaned = re.sub(r"(\d+)(st|nd|rd|th)\b", r"\1", text.strip(), flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned)
    for fmt in DATE_HEADER_FORMATS:
        try:
            return datetime.strptime(cleaned, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None


GROUP_HEADER_RE = re.compile(r"^GROUP\s+(\S+)\s*[–-]\s*(\w+)\s+REGION")

COLOR_REF: dict[tuple[int, int, int], ColorName] = {
    (255, 0, 0): "red",
    (0, 175, 80): "green",
    (255, 192, 0): "orange",
    (0, 0, 0): "black",
    (255, 255, 255): "white",
    (189, 215, 238): "blue",
    (169, 208, 142): "lightgreen",
    (191, 191, 191): "gray",
}


def closest_color_name(rgb: tuple[int, int, int]) -> ColorName:
    best_ref = min(COLOR_REF, key=lambda ref: sum((a - b) ** 2 for a, b in zip(rgb, ref)))
    return COLOR_REF[best_ref]


def cluster_1d(values: Iterable[float], tol: float = 1.5) -> list[float]:
    values = sorted(values)
    groups, cur = [], [values[0]]
    for v in values[1:]:
        if v - cur[-1] < tol:
            cur.append(v)
        else:
            groups.append(cur)
            cur = [v]
    groups.append(cur)
    return [sum(g) / len(g) for g in groups]


# ---------------------------------------------------------------------------
# Schedule grid (page 1)
# ---------------------------------------------------------------------------


# pymupdf's page.get_text("words") row shape: (x0, y0, x1, y1, text, block_no, line_no, word_no)
Word = tuple[float, float, float, float, str, int, int, int]


class PageFillSampler:
    """Looks up the vector fill color covering each schedule-cell sample point."""

    def __init__(self, page: fitz.Page) -> None:
        self._fills = [
            (drawing["rect"], closest_color_name(tuple(round(channel * 255) for channel in drawing["fill"])))
            for drawing in page.get_drawings()
            if drawing["fill"] is not None
        ]

    def sample(self, px: float, py: float) -> ColorName:
        # Drawings are in paint order, so the last covering fill is visible.
        for rect, color_name in reversed(self._fills):
            if rect.x0 <= px <= rect.x1 and rect.y0 <= py <= rect.y1:
                return color_name
        raise ValueError(f"no vector fill found at schedule cell sample point ({px:.2f}, {py:.2f})")


def _duration_tokens_by_band(words: list[Word]) -> dict[int, list[Word]]:
    bands: dict[int, list[Word]] = defaultdict(list)
    for w in words:
        if DURATION_RE.match(w[4]):
            bands[round(w[1])].append(w)
    return bands


def _hour_boundary_tokens(words: list[Word]) -> list[tuple[float, float, str]]:
    """(x0, y0, "HHhMM") for each hour boundary - one word can expand to 2 (see
    extract_hour_values)."""
    return [(w[0], w[1], v) for w in words for v in extract_hour_values(w[4])]


def _group_letter_tokens(words: list[Word]) -> list[Word]:
    # Generous y-bound: just enough to exclude the location table further down the
    # page. Row spacing/table height varies slightly between PDFs (e.g. some weeks
    # drop the F group), so this is deliberately wider than the grid itself.
    return [w for w in words if GROUP_LETTER_RE.match(w[4]) and 150 <= w[1] <= 290]


def _day_header_chunks(words: list[Word]) -> dict[int, list[tuple[float, str]]]:
    """Day-header text lines, split into one (x0, text) chunk per day (a line can
    hold more than one day's header, e.g. a 3-day band)."""
    lines: dict[int, list[Word]] = defaultdict(list)
    for w in words:
        if 140 <= w[1] <= 260:
            lines[round(w[1])].append(w)

    chunks_by_y: dict[int, list[tuple[float, str]]] = {}
    for y, toks in lines.items():
        toks_sorted = sorted(toks, key=lambda w: w[0])
        starts = [i for i, w in enumerate(toks_sorted) if DAY_RE.match(w[4])]
        chunks = [
            (toks_sorted[start][0], " ".join(t[4] for t in toks_sorted[start:end]))
            for start, end in zip(starts, starts[1:] + [len(toks_sorted)])
        ]
        if chunks:
            chunks_by_y[y] = chunks
    return chunks_by_y


def extract_schedule(doc: fitz.Document) -> list[ScheduleCell]:
    page = doc[0]
    words = page.get_text("words")
    sampler = PageFillSampler(page)

    duration_bands = _duration_tokens_by_band(words)
    hour_tokens = _hour_boundary_tokens(words)
    letter_tokens = _group_letter_tokens(words)
    day_header_chunks = _day_header_chunks(words)

    return [
        cell
        for band_y in sorted(duration_bands)
        for cell in _extract_band(
            band_y, duration_bands[band_y], hour_tokens, letter_tokens, day_header_chunks, sampler,
        )
    ]


def _band_columns(duration_tokens: list[Word]) -> list[tuple[float, str]]:
    toks = sorted(duration_tokens, key=lambda w: w[0])
    return [((w[0] + w[2]) / 2, w[4]) for w in toks]


def _band_slot_times(band_y: int, hour_tokens: list[tuple[float, float, str]]) -> list[tuple[str, str]]:
    hours = sorted((h for h in hour_tokens if band_y - 6 <= h[1] <= band_y - 1), key=lambda h: h[0])
    boundaries: list[str] = []
    for _, _, value in hours:
        if not boundaries or boundaries[-1] != value:
            boundaries.append(value)
    return list(zip(boundaries, boundaries[1:]))


def _day_start_indices(cols: list[tuple[float, str]]) -> list[int]:
    """Day boundaries can't be trusted from column position (day-header text isn't
    reliably left-aligned to its day's first column - its x0 just depends on the
    header string's own width) or from a fixed stride of 5 columns (a day can
    have a different slot count, e.g. a split overnight slot gives 6 instead of
    5) or even from a specific duration value always marking a day's start (the
    industrial table's 3rd slot is also "3.5hrs", same as every day's 1st slot).
    The one thing actually invariant: a full day's slot durations always sum to
    24 hours, in every template/irregularity seen so far."""
    indices = [0]
    running_hours = 0.0
    for i, (_, dur_text) in enumerate(cols):
        running_hours += float(dur_text.replace("hrs", ""))
        if abs(running_hours - 24.0) < 0.01:
            running_hours = 0.0
            if i + 1 < len(cols):
                indices.append(i + 1)
    return indices


def _index_columns_by_day(n_cols: int, day_start_indices: list[int]) -> tuple[list[int], list[int]]:
    """For each column: which day it belongs to, and its 1-based slot index
    *within* that day (days can have a different slot count, so this can't be a
    fixed ci % 5)."""
    col_day_idx = [bisect.bisect_right(day_start_indices, ci) - 1 for ci in range(n_cols)]
    col_slot_idx = []
    per_day_counter: dict[int, int] = defaultdict(int)
    for day_num in col_day_idx:
        per_day_counter[day_num] += 1
        col_slot_idx.append(per_day_counter[day_num])
    return col_day_idx, col_slot_idx


def _band_day_dates(
    band_y: int, day_header_chunks: dict[int, list[tuple[float, str]]], n_days: int,
) -> list[str | None]:
    candidate_ys = [y for y in day_header_chunks if y < band_y]
    day_y = max(candidate_ys) if candidate_ys else None
    chunks = sorted(day_header_chunks.get(day_y, []), key=lambda c: c[0])

    if len(chunks) != n_days:
        logger.warning(
            "expected %d day header(s) for band at y=%s, found %d (%r); dates will be missing",
            n_days, band_y, len(chunks), [c[1] for c in chunks],
        )
        return [None] * n_days
    return [parse_header_date_to_iso(c[1]) for c in chunks]


def _closest_label(row_toks: list[Word], cx: float, fallback: str) -> str:
    label_tok = min(row_toks, key=lambda w: abs((w[0] + w[2]) / 2 - cx), default=None)
    return label_tok[4] if label_tok else fallback


def _extract_row(
    ry: float,
    row_letters: list[Word],
    cols: list[tuple[float, str]],
    slot_times: list[tuple[str, str]],
    col_day_idx: list[int],
    col_slot_idx: list[int],
    day_dates: list[str | None],
    table_type: TableType,
    sampler: PageFillSampler,
) -> list[ScheduleCell]:
    row_toks = sorted((w for w in row_letters if abs(w[1] - ry) < 1.5), key=lambda w: w[0])
    base_letter = row_toks[0][4][0] if row_toks else "?"

    cells = []
    for ci, (cx, dur_text) in enumerate(cols):
        color_name = sampler.sample(cx + 6.0, ry + 1.1)
        day_idx = col_day_idx[ci]
        # slot_times is indexed by the column's own flat position in the band, not
        # by its within-day slot number - the two only coincide when every day has
        # the same number of slots.
        start_h, end_h = slot_times[ci] if ci < len(slot_times) else (None, None)

        cells.append(ScheduleCell(
            date=day_dates[day_idx] if day_idx < len(day_dates) else None,
            table_type=table_type,
            group=base_letter,
            label=_closest_label(row_toks, cx, base_letter),
            slot_index=col_slot_idx[ci],
            start_time=start_h,
            end_time=end_h,
            duration=dur_text,
            status="OFF" if color_name == "black" else "ON",
            fill_color=color_name,
        ))
    return cells


def _extract_band(
    band_y: int,
    duration_tokens: list[Word],
    hour_tokens: list[tuple[float, float, str]],
    letter_tokens: list[Word],
    day_header_chunks: dict[int, list[tuple[float, str]]],
    sampler: PageFillSampler,
) -> list[ScheduleCell]:
    cols = _band_columns(duration_tokens)
    slot_times = _band_slot_times(band_y, hour_tokens)

    row_letters = [w for w in letter_tokens if band_y + 1 <= w[1] <= band_y + 22]
    if not row_letters:
        logger.warning("no group-letter rows found for band at y=%s, skipping", band_y)
        return []
    row_ys = sorted(cluster_1d([w[1] for w in row_letters], tol=1.5))

    day_start_indices = _day_start_indices(cols)
    col_day_idx, col_slot_idx = _index_columns_by_day(len(cols), day_start_indices)
    day_dates = _band_day_dates(band_y, day_header_chunks, n_days=len(day_start_indices))

    sample_letters = {w[4][0] for w in row_letters}
    table_type: TableType = "residential" if sample_letters & {"A", "B", "C"} else "industrial"

    return [
        cell
        for ry in row_ys
        for cell in _extract_row(
            ry, row_letters, cols, slot_times, col_day_idx, col_slot_idx, day_dates, table_type, sampler,
        )
    ]


def derive_power_windows(schedule_rows: Sequence[ScheduleCell]) -> list[PowerWindow]:
    """Derived, interpreted view: per-subgroup ON windows per day.

    Inference rule (not explicit in the PDF - see README):
    - A cell labelled with the plain group letter (e.g. "A") applies to ALL of that
      group's subgroups (e.g. A1 and A2 both get this status).
    - A cell labelled with a specific subgroup (e.g. "A1") means only that subgroup
      has the shown status; the unmentioned sibling subgroup is assumed ON for that
      slot (since the grid only ever shows one label per cell).
    Groups D/E/F have no subgroups; D/E/F rows are used as-is.
    """
    SUBGROUPS = {"A": ["A1", "A2"], "B": ["B1", "B2"], "C": ["C1", "C2"]}
    by_date_group: dict[tuple[date | None, str], list[ScheduleCell]] = defaultdict(list)
    for r in schedule_rows:
        by_date_group[(r.date, r.group)].append(r)

    windows: list[PowerWindow] = []
    for (day, group), cells in by_date_group.items():
        cells = sorted(cells, key=lambda r: r.slot_index)
        subgroups = SUBGROUPS.get(group, [group])
        for sub in subgroups:
            for c in cells:
                # unmentioned sibling subgroup (see docstring) is assumed ON
                status = c.status if c.label in (sub, group) else "ON"
                windows.append(PowerWindow(
                    date=day,
                    subgroup=sub,
                    slot_index=c.slot_index,
                    start_time=c.start_time,
                    end_time=c.end_time,
                    status=status,
                ))
    return windows


# ---------------------------------------------------------------------------
# Location tables (page 1 bottom + page 2)
# ---------------------------------------------------------------------------


def detect_location_columns(page: fitz.Page) -> list[float]:
    """Find the x0 of each of the location table's 3 columns, by clustering the
    x-positions where its repeated 'LOCATION' sub-header appears. These column
    positions vary between weeks' PDFs (different table widths/margins), so
    they can't be hardcoded - one observed week sat at x~80/222/368 instead of
    the more common x~52/180/309, and hardcoding the latter silently
    misaligned every row for weeks using the former."""
    words = page.get_text("words")
    xs = [w[0] for w in words if w[4] == "LOCATION"]
    return cluster_1d(xs, tol=5) if xs else []


def get_row_boundaries(page: fitz.Page, ymin: float, xlo: float, xhi: float) -> list[float]:
    ys = set()
    for d in page.get_drawings():
        rect = d.get("rect")
        if rect is None or rect.y0 < ymin - 5:
            continue
        if rect.x0 < xlo - 2 or rect.x0 > xhi + 2:
            continue
        w, h = rect.x1 - rect.x0, rect.y1 - rect.y0
        if h < 1.0 and w > 5:
            ys.add(round(rect.y0, 1))
    return sorted(ys)


def _location_column_ranges(col_starts: list[float]) -> list[tuple[float, float]]:
    bounds = [start - 7 for start in col_starts] + [9999]
    return list(zip(bounds, bounds[1:]))


def _parse_location_row(bucket: list[Word], col_start: float, group: str, region: str) -> LocationRow | None:
    loc_words = sorted((w for w in bucket if w[0] < col_start + 10), key=lambda w: (w[1], w[0]))
    area_words = sorted((w for w in bucket if w[0] >= col_start + 10), key=lambda w: (w[1], w[0]))
    location = " ".join(w[4] for w in loc_words).strip()
    areas = " ".join(w[4] for w in area_words).strip()
    if not location and not areas:
        return None
    return LocationRow(group=group, region=region, location=location, affected_areas=areas)


def _extract_location_column(
    page: fitz.Page, all_words: list[Word], ymin: float, col_start: float, xlo: float, xhi: float,
) -> list[LocationRow]:
    boundaries = [b for b in get_row_boundaries(page, ymin, col_start, col_start + 110) if b >= ymin - 1]
    if not boundaries:
        return []
    if boundaries[0] > ymin:
        boundaries = [ymin] + boundaries
    boundaries.append(boundaries[-1] + 1000)
    col_words = [w for w in all_words if xlo <= w[0] < xhi and w[1] >= ymin - 1]

    rows: list[LocationRow] = []
    current_group = current_region = None
    for y_top, y_bot in zip(boundaries, boundaries[1:]):
        bucket = sorted((w for w in col_words if y_top - 0.5 <= w[1] < y_bot - 0.5), key=lambda w: (w[1], w[0]))
        if not bucket:
            continue
        full_text = " ".join(w[4] for w in bucket)

        header = GROUP_HEADER_RE.match(full_text)
        if header:
            current_group, current_region = header.group(1), header.group(2)
            continue
        if full_text.startswith("LOCATION") and "AFFECTED" in full_text:
            continue
        if current_group is None:
            continue

        row = _parse_location_row(bucket, col_start, current_group, current_region)
        if row is not None:
            rows.append(row)
    return rows


def extract_locations_from_page(page: fitz.Page, ymin: float) -> list[LocationRow]:
    """Find the location table's 3 columns (see detect_location_columns) and parse
    each one's rows independently - columns don't share row boundaries."""
    col_starts = detect_location_columns(page)
    if not col_starts:
        return []

    all_words = page.get_text("words")
    return [
        row
        for col_start, (xlo, xhi) in zip(col_starts, _location_column_ranges(col_starts))
        for row in _extract_location_column(page, all_words, ymin, col_start, xlo, xhi)
    ]


def extract_locations(doc: fitz.Document) -> list[LocationRow]:
    rows = extract_locations_from_page(doc[0], ymin=252)
    if len(doc) > 1:
        rows.extend(extract_locations_from_page(doc[1], ymin=0))
    return rows


# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------


def extract_metadata(doc: fitz.Document) -> Metadata:
    page = doc[0]
    words = page.get_text("words")
    title_words = [w for w in words if w[1] < 85]
    title = " ".join(w[4] for w in sorted(title_words, key=lambda w: (w[1], w[0])))

    issue_date = None
    for w in words:
        if w[4] == "MANAGEMENT":
            line = [x for x in words if abs(x[1] - w[1]) < 1.0]
            issue_date = " ".join(x[4] for x in sorted(line, key=lambda x: x[0]) if x[4] != "MANAGEMENT")
            break

    return Metadata(title=title.strip(), issue_date=issue_date)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def write_csv(path: Path, rows: Sequence[RecordModel], model_cls: type[RecordModel]) -> None:
    """Write `rows` as CSV with a header taken from `model_cls`'s own fields,
    so the header/column set is correct even for an empty `rows` (unlike
    deriving fieldnames from rows[0])."""
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(model_cls.model_fields))
        writer.writeheader()
        for row in rows:
            writer.writerow(row.model_dump(mode="json"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input_pdf", type=Path, help="path to the ESCOM loadshedding PDF")
    parser.add_argument("output_dir", type=Path, help="directory to write metadata.json / *.csv / source.pdf into")
    return parser


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    args = build_arg_parser().parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    with fitz.open(args.input_pdf) as doc:
        metadata = extract_metadata(doc)
        schedule_rows = extract_schedule(doc)
        power_windows = derive_power_windows(schedule_rows)
        location_rows = extract_locations(doc)

    (args.output_dir / "metadata.json").write_text(metadata.model_dump_json(indent=2))
    write_csv(args.output_dir / "schedule_cells.csv", schedule_rows, ScheduleCell)
    write_csv(args.output_dir / "power_windows.csv", power_windows, PowerWindow)
    write_csv(args.output_dir / "locations.csv", location_rows, LocationRow)

    dest_pdf = args.output_dir / "source.pdf"
    if args.input_pdf.resolve() != dest_pdf.resolve():
        shutil.copy(args.input_pdf, dest_pdf)

    print(f"schedule_cells.csv : {len(schedule_rows)} rows")
    print(f"power_windows.csv  : {len(power_windows)} rows")
    print(f"locations.csv      : {len(location_rows)} rows")
    print(f"metadata.json      : {metadata.model_dump()}")


if __name__ == "__main__":
    main()
