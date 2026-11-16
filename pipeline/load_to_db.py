#!/usr/bin/env python3
"""
Load parsed ESCOM data into Postgres.

Usage:
    python load_to_db.py <data/week-label-dir>
    python load_to_db.py --latest

The latest mode selects the newest parsed week under data/. DATABASE_URL is
read from the environment or .env. Programme and power-window records are
upserted; locations are replaced with the selected week's data.
"""
import argparse
import csv
import json
import re
import sys
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv
import os

load_dotenv()

HERE = Path(__file__).resolve().parent
DATA_DIR = HERE.parent / "data"


def latest_week_dir():
    candidates = []
    for d in DATA_DIR.iterdir():
        if not d.is_dir() or not (d / "metadata.json").exists():
            continue
        m = re.match(r"(\d{4}-\d{2}-\d{2})", d.name)
        if m:
            candidates.append((m.group(1), d))
    if not candidates:
        raise SystemExit("no week directories found under data/")
    candidates.sort(key=lambda c: c[0])
    return candidates[-1][1]


def parse_week_bounds(dir_name):
    parts = dir_name.split("_to_")
    start = parts[0]
    end = parts[1] if len(parts) > 1 else parts[0]
    return start, end


DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def to_iso_date(date_text):
    # parse_escom_pdf.py already normalizes dates to ISO; this just validates it.
    if not date_text or not DATE_RE.match(date_text):
        raise ValueError(f"expected an ISO date (YYYY-MM-DD), got {date_text!r}")
    return date_text


def to_sql_time(hhmm):
    # e.g. "04h30" -> "04:30:00"
    m = re.match(r"^(\d{2})h(\d{2})$", hhmm)
    if not m:
        raise ValueError(f"unexpected time format: {hhmm!r}")
    return f"{m.group(1)}:{m.group(2)}:00"


def load_week(conn, week_dir: Path):
    metadata = json.loads((week_dir / "metadata.json").read_text())
    week_label = week_dir.name
    week_start, week_end = parse_week_bounds(week_label)

    with conn.cursor() as cur:
        cur.execute(
            """
            insert into programmes (week_label, title, issue_date, week_start, week_end)
            values (%s, %s, %s, %s, %s)
            on conflict (week_label) do update set
              title = excluded.title,
              issue_date = excluded.issue_date,
              week_start = excluded.week_start,
              week_end = excluded.week_end
            returning id
            """,
            (week_label, metadata.get("title"), metadata.get("issue_date"), week_start, week_end),
        )
        programme_id = cur.fetchone()[0]

        # power_windows: upsert on (date, subgroup, slot_index)
        rows = []
        with open(week_dir / "power_windows.csv", newline="") as f:
            for r in csv.DictReader(f):
                rows.append((
                    programme_id,
                    to_iso_date(r["date"]),
                    r["subgroup"],
                    int(r["slot_index"]),
                    to_sql_time(r["start_time"]),
                    to_sql_time(r["end_time"]),
                    r["status"],
                ))
        execute_values(
            cur,
            """
            insert into power_windows
              (programme_id, date, subgroup, slot_index, start_time, end_time, status)
            values %s
            on conflict (date, subgroup, slot_index) do update set
              programme_id = excluded.programme_id,
              start_time = excluded.start_time,
              end_time = excluded.end_time,
              status = excluded.status
            """,
            rows,
        )

        # locations: reference data, only the latest snapshot matters (no history
        # needed) - delete ALL prior rows, not just this programme's, otherwise
        # every earlier week's locations accumulate forever and searches return
        # the same place many times over (one row per week it was ever loaded).
        cur.execute("delete from locations")
        loc_rows = []
        with open(week_dir / "locations.csv", newline="") as f:
            for r in csv.DictReader(f):
                loc_rows.append((programme_id, r["group"], r["region"], r["location"], r["affected_areas"]))
        if loc_rows:
            execute_values(
                cur,
                """
                insert into locations (programme_id, group_code, region, location, affected_areas)
                values %s
                """,
                loc_rows,
            )

    conn.commit()
    return len(rows), len(loc_rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("week_dir", nargs="?", help="path to a data/<week-label> directory")
    ap.add_argument("--latest", action="store_true", help="auto-pick the newest week dir")
    args = ap.parse_args()

    if args.latest:
        week_dir = latest_week_dir()
    elif args.week_dir:
        week_dir = Path(args.week_dir).resolve()
    else:
        ap.error("pass a week dir or --latest")

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise SystemExit("DATABASE_URL is not set (check your .env)")

    conn = psycopg2.connect(database_url)
    try:
        n_windows, n_locations = load_week(conn, week_dir)
    finally:
        conn.close()

    print(f"loaded {week_dir.name}: {n_windows} power_windows rows, {n_locations} locations rows")


if __name__ == "__main__":
    main()
