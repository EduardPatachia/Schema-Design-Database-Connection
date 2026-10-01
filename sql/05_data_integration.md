# Real-data integration
## 1. The two datasets

| | **A: openFDA Drug Shortages** | **B: BDPM, "Disponibilité des spécialités" (France)** |
|---|---|---|
| Publisher | U.S. Food and Drug Administration | ANSM (French medicines agency), via the Base de données publique des médicaments |
| Access | `https://api.fda.gov/drug/shortages.json` (JSON, no key) | Tab-separated files from `https://base-donnees-publique.medicaments.gouv.fr/telechargement` (no registration) |
| Publication date | Rolling: refreshed daily, covers 2012 onwards. The exact `meta.last_updated` at download time is stored in `data_source.version_note` | Rolling: refreshed monthly. The download page showed 29/06/2026 as the database update date when checked (the *specialités* file); record the date you see via `--bdpm-update-date` |
| Licence | **CC0 1.0** public-domain dedication (<https://open.fda.gov/terms/>). Attribution not required, requested: "Data provided by the U.S. Food and Drug Administration (https://open.fda.gov)" | **Licence Ouverte / Open Licence v2.0** (listed as "LOv2" on BioPortal's BDPM entry). The BDPM download page additionally requires: do not alter the data or distort its meaning, cite the source and the update date. **Confirm the licence line on the download page before submitting.** |
| Size | About 1,700 records per third-party descriptions of the feed (one record per drug presentation / NDC); confirm from `manifest.json` | Thousands of rows in `CIS_CIP_Dispo_Spec.txt` (one per CIS or CIP13); confirm from `manifest.json` |
| Files used | `fda_shortages.json` | `CIS_CIP_Dispo_Spec.txt` (status), `CIS_bdpm.txt` (name, form, holder), `CIS_COMPO_bdpm.txt` (active substance, dose), `CIS_MITM.txt` (ATC code) |

**Complementary, and A ⊄ B.** A is US-only and contains resolved shortages with
dates; B is France-only and contains only current rupture/tension notices (it
has the rupture vs. tension distinction that A lacks) plus ATC codes for
major-therapeutic-interest drugs. Each has records the other cannot have
(different country, different statuses, different attributes). They overlap
only where the same substance, form and strength is short in both countries
(query 6), so neither is a subset of the other.

**Neither dataset covers** `facility`, `facility_report` or `alternative`
(none of them is in the sources). Those tables keep their seed rows only, which
the documentation of query 2 and 5 reflects. Both datasets are intended to
exceed 50 unique rows; the loader prints a warning if `loaded < 50`.

Considered and rejected: the EMA shortages catalogue (covers only shortages
EMA itself assessed, which are few, and no bulk download was found) and ASHP's
list (no open licence or API).

## 2. Mapping to the schema

| Schema | openFDA | BDPM |
|---|---|---|
| `country` / `authority` | United States / FDA (added by `04_data_sources.sql`) | France / ANSM (already seeded) |
| `medicine.name` | `generic_name`, with embedded form stripped, accent-folded, US→INN synonyms | Active substance(s) (`SA` rows of `CIS_COMPO`), joined with ` + ` |
| `medicine.form` | `dosage_form` | French form translated to English (`FORM_FR_EN` map) |
| `medicine.strength` | `strength[]` | dose column of `CIS_COMPO` |
| `medicine.atc_code` | not available (NULL) | `CIS_MITM.txt` where present, else NULL |
| `manufacturer` / `produces` | `company_name` | `Titulaire(s)` of the CIS |
| `shortage.start_date` | `initial_posting_date` | `DateDebut` (falls back to update date) |
| `shortage.end_date` | NULL if Current; `update_date` if Resolved (a proxy) | always NULL (only statuses 1 and 2 are loaded) |
| `shortage.severity` | NULL (not provided) | NULL (not provided) |
| `shortage.supply_status` | NULL | `Shortage` (code 1) or `Supply constraint` (code 2) |
| `shortage.reason` | `shortage_reason` / `resolved_note` if present | NULL (not published) |

Records are **per presentation** in both sources but `shortage` is **per
medicine**, so they are collapsed onto `(name, form, strength, ongoing|resolved)`.
One medicine can therefore have one ongoing and one resolved row.

## 3. How to run it

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p medicine_shortage_tracker < sql/02_seed.sql
mysql -u root -p medicine_shortage_tracker < sql/04_data_sources.sql

cd src
python etl_test_clean.py                           # cleaning rules self-test
python etl_download.py                             # -> data/raw/ + manifest.json
python etl_load.py --bdpm-update-date DD/MM/YYYY   # -> MySQL + data/rejects/*.csv
python run_queries.py                              # -> docs/query_results.md
```

Commit `data/raw/` (unaltered downloads + `manifest.json` with SHA-256) and
`data/rejects/`; they are the audit trail. The BDPM URL pattern in
`etl_download.py` could not be tested; if a download 404s, save the file by hand
from the download page into `data/raw/` under the same name.

## 4. Data-quality checklist

"Source documentation" = what the field docs or format PDF say. "To confirm" =
check on the real file and correct this table.

### 4.1 How is missing data reported?

| | openFDA | BDPM |
|---|---|---|
| Documented behaviour | Optional fields are omitted from the JSON record; some arrive as empty strings or empty arrays (to confirm) | Empty field between tabs. The format PDF states `CIP13` is left empty when *all* presentations of a product are affected |
| Handling | `is_missing()` treats absent, `""`, `[]`, `N/A`, `null`, `-`, `unknown` alike | same |
| Consequence | Missing `generic_name` or `initial_posting_date` → record rejected. Missing form or strength → stored as the sentinel `Unspecified` (NOT NULL columns, and `UNIQUE` ignores NULLs so a NULL would not de-duplicate) | Missing start date → falls back to the update date, else rejected. Missing `CIP13` is normal (CIS-level notice) |
| Not in the data at all | severity, ATC (FDA), reason (BDPM), manufacturer HQ country | severity, reason, HQ country |

### 4.2 How are dates formatted?

| | openFDA | BDPM |
|---|---|---|
| Format | `MM/DD/YYYY` (to confirm on a real record) | `DD/MM/YYYY` (format PDF) |
| Pitfall | `03/04/2026` is 4 March in one source and 3 April in the other, so `parse_date()` takes an explicit format per source | same |
| Checks | Unparseable, impossible (31/02) or implausible (before 1990, after next year) → treated as missing | same |
| Semantics | Resolved shortages have no end date; `update_date` is used as a proxy | For notices before 06/10/2023 "start date" is the *update* date, not the true start (format PDF). Start dates of old notices are therefore approximate |
| Output | ISO `YYYY-MM-DD` for MySQL `DATE` | same |

### 4.3 Are there duplicate records?

| | openFDA | BDPM |
|---|---|---|
| Expected | Yes by design: one record per NDC presentation, so one medicine appears many times (different packagers/labelers) | Yes: several CIS (brand and generics) share one active substance, form and strength; several CIP13 per CIS |
| Handling | Collapsed in `aggregate()` to one shortage per medicine and episode kind; earliest start kept; companies unioned into `produces`. `stats.shortages_after_dedup` vs `presentations_kept` gives the reduction | same |
| Idempotency | `UNIQUE(source_id, source_ref)` (SHA-1 of the normalised key) + upserts: re-running the loader changes nothing | same |
| Cross-source | The same drug in both datasets is intentionally one `medicine` row (upsert on `UNIQUE(name, form, strength)`), with separate `shortage` rows per country | same |

### 4.4 Are there inconsistent naming conventions?

| Issue | Example | Handling |
|---|---|---|
| Case | FDA mixed case, BDPM `UPPER CASE` | folded, then Title Case |
| Accents | `Paracétamol` | `unicodedata` accent folding |
| Language | `comprimé pelliculé` vs `Tablet, Film Coated` | `FORM_FR_EN` map; unmapped forms are kept (folded) and show up as non-matching forms |
| USAN vs INN | acetaminophen / paracetamol, epinephrine / adrenaline, albuterol / salbutamol | `INN_SYNONYMS` map (8 pairs; extend it as needed) |
| Form inside the name | A third-party sample of the FDA feed shows names like "Lisdexamfetamine Dimesylate Tablet, Chewable" (to confirm) | form suffix stripped when it equals `dosage_form` |
| Strength notation | `500 MG`, `500mg`, `100 Units/mL`, `µg` vs `mcg` | lower-case, no spaces, `units`→`u`, `µg`→`mcg` |
| Company names | `Teva Pharmaceuticals USA, Inc.` | punctuation and legal suffixes (Inc, LLC, SA, SAS, GmbH …) removed, Title Case |
| Salts | `Levothyroxine Sodium` vs `LEVOTHYROXINE SODIQUE` | **not** handled; these stay separate medicines (known limitation) |

## 5. Schema changes (step 7)

The loader writes every failed row, with MySQL's error, to `data/rejects/`.
The changes below were made **in anticipation** of the following violations,
derived from the documented fields; after your run, check the rejects files
for any that remain.

| # | Change | Violation it prevents |
|---|---|---|
| 1 | `shortage.severity` now nullable | Neither source grades severity; `NOT NULL` would reject every real row or force invented values |
| 2 | `manufacturer.hq_country_id` nullable | Neither source gives HQ country (error 1048 / forced fabrication) |
| 3 | `medicine.name` 200, `form` 100, `strength` 150 | Data too long (error 1406) for combination products and FDA forms such as "Injection, Powder, Lyophilized, For Solution" |
| 4 | New table `data_source` + `shortage.source_id`, `source_ref`, `UNIQUE(source_id, source_ref)` | Re-running the load would duplicate shortages; also records licence/retrieval date and separates mock from real rows |
| 5 | New `shortage.supply_status` ENUM | BDPM's rupture/tension distinction had no column |
| 6 | `04_data_sources.sql` adds authority FDA | `shortage.authority_id` is NOT NULL and no US authority existed |
| 7 | Cleaner rejects `end < start` before MySQL does | `chk_shortage_dates` would reject it (error 3819); rejecting earlier gives a readable reason |
| 8 | Sentinel `Unspecified` for missing form/strength | `UNIQUE(name, form, strength)` treats NULLs as distinct, so duplicates would slip through if the columns were nullable |

Constraints kept unchanged on purpose: all FKs and referential actions, the
`UNIQUE` keys, the ENUMs on `facility.type`, the `alternative` self-check. Update
`00_relational_schema.md` to add DATA_SOURCE and the changed columns.

## 6. Re-running the example queries (steps 13-14)

`python run_queries.py` writes `docs/query_results.md`. What changed in each
query and what to check in the output:

| Query | Problem with real data | Change | Check |
|---|---|---|---|
| Q1 countries by ongoing shortages | `FIELD()` returns 0 for NULL severity, which would pull every real country's average toward 0 | `CASE` score, plus `rows_with_severity` column | US and France should lead the count; `avg_severity_score` NULL for them is expected, not a bug |
| Q2 alternatives | Row repetition per country, and "available" ignored location | `DISTINCT`, availability judged in the same country, country column added | Only seeded medicines appear: `alternative` has no real data |
| Q3 manufacturers in >1 country | None | Added tiebreaker | Expect manufacturers that exist in both `produces` sets or whose medicine is short in US and France |
| Q4 resolution time | FDA end date is a proxy; BDPM rows never resolved | Grouped by source, NULL severity labelled "Not graded" | Durations of the FDA group are "posted → last update", say so in the write-up |
| Q5 top reporting facility | None | Unchanged | Only seed shortages appear (no facility data in A or B) |
| Q6 (new) in both US and France | n/a | New | If it returns 0 rows, normalisation did not align forms/strengths. Compare `SELECT DISTINCT form FROM medicine` for the two countries and extend `FORM_FR_EN` |

Sanity checks to run after loading (paste the outputs into the report):

```sql
SELECT ds.name, COUNT(*) AS shortages, SUM(end_date IS NULL) AS ongoing
FROM shortage s JOIN data_source ds USING (source_id) GROUP BY ds.name;

SELECT COUNT(*) AS medicines, COUNT(atc_code) AS with_atc,
       SUM(strength = 'Unspecified') AS no_strength, SUM(form = 'Unspecified') AS no_form
FROM medicine;

SELECT COUNT(*) AS violating_dates FROM shortage WHERE end_date < start_date;   -- must be 0
SELECT COUNT(*) AS orphans FROM shortage s LEFT JOIN medicine m USING (medicine_id)
WHERE m.medicine_id IS NULL;                                                      -- must be 0
```

## 7. Known limitations (state these in the report)

- `end_date` for FDA-resolved shortages is a proxy, so durations are indicative.
- BDPM statuses 3 (discontinued) and 4 (back in stock) are not loaded: they carry no start date for the underlying shortage.
- One ongoing and one resolved row per medicine per source; several distinct past episodes merge into one resolved row.
- Salt names, brand-name combos and form translations are only partly harmonised, so some real overlap between A and B will be missed.
- BDPM terms say not to alter data or distort its meaning. Our normalisation is documented, reversible (raw files are committed), and does not change meaning, but mention it.
