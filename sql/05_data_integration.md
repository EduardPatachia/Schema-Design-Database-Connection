# Assignment 5: real-data integration

## 1. The two datasets

| | **A: openFDA Drug Shortages** | **B: BDPM, "Disponibilité des spécialités" (France)** |
|---|---|---|
| Publisher | U.S. Food and Drug Administration | ANSM (French medicines agency), via the Base de données publique des médicaments |
| Access | `https://api.fda.gov/drug/shortages.json` (JSON, no key) | Tab-separated files from `https://base-donnees-publique.medicaments.gouv.fr/telechargement` (no registration) |
| Publication date | Rolling daily feed; `meta.last_updated` was **30/09/2026** | Shortage file **28/09/2026**; product and composition files **29/09/2026**; MITM file **03/06/2026** |
| Licence | **CC0 1.0** public-domain dedication ([openFDA licence](https://open.fda.gov/license/)). Requested attribution: "Data provided by the U.S. Food and Drug Administration (https://open.fda.gov)" | **Licence Ouverte / Open Licence, October 2011** ([licence PDF](https://base-donnees-publique.medicaments.gouv.fr/docs/telechargement/licence_bdpm.pdf)). Reuse must cite BDPM and the update date. |
| Size downloaded | 1,594 presentation records, producing **74 unique shortage rows** | 703 availability notices, producing **298 unique shortage rows** |
| Files used | `fda_shortages.json` | `CIS_CIP_Dispo_Spec.txt` (status), `CIS_bdpm.txt` (name, form, holder), `CIS_COMPO_bdpm.txt` (active substance, dose), `CIS_MITM.txt` (ATC code) |

Both sources are open, free, and require no registration. The raw snapshot was
downloaded on 1 October 2026. Exact hashes and retrieval time are stored in
[`data/raw/manifest.json`](../data/raw/manifest.json).

**Complementary, and A ⊄ B.** The French BDPM is the national EU source and
openFDA is used as a comparison with another reporting system. openFDA includes
current and resolved entries, dates, and reasons. BDPM distinguishes stock
shortages from supply constraints and provides composition and some ATC codes.
The markets, identifiers, and attributes differ, so neither dataset is a subset
of the other.

**Neither dataset covers** `facility`, `facility_report`, or `alternative`.
Those tables keep their seed rows. Both datasets exceed the required 50 unique
rows after cleaning and de-duplication.

Considered and rejected: the EMA shortages catalogue only covers shortages
assessed by EMA and provided too few records for the 50-row requirement. ASHP
was rejected because no suitable open licence was found.

## 2. Mapping to the schema

| Schema | openFDA | BDPM |
|---|---|---|
| `country` / `authority` | United States / FDA (added by `04_data_sources.sql`) | France / ANSM (already seeded) |
| `medicine.name` | `generic_name`, with embedded form stripped, accent-folded, US-to-INN synonyms | Active substance rows from `CIS_COMPO`, joined with ` + ` for combinations |
| `medicine.form` | `dosage_form` | French form translated to English using `FORM_FR_EN` |
| `medicine.strength` | Not present as a structured field in this snapshot, so `Unspecified` | Dose column of `CIS_COMPO` |
| `medicine.atc_code` | Not available (NULL) | `CIS_MITM.txt` where present, else NULL |
| `reported_company` | `company_name` | `Titulaire(s)` of the CIS product |
| `shortage.start_date` | `initial_posting_date` | `DateDebut` (falls back to update date) |
| `shortage.end_date` | NULL if Current; `update_date` if Resolved (a proxy) | Always NULL because statuses 1 and 2 are current notices |
| `shortage.severity` | NULL (not provided) | NULL (not provided) |
| `shortage.supply_status` | NULL | `Shortage` (code 1) or `Supply constraint` (code 2) |
| `shortage.reason` | `shortage_reason` or `resolved_note` | NULL (not published) |

Records are per presentation in both sources, while our `shortage` table is per
normalized medicine and episode type. Records are therefore collapsed onto
`(name, form, strength, ongoing|resolved)`. One medicine can have one ongoing
and one resolved row from the same source.

## 3. How to run it

Run these commands from the repository root:

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p medicine_shortage_tracker < sql/02_seed.sql
mysql -u root -p medicine_shortage_tracker < sql/04_data_sources.sql

cp .env.example .env                         # enter local MySQL credentials
python -m pip install -r src/requirements.txt
python src/etl_test_clean.py                  # cleaning-rule checks
python src/etl_load.py --bdpm-update-date 28/09/2026
python src/run_queries.py                     # writes docs/query_results.md
mysql -u root -p medicine_shortage_tracker < sql/06_validation.sql
```

The downloaded snapshot is included, so `etl_download.py` is not required to
reproduce the submitted result. Run it only when collecting a newer snapshot.
The raw data and rejects are kept as the audit trail.

## 4. Data-quality checklist

### 4.1 How is missing data reported?

| | openFDA | BDPM |
|---|---|---|
| Observed behaviour | Optional JSON fields are omitted. `strength` was absent from all 1,594 rows and `dosage_form` from 20. | Missing values are empty fields between tabs. CIP13 was empty in 667 rows, which is allowed when all presentations are affected. |
| Handling | `is_missing()` treats absent, empty, `N/A`, `null`, `-`, and `unknown` as missing. | Same. |
| Consequence | Missing name or start date is rejected. Missing form or strength is stored as `Unspecified`, because these fields are part of a non-null uniqueness key. | Missing start date falls back to the update date, otherwise the record is rejected. Missing CIP13 is accepted. |
| Not supplied | Severity, ATC code, structured strength | Severity and reason |

No severity values were invented. This is why the real-data severity averages
in Query 1 are NULL.

### 4.2 How are dates formatted?

| | openFDA | BDPM |
|---|---|---|
| Format | `MM/DD/YYYY` | `DD/MM/YYYY` |
| Pitfall | `03/04/2026` means 4 March | `03/04/2026` means 3 April |
| Checks | Unparseable, impossible, before 1990, or later than next year becomes missing | Same |
| Semantics | A resolved record has no exact end date, so its update date is used as a proxy | For notices before 06/10/2023, the documented start can be the update date rather than the true start |
| Database output | ISO `YYYY-MM-DD` | ISO `YYYY-MM-DD` |

The source-specific format is passed explicitly to `parse_date()` so the two
date orders are not mixed up.

### 4.3 Are there duplicate records?

| | openFDA | BDPM |
|---|---|---|
| Expected duplicates | One shortage medicine can have many NDC presentations | Several CIS products and CIP13 presentations can share one active substance, form, and strength |
| Before de-duplication | 1,160 current/resolved presentation rows kept | 552 rupture/tension rows kept |
| After de-duplication | **74 shortage rows** | **298 shortage rows** |
| Handling | `aggregate()` keeps the earliest start date and combines reported companies | Same |
| Idempotency | `UNIQUE(source_id, source_ref)` plus upserts prevents duplicate rows when rerun | Same |

The complete loader was run twice. The counts remained 74 and 298.

### 4.4 Are there inconsistent naming conventions?

| Issue | Example | Handling |
|---|---|---|
| Case | FDA mixed case, BDPM upper case | Folded, then converted to title case |
| Accents | `Paracétamol` | Accent folding |
| Language | `comprimé pelliculé` / `Tablet, Film Coated` | Common French forms translated with `FORM_FR_EN`; unknown forms are kept |
| USAN / INN | acetaminophen / paracetamol, epinephrine / adrenaline | Eight common names mapped with `INN_SYNONYMS` |
| Form inside the name | `Lisdexamfetamine Dimesylate Tablet, Chewable` | Matching form suffix removed from the name |
| Strength notation | `500 MG`, `500mg`, `100 Units/mL`, `µg` | Spaces/case normalized, `units` to `u`, and `µg` to `mcg` |
| Company names | `Teva Pharmaceuticals USA, Inc.` | Punctuation and common legal suffixes removed |
| Known limitation | Different salt and brand names | Some equivalent medicines remain separate |

## 5. Schema and constraint changes

The loader writes records that cannot be integrated to `data/rejects/` with a
reason. These changes were needed after checking the real files:

| # | Change | Reason |
|---|---|---|
| 1 | `shortage.severity` is nullable | Neither source grades severity; keeping NOT NULL would require invented values |
| 2 | Wider medicine name, form, and strength columns | Combination products and long form names exceeded the Week 3 limits |
| 3 | New `data_source` table and `shortage.source_id/source_ref` | Stores provenance and prevents duplicate imports |
| 4 | New `shortage.supply_status` | Keeps BDPM's shortage/supply-constraint distinction |
| 5 | New `reported_company` and `shortage_company` tables | Source company or licence-holder names are not necessarily verified manufacturers |
| 6 | FDA authority added in `04_data_sources.sql` | Every shortage requires an authority |
| 7 | Cleaner rejects end dates before start dates | Prevents a readable source error from becoming a database constraint error |
| 8 | `Unspecified` sentinel for missing form or strength | Prevents NULL values from bypassing the medicine uniqueness constraint |
| 9 | Removed cascading updates from the two `alternative` foreign keys | Allows the self-alternative CHECK to run; medicine IDs are stable surrogate keys |

The original `manufacturer` and `produces` tables keep their Week 3 meaning.
Primary keys, foreign keys, the facility and severity enums, unique keys, date
check, and alternative self-check remain in the schema.

Results from the submitted snapshot:

- 74 openFDA and 298 BDPM shortage rows loaded
- 15 BDPM records rejected because their CIS code was absent from the product file
- 0 MySQL rejects
- 0 end dates before start dates
- 0 shortages without a medicine
- Test inserts with an end date before the start date and a self-alternative
  were rejected by their CHECK constraints
- A second import left the row counts unchanged

The rejected identifiers and reasons are in [`data/rejects/`](../data/rejects/).
The executable checks are in [`06_validation.sql`](06_validation.sql).

## 6. Re-running the Week 3 queries

`python src/run_queries.py` writes the exact output to
[`docs/query_results.md`](../docs/query_results.md).

| Query | Real-data issue | Update and result |
|---|---|---|
| Q1 countries by ongoing shortages | Real rows have NULL severity | Uses a CASE score and shows the number of graded rows. France has 298 ongoing rows and the US comparison has 70; both averages are NULL as expected. |
| Q2 alternatives | The original query did not check the country and labelled missing reports as available | Checks the same country and says `No reported shortage`. Only four seed-derived links appear because neither source supplies alternatives. |
| Q3 manufacturers in several countries | Source company names do not prove a physical manufacturing relationship | Runs on the original seed manufacturer links only and returns five rows. |
| Q4 resolution time | FDA uses update date as an end-date proxy; BDPM rows are current | Groups by source and labels missing severity `Not graded`. The FDA start-to-update average is 1,518.8 days and is not treated as an exact resolution duration. |
| Q5 top reporting facility | Neither source provides facility reports | The query remains valid and returns the original 13 seed-derived rows. |
| Q6 shared labels | The sources use different product identifiers and FDA lacks structured strength | A name-only comparison returns Furosemide, Ifosfamide, and Riluzole as candidate overlaps. |

The results are useful for comparing counts and checking which parts of the
original schema the real sources cover. Queries 2, 3, and 5 also show where more
source data is needed instead of creating information that was not published.

## 7. Normalisation and Week 4 reassessment

The new source and company tables are in 3NF: each fact is stored once and
linked through keys. One limitation remains in the original `shortage` table:
`authority_id` determines the authority's country, while `country_id` is also
stored directly in `shortage`. This creates the dependency
`shortage_id -> authority_id -> country_id`. It is documented in the updated
[Week 2 report](../docs/week2_data_modelling.md). A future version could obtain
country through authority or model multi-country authority jurisdiction.

The [Week 4 video and summary](../docs/week4_video_transcript.md) identified
missing stock quantities, patient impact, live updates, country-specific
substitutes, prices, and trade data. The real-data import addresses the move
away from sample-only data, while the remaining future work is:

- Add more national-agency and EMA feeds for wider EU coverage.
- Store separate product presentations and shortage episodes rather than
  collapsing every presentation of a medicine.
- Add verified alternatives and local stock evidence. No shortage report does
  not prove that a medicine is physically available.
- Add patient impact, price, and trade information when openly licensed sources
  are available.
- Add cross-border warnings, hospital/pharmacy alerts, and the multilingual map
  proposed in the video.
