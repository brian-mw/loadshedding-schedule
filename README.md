# ESCOM Malawi loadshedding-programme parser

The project uses `pipeline/parse_escom_pdf.py` to extract structured information from ESCOM Malawi's weekly load-shedding PDF.

It solves two main problems:

- **Colour recognition:** Samples the actual fill colour of schedule cells to determine whether electricity is ON (green, yellow, red) or OFF (black).
- **Table reconstruction:** Uses word coordinates, line positions and grid borders to correctly reconstruct the schedule and the group-location table, which ordinary PDF text extraction reads incorrectly.

The parser handles both the weekly power schedule (including residential subgroups A1/A2, B1/B2 and C1/C2) and the table mapping customer groups to substations, feeders and neighbourhoods.

## How it Works

See [How it works](/docs/how_it_works.md)

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
  C2, D, E, F) ON/OFF status per slot per day.
- `locations.csv` - one row per `group, region, location, affected_areas`.
- `source.pdf` - a copy of the input, for provenance.

## Backend: Postgres + Fastify API

The parsed CSVs are loaded into Postgres (`pipeline/load_to_db.py`) and
served to the Flutter app by a Fastify (Node/TypeScript) API in `api/`, which
is the only thing the app talks to.

## Local Development

`docker-compose.yml` runs a local Postgres (seeded
from `db/schema.sql`) and the API together - `docker compose up`. In
production the same API connects to Supabase Postgres instead (via its
*pooled* connection string - see `api/.env.example`), and the database
schema itself is managed with Prisma (`api/prisma/schema.prisma`,
`npm run migrate:dev` / `migrate:deploy`).
