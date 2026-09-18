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
- Same 1:N treatment: the HQ country is an FK on the manufacturer.

**MEDICINE**(**medicine_id**, name, atc_code, form, strength)
- `(name, form, strength)` is unique — the same drug in a different form or
  strength is a different row (e.g. Amoxicillin capsule vs. suspension).

**FACILITY**(**facility_id**, name, type, country_id → country.country_id)
- `type` is restricted to `Pharmacy` / `Hospital`.

**SHORTAGE**(**shortage_id**, medicine_id → medicine.medicine_id,
country_id → country.country_id, authority_id → authority.authority_id,
start_date, end_date, severity, reason)
- A shortage is one medicine, in one country, reported by one authority, so
  all three become FKs on this relation.
- `end_date IS NULL` means the shortage is still ongoing.

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

## Referential actions

| Relationship | ON DELETE | Why |
|---|---|---|
| authority, manufacturer, facility, shortage → country | RESTRICT | A country should never be removed while records still depend on it. |
| shortage → medicine / authority | RESTRICT | Shortage history must not be silently lost. |
| produces, alternative → manufacturer / medicine | CASCADE | Pure link rows; meaningless once either side is gone. |
| facility_report → facility / shortage | CASCADE | A report has no meaning without the shortage it reports on. |

All FKs use `ON UPDATE CASCADE` so surrogate-key changes propagate.
