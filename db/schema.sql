create table if not exists programmes (
  id bigint generated always as identity primary key,
  week_label text not null unique,
  title text,
  issue_date text,
  week_start date not null,
  week_end date not null,
  fetched_at timestamptz not null default now()
);

create table if not exists power_windows (
  id bigint generated always as identity primary key,
  programme_id bigint not null references programmes(id) on delete cascade,
  date date not null,
  subgroup text not null,              -- A1, A2, B1, B2, C1, C2, D, E, F
  slot_index int not null,
  start_time time not null,
  end_time time not null,
  status text not null check (status in ('ON','OFF')),
  unique (date, subgroup, slot_index)  -- re-published/overlapping weeks overwrite cleanly
);
create index if not exists power_windows_subgroup_date_idx on power_windows (subgroup, date);

create table if not exists locations (
  id bigint generated always as identity primary key,
  programme_id bigint references programmes(id),
  group_code text not null,            -- A1, A2, ... F
  region text not null,
  location text not null,
  affected_areas text not null
);
create index if not exists locations_search_idx on locations
  using gin (to_tsvector('english', location || ' ' || affected_areas));
