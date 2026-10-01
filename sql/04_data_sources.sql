-- Run after 01_schema.sql and 02_seed.sql, before the Python ETL (src/etl_load.py).
-- Registers the datasets, tags the mock rows so they stay distinguishable, and
-- adds the one authority the seed data lacks (the US regulator).

USE medicine_shortage_tracker;

INSERT INTO data_source (source_id, name, url, license, license_url, version_note) VALUES
    (1, 'Synthetic seed data',
        NULL, 'n/a (invented for teaching)', NULL,
        'Hand-written mock rows from 02_seed.sql'),
    (2, 'openFDA Drug Shortages',
        'https://api.fda.gov/drug/shortages.json',
        'CC0 1.0 Universal (public domain)',
        'https://open.fda.gov/terms/',
        'Updated daily by FDA; exact meta.last_updated is filled in by etl_load.py'),
    (3, 'BDPM - Disponibilite des specialites (ANSM, France)',
        'https://base-donnees-publique.medicaments.gouv.fr/telechargement',
        'Licence Ouverte / Open Licence v2.0 (Etalab)',
        'https://www.etalab.gouv.fr/licence-ouverte-open-licence/',
        'Updated monthly; exact BDPM update date is filled in by etl_load.py');

UPDATE shortage
   SET source_id = 1, source_ref = CONCAT('seed-', shortage_id)
 WHERE source_id IS NULL;

INSERT IGNORE INTO authority (name, country_id) VALUES ('FDA', 13);  -- United States
