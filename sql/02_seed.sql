-- Mock data, run after 01_schema.sql. IDs are set explicitly so the FK
-- columns below stay readable instead of relying on insert order.

USE medicine_shortage_tracker;

INSERT INTO country (country_id, name, region) VALUES
    (1,  'Netherlands',    'Western Europe'),
    (2,  'Belgium',        'Western Europe'),
    (3,  'Germany',        'Western Europe'),
    (4,  'France',         'Western Europe'),
    (5,  'Spain',          'Southern Europe'),
    (6,  'Italy',          'Southern Europe'),
    (7,  'Poland',         'Central Europe'),
    (8,  'Sweden',         'Northern Europe'),
    (9,  'Portugal',       'Southern Europe'),
    (10, 'Ireland',        'Northern Europe'),
    (11, 'Slovenia',       'Central Europe'),
    (12, 'Switzerland',    'Non-EU'),
    (13, 'United States',  'Non-EU'),
    (14, 'United Kingdom', 'Non-EU');

INSERT INTO authority (authority_id, name, country_id) VALUES
    (1, 'CBG-MEB',   1),  -- Netherlands
    (2, 'FAMHP',     2),  -- Belgium
    (3, 'BfArM',     3),  -- Germany
    (4, 'ANSM',      4),  -- France
    (5, 'AEMPS',     5),  -- Spain
    (6, 'AIFA',      6),  -- Italy
    (7, 'URPL',      7),  -- Poland
    (8, 'MPA',       8),  -- Sweden (Läkemedelsverket)
    (9, 'INFARMED',  9),  -- Portugal
    (10, 'HPRA',     10); -- Ireland

INSERT INTO manufacturer (manufacturer_id, name, hq_country_id) VALUES
    (1, 'Pfizer',          13), -- United States
    (2, 'Sandoz',          12), -- Switzerland
    (3, 'Teva',            1),  -- Netherlands (EU HQ)
    (4, 'Krka',            11), -- Slovenia
    (5, 'GSK',              14), -- United Kingdom
    (6, 'Sanofi',          4),  -- France
    (7, 'Novartis',        12), -- Switzerland
    (8, 'Bayer',           3);  -- Germany

INSERT INTO medicine (medicine_id, name, atc_code, form, strength) VALUES
    (1,  'Amoxicillin',       'J01CA04', 'Capsule',     '500mg'),
    (2,  'Amoxicillin',       'J01CA04', 'Suspension',  '250mg/5ml'),
    (3,  'Paracetamol',       'N02BE01', 'Tablet',      '500mg'),
    (4,  'Ibuprofen',         'M01AE01', 'Tablet',      '400mg'),
    (5,  'Insulin Glargine',  'A10AE04', 'Injection',   '100u/ml'),
    (6,  'Salbutamol',        'R03AC02', 'Inhaler',     '100mcg'),
    (7,  'Metformin',         'A10BA02', 'Tablet',      '500mg'),
    (8,  'Omeprazole',        'A02BC01', 'Capsule',     '20mg'),
    (9,  'Atorvastatin',      'C10AA05', 'Tablet',      '20mg'),
    (10, 'Levothyroxine',     'H03AA01', 'Tablet',      '50mcg'),
    (11, 'Adrenaline',        'C01CA24', 'Injection',   '1mg/ml'),
    (12, 'Azithromycin',      'J01FA10', 'Tablet',      '250mg');

INSERT INTO facility (facility_id, name, type, country_id) VALUES
    (1,  'Amsterdam UMC',              'Hospital', 1),
    (2,  'De Kring Apotheek',          'Pharmacy', 1),
    (3,  'CHU Brussels',               'Hospital', 2),
    (4,  'Multipharma Bruxelles',      'Pharmacy', 2),
    (5,  'Charite Berlin',             'Hospital', 3),
    (6,  'Hopital Necker Paris',       'Hospital', 4),
    (7,  'Pharmacie Lafayette',        'Pharmacy', 4),
    (8,  'Hospital Clinic Barcelona',  'Hospital', 5),
    (9,  'Farmacia San Marco Milan',   'Pharmacy', 6),
    (10, 'Karolinska Stockholm',       'Hospital', 8);

INSERT INTO shortage (shortage_id, medicine_id, country_id, authority_id, start_date, end_date, severity, reason) VALUES
    (1,  1,  1, 1, '2025-11-03', '2026-01-15', 'High',     'Manufacturing delay at supplier site'),
    (2,  2,  1, 1, '2025-12-01', NULL,         'Critical', 'Sole EU manufacturer halted production'),
    (3,  3,  2, 2, '2025-10-10', '2025-11-20', 'Medium',   'Packaging line shutdown'),
    (4,  5,  2, 2, '2026-01-05', NULL,         'Critical', 'Global raw-material shortage'),
    (5,  6,  3, 3, '2025-09-15', '2025-10-30', 'High',     'Surge in seasonal demand'),
    (6,  7,  3, 3, '2026-02-01', NULL,         'Medium',   'Distribution bottleneck'),
    (7,  4,  4, 4, '2025-08-20', '2025-09-05', 'Low',      'Temporary logistics delay'),
    (8,  8,  4, 4, '2026-03-10', NULL,         'Medium',   'Active ingredient recall'),
    (9,  9,  5, 5, '2025-11-25', '2026-01-10', 'Medium',   'Plant recertification'),
    (10, 10, 5, 5, '2026-02-15', NULL,         'High',     'Quality control failure at manufacturer'),
    (11, 11, 6, 6, '2025-12-10', NULL,         'Critical', 'Export restriction in source country'),
    (12, 1,  6, 6, '2026-01-20', NULL,         'High',     'Regional supply chain disruption'),
    (13, 12, 7, 7, '2025-10-05', '2025-12-01', 'Medium',   'Raw material import delay'),
    (14, 3,  8, 8, '2026-01-08', NULL,         'Low',      'Increased winter demand'),
    (15, 5,  4, 4, '2026-02-20', NULL,         'Critical', 'Sole EU manufacturer halted production');

INSERT INTO produces (manufacturer_id, medicine_id) VALUES
    (1, 1), (1, 3), (1, 5),
    (2, 1), (2, 4), (2, 7), (2, 12),
    (3, 2), (3, 3), (3, 8),
    (4, 3), (4, 4), (4, 7),
    (5, 6), (5, 11),
    (6, 5), (6, 9),
    (7, 9), (7, 10),
    (8, 4), (8, 8), (8, 12);

INSERT INTO alternative (medicine_id, alternative_medicine_id) VALUES
    (3, 4), (4, 3),   -- paracetamol / ibuprofen
    (1, 12), (12, 1), -- amoxicillin / azithromycin
    (1, 2), (2, 1);   -- amoxicillin capsule / suspension

INSERT INTO facility_report (facility_id, shortage_id, report_date) VALUES
    (1, 1,  '2025-11-05'), (2, 1,  '2025-11-06'),
    (1, 2,  '2025-12-02'), (2, 2,  '2025-12-03'), (2, 2, '2026-01-10'),
    (3, 3,  '2025-10-11'),
    (3, 4,  '2026-01-06'), (4, 4,  '2026-01-07'),
    (5, 5,  '2025-09-16'),
    (5, 6,  '2026-02-02'),
    (7, 7,  '2025-08-21'),
    (6, 8,  '2026-03-11'), (7, 8,  '2026-03-12'),
    (8, 9,  '2025-11-26'),
    (8, 10, '2026-02-16'),
    (9, 11, '2025-12-11'), (9, 11, '2026-01-05'),
    (9, 12, '2026-01-21'),
    (10, 14, '2026-01-09'),
    (6, 15, '2026-02-21'), (7, 15, '2026-02-22');
