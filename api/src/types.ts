export interface LocationRow {
  group_code: string;
  region: string;
  location: string;
  affected_areas: string;
}

export interface PowerWindowRow {
  date: string; // YYYY-MM-DD
  subgroup: string;
  slot_index: number;
  start_time: string; // HH:MM:SS
  end_time: string;
  status: 'ON' | 'OFF';
}

export interface ProgrammeRow {
  week_label: string;
  title: string | null;
  issue_date: string | null;
  week_start: string;
  week_end: string;
}
