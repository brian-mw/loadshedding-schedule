# How it works / re-deriving coordinates if ESCOM changes the template

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

## Derivation rule

(not stated explicitly in the PDF): a cell labelled with the plain group letter (e.g.
`A`) applies to both of that group's subgroups; a cell labelled with one
subgroup (e.g. `A1`) means only that subgroup has the shown status, and the
unmentioned sibling is assumed ON for that slot, since the grid only ever
shows one label per cell. This held up against the one week checked but
is an inference, not an observed fact - treat with proportionate caution
before relying on it for e.g. automated alerts.
