# Week 2: data modelling

## Scope

The database should let health authorities and researchers track which
medicines are in shortage, in which countries, who manufactures them, which
alternatives exist, and how hospitals and pharmacies experience shortages.

The original model contains six main entities: `country`, `authority`,
`manufacturer`, `medicine`, `facility`, and `shortage`. The many-to-many
relationships are stored in `produces`, `alternative`, and `facility_report`.
The full diagram is shown in the main [README](../README.md#entity-relationship-diagram).

## Normalisation used in the original design

### First normal form (1NF)

The first flat-table example stored several manufacturers in one comma-separated
field. We separated manufacturers into their own table and used the `produces`
bridge table. This keeps each field atomic and makes manufacturers queryable.

### Second normal form (2NF)

In the example relation with `(medicine_id, country_id)` as a combined key,
`medicine_name` depended only on `medicine_id`. We moved medicine details to the
`medicine` table so they are stored once.

### Third normal form (3NF)

Authority name and authority country depended on `authority_id`, rather than
directly on a shortage. We moved those details to the `authority` table and
referenced the authority with a foreign key.

## Assignment 5 update after using real data

The real datasets introduced two new types of information:

- `data_source` stores the source name, URL, licence, update note, and retrieval
  date instead of repeating these values for every shortage.
- `reported_company` and `shortage_company` store the companies named in source
  notices. We kept these separate from `manufacturer`, because a reported
  company or marketing-authorisation holder is not always the physical producer.

These additions are normalized: each source and company is stored once and
linked by foreign keys.

One limitation remains in the original shortage relation. It stores both
`authority_id` and `country_id`, while each national authority already belongs
to one country. This creates the dependency
`shortage_id -> authority_id -> country_id`. The data still loads consistently,
but a later version could remove `country_id` from `shortage` and obtain it
through `authority`. We kept the original field in Assignment 5 because it is
used throughout the Week 3 schema and queries, and recorded the limitation here.

## Final-week update

After peer review, the schema (v3) adds a composite foreign key from
`shortage(authority_id, country_id)` to `authority(authority_id, country_id)`.
A shortage can no longer be stored with a country that differs from its
authority's country, so the redundant value cannot become inconsistent.
The redundancy itself remains, as described above.
