# Relational schema

The ERD in the README, written out as relations. Primary keys are **bold**,
foreign keys are marked `→ table.column`. This is the mapping that
`01_schema.sql` implements.

## Entity relations

**COUNTRY**(**country_id**, name, region)
- `name` is unique — no two rows for the same country.

**AUTHORITY**(**authority_id**, name, country_id → country.country_id)
- One country has many authorities; each authority belongs to exactly one
  country, so the 1:N relationship is stored as an FK on the N side.
- `(name, country_id)` is unique.

**MANUFACTURER**(**manufacturer_id**, name, hq_country_id → country.country_id)
- Same 1:N treatment: the HQ country is an FK on the manufacturer. This table
  and `PRODUCES` contain teaching seed data only; the real
  feeds identify companies or licence holders, not verified manufacturers.

**MEDICINE**(**medicine_id**, name, atc_code, form, strength)
- `(name, form, strength)` is unique — the same drug in a different form or
  strength is a different row (e.g. Amoxicillin capsule vs. suspension).

**FACILITY**(**facility_id**, name, type, country_id → country.country_id)
- `type` is restricted to `Pharmacy` / `Hospital`.

**DATA_SOURCE**(**source_id**, name, url, license, license_url, version_note,
retrieved_on)
- Distinguishes the synthetic seed, openFDA and French BDPM snapshots.

**SHORTAGE**(**shortage_id**, medicine_id → medicine.medicine_id,
country_id → country.country_id, authority_id → authority.authority_id,
start_date, end_date, severity, supply_status, reason,
source_id → data_source.source_id, source_ref)
- A shortage is one medicine, in one country, reported by one authority, so
  all three become FKs on this relation.
- `end_date IS NULL` means the shortage is still ongoing.
- `severity` is nullable because neither real source grades it. `source_ref`
  is unique within a source and makes re-imports idempotent.
- `country_id` duplicates the country implied by `authority_id` for national
  authorities. This is a **remaining 3NF violation**, documented in
  [`05_data_integration.md`](05_data_integration.md#normalisation-and-week-4-reassessment).
  Since v3, the composite FK `(authority_id, country_id)` →
  `authority(authority_id, country_id)` guarantees that the two agree. It
  replaces the v2 single-column FK on `authority_id`.

**REPORTED_COMPANY**(**company_id**, name)
- A company named in a source notice; this does not assert who made the drug.

## Bridge relations

The three M:N relationships from the ERD cannot be stored as FKs on either
side, so each becomes its own relation with a composite key.

**PRODUCES**(**manufacturer_id** → manufacturer.manufacturer_id,
**medicine_id** → medicine.medicine_id)
- Resolves MANUFACTURER }o--o{ MEDICINE. One manufacturer makes many
  medicines; one medicine is made by many manufacturers.

**ALTERNATIVE**(**medicine_id** → medicine.medicine_id,
**alternative_medicine_id** → medicine.medicine_id)
- A recursive M:N on MEDICINE. Both columns point back at `medicine`, and a
  CHECK constraint stops a medicine being its own alternative. Pairs are
  inserted in both directions so the relation reads symmetrically.

**FACILITY_REPORT**(**report_id**, facility_id → facility.facility_id,
shortage_id → shortage.shortage_id, report_date)
- Resolves FACILITY }o--o{ SHORTAGE. It carries its own attribute
  (`report_date`) and the same facility can report the same shortage on
  several dates, so it gets a surrogate key with
  `(facility_id, shortage_id, report_date)` unique instead of a composite PK.

**SHORTAGE_COMPANY**(**shortage_id** → shortage.shortage_id,
**company_id** → reported_company.company_id)
- Connects each notice to its reported companies or marketing-authorisation
  holders, without treating them as physical manufacturers.

## Referential actions

| Relationship | ON DELETE | Why |
|---|---|---|
| authority, manufacturer, facility, shortage → country | RESTRICT | A country should never be removed while records still depend on it. |
| shortage → medicine / authority | RESTRICT | Shortage history must not be silently lost. |
| shortage (authority_id, country_id) → authority | RESTRICT | v3: a shortage's country must be its authority's country. |
| produces, alternative → manufacturer / medicine | CASCADE | Pure link rows; meaningless once either side is gone. |
| facility_report → facility / shortage | CASCADE | A report has no meaning without the shortage it reports on. |
| shortage → data_source | RESTRICT | Do not erase provenance while shortages depend on it. |
| shortage_company → shortage | CASCADE | Remove notice-company links with the notice. |
| shortage_company → reported_company | RESTRICT | A named company cannot disappear while linked. |

Most FKs use `ON UPDATE CASCADE` so surrogate-key changes propagate. The two
`alternative` FKs omit it because MySQL/MariaDB do not allow the same columns
to use cascading updates and the self-alternative `CHECK` constraint together.
