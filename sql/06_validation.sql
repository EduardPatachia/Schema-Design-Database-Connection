USE medicine_shortage_tracker;

-- Each real dataset must contribute at least 50 unique shortage rows.
SELECT ds.name, COUNT(*) AS shortage_rows
FROM shortage AS s
JOIN data_source AS ds ON ds.source_id = s.source_id
WHERE s.source_id IN (2, 3)
GROUP BY ds.source_id, ds.name;

-- These checks should both return 0.
SELECT COUNT(*) AS invalid_date_ranges
FROM shortage
WHERE end_date < start_date;

SELECT COUNT(*) AS shortages_without_medicine
FROM shortage AS s
LEFT JOIN medicine AS m ON m.medicine_id = s.medicine_id
WHERE m.medicine_id IS NULL;

-- Shows how much missing source data remained after cleaning.
SELECT
    SUM(form = 'Unspecified') AS medicines_without_form,
    SUM(strength = 'Unspecified') AS medicines_without_strength
FROM medicine;
