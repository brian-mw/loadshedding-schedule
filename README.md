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
