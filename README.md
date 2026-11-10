# ESCOM Malawi loadshedding-programme parser

ESCOM (Malawi's electricity utility) publishes a weekly loadshedding
timetable as a PDF (an Excel export) with two parts:

1. A colour-coded grid: for each day, each customer group (A/B/C
   residential, D/E/F industrial) x 5 time slots, coloured cells mean the
   group has power, black cells mean it doesn't. Groups A/B/C are each
   split in two (A1/A2, B1/B2, C1/C2) and the two halves sometimes take
   turns within the same slot.
2. A "LOAD SHEDDING GROUPS" table mapping each group+region to named
   substations/feeders and the neighbourhoods/areas they cover.

Both parts are plain vector text/drawing objects in the PDF (not a scanned
image), so they can be parsed directly with coordinates - no OCR needed.
Colour is meaningful (see the PDF's own note: GREEN/YELLOW/RED = power on,
BLACK = power off), so a naive text extraction loses the on/off signal and
also reads the group-location table in the wrong order (PDF text objects
are emitted in drawing order, not visual order). `pipeline/parse_escom_pdf.py`
handles both issues: it uses word/line coordinates and the table's own grid
border lines to reconstruct rows, and renders the page to sample each
schedule cell's actual fill colour.

## Usage

```
pipeline/venv/bin/python pipeline/parse_escom_pdf.py <input.pdf> data/<week-label>/
```

(First time: `python3 -m venv pipeline/venv && pipeline/venv/bin/pip install -r pipeline/requirements.txt`)

This writes to the output directory:

- `metadata.json` - title and issue date.
- `schedule_cells.csv` - one row per (date, group, time slot) grid cell, exactly
  as drawn: `date, table_type, group, label, slot_index, start_time, end_time,
  duration, status, fill_color`. `label` is the text actually printed in the
  cell (e.g. `A`, `A1`, or `A2`); `status` is ON/OFF from the sampled colour.
- `power_windows.csv` - a **derived** view: per-subgroup (A1, A2, B1, B2, C1,
  C2, D, E, F) ON/OFF status per slot per day. Derivation rule (not stated
  explicitly in the PDF): a cell labelled with the plain group letter (e.g.
  `A`) applies to both of that group's subgroups; a cell labelled with one
  subgroup (e.g. `A1`) means only that subgroup has the shown status, and the
  unmentioned sibling is assumed ON for that slot, since the grid only ever
  shows one label per cell. This held up against the one week checked but
  is an inference, not an observed fact - treat with proportionate caution
  before relying on it for e.g. automated alerts.
- `locations.csv` - one row per `group, region, location, affected_areas`.
- `source.pdf` - a copy of the input, for provenance.

## How it works / re-deriving coordinates if ESCOM changes the template

The schedule grid is located by searching for duration labels (`"3.5hrs"`
etc.) and single/double-letter group tokens (`A`, `A1`, ...) within the known
y-range, then clustering by position - no coordinates are hardcoded other
than the general search windows (`y` between 140 and 245 for the grid).
Each cell's colour is sampled from a rendered 12x page image, offset away
from both the cell borders and the text glyph (`cx+6, ry+1.1` relative to the
column-centre/row-top anchors) to avoid misreads from antialiasing.

The location table is parsed per 3-column layout (`x` starting at 51.72,
180.38, 309.17pt - standard for this template) using the table's own
horizontal border lines (thin black rects with width > 5pt, height < 1pt) as
row boundaries. This matters because location-name text is vertically
*centred* within a multi-line row (Excel default), so a naive "new row starts
wherever text appears in the left/location column" approach misattributes
~20% of rows; using the real border lines fixes this.

The location table's column x-positions are **auto-detected per PDF**
(`detect_location_columns`, by clustering where its repeated `LOCATION`
sub-header appears) rather than hardcoded - one week's PDF used completely
different column positions than the others, and hardcoding silently
misaligned ~65% of that week's rows (blank location names) before this was
caught.

Several other template quirks turned up only once all 10 backfilled weeks
were re-parsed (not visible from a single week): `DAY_RE` needs to include
Sunday; some weeks write "21:00" instead of "21h00"; two adjacent cell labels
can render with zero whitespace and fuse into one PDF text run (e.g.
`"08h0008h00"`); and day boundaries within a band can't be assumed to be a
fixed "5 columns per day" (a day's overnight slot is sometimes split in two,
and the industrial table's 3rd slot duration coincidentally equals its 1st) -
the only actually-invariant signal is that one day's slot durations always
sum to 24 hours, which is what `extract_schedule` uses now. If ESCOM changes
the template further, re-run the diagnostic scripts this was built with
(column x-dump, `get_drawings()` fill-colour histogram, rendered crops for
visual spot-check) against the new PDF before trusting the output.

## Validation performed

All 10 backfilled weeks (2026-06-23 through 2026-11-07, including several
irregular short notices) parse with zero warnings and were checked
programmatically for internal consistency: no blank/malformed dates or
times, no duplicate `(date, subgroup, slot_index)` keys, and zero blank
location names. The first week processed (2026-11-02..2026-11-07) was also
cross-checked by hand against high-resolution renders of the source page.

## Backend: Postgres + Fastify API

The parsed CSVs are loaded into Postgres (`pipeline/load_to_db.py`) and
served to the mobile app by a Fastify (Node/TypeScript) API in `api/`, which
is the only thing the app talks to - it never talks to Supabase directly.
See `api/README` (package.json scripts) for running it, and
`.github/workflows/weekly-scrape.yml` for how new weeks get scraped, parsed,
and loaded automatically (daily, since ESCOM's publish day varies).

For local development, `docker-compose.yml` runs a local Postgres (seeded
from `db/schema.sql`) and the API together - `docker compose up`. In
production the same API connects to Supabase Postgres instead (via its
*pooled* connection string - see `api/.env.example`), and the database
schema itself is managed with Prisma (`api/prisma/schema.prisma`,
`npm run migrate:dev` / `migrate:deploy`).
