# Brain-dump: the parts no API knows

The CV pulls publications, reports, software and open-data projects automatically
from ORCID and GitHub. Everything below has to come from you. Fill in the CSV
`data/braindump_entries.csv` (same columns as `entries.csv`) and I'll merge it in.

Column reminder: `section, title, loc, institution, start, end, description_1..3, url`

- `start` / `end` are years. Leave `end` **empty** for anything current (renders as "Current").
- `loc` = location (city, country). Optional.
- `institution` = employer / host / who you did it for.

## What I still need from you

1. **Work experience before 2021** (ORCID only has your ETH role from 2021 on):
   - Eawag-Sandec roles, Lars Schöbitz GmbH founding, any consulting. Titles + years.
2. **Education** (ORCID has none):
   - Degrees, institutions, years, field of study.
3. **Courses taught in person (20+)**:
   - You said 20+ in-person courses. List them, or give me the pattern (course name,
     institution, city, year) and I'll expand. If they're all one series, one entry
     with a count is fine (e.g. "R training, 20+ deliveries 2019-2026").
4. **Workshops hosted** (distinct from courses):
   - Title, host/venue, year. The GHE website (ghe-open.ch) has slides for some of
     these; tell me which to pull and I'll harvest titles/dates from there.
5. **Talks / conference presentations** (invited talks, keynotes):
   - The ghe-open.ch site hosts several. Confirm and I'll extract them.
6. **Professional roles - confirm start years**:
   - Data Stewardship Network (ETH): joined which year?
   - SwissRN local node (ETH Zurich): since which year?
7. **gitforsci-ghe** direction: where does this repo live (which org/user)? Not found
   under Global-Health-Engineering by that exact name.
8. **References**: names, titles, affiliations, contact - or "on request".
9. **Language levels**: I guessed German 5 / English 5 / French 2 / Spanish 1. Correct?
