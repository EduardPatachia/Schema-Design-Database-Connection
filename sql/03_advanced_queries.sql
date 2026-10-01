USE medicine_shortage_tracker;

-- Q1: countries with the most ongoing imported shortages, by severity.
-- Both sources omit severity; AVG ignores NULL and rows_with_severity shows
-- the denominator. Synthetic teaching rows are excluded from this comparison.
SELECT
    c.name                                                   AS country,
    COUNT(*)                                                 AS ongoing_shortages,
    COUNT(s.severity)                                        AS rows_with_severity,
    ROUND(AVG(CASE s.severity WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2
                              WHEN 'High' THEN 3 WHEN 'Critical' THEN 4 END), 2) AS avg_severity_score
FROM shortage AS s
JOIN country AS c ON c.country_id = s.country_id
WHERE s.end_date IS NULL AND s.source_id IN (2, 3)
GROUP BY c.country_id, c.name
ORDER BY ongoing_shortages DESC, avg_severity_score DESC;


-- Q2: for medicines currently short, do their listed alternatives also have
-- a reported shortage in the SAME country? No report does not prove stock.
SELECT DISTINCT
    c.name                       AS country,
    m.name                       AS medicine_in_shortage,
    m.form                       AS shortage_form,
    m.strength                   AS shortage_strength,
    alt.name                     AS alternative_medicine,
    alt.form                     AS alternative_form,
    alt.strength                 AS alternative_strength,
    CASE WHEN alt_shortage.shortage_id IS NULL THEN 'No reported shortage'
         ELSE 'Also short' END   AS alternative_status
FROM shortage AS s
JOIN country AS c ON c.country_id = s.country_id
JOIN medicine AS m ON m.medicine_id = s.medicine_id
JOIN alternative AS a ON a.medicine_id = m.medicine_id
JOIN medicine AS alt ON alt.medicine_id = a.alternative_medicine_id
LEFT JOIN shortage AS alt_shortage
       ON alt_shortage.medicine_id = alt.medicine_id
      AND alt_shortage.country_id  = s.country_id
      AND alt_shortage.end_date IS NULL
WHERE s.end_date IS NULL
ORDER BY country, medicine_in_shortage, shortage_form, alternative_medicine;


-- Q3: manufacturers with shortages hitting more than one country at once.
-- Produces is populated only by the teaching seed: a source's reported company
-- or authorisation holder does not establish who physically makes the drug.
SELECT
    mf.name                          AS manufacturer,
    COUNT(DISTINCT s.country_id)     AS countries_affected,
    COUNT(DISTINCT s.medicine_id)    AS medicines_affected
FROM manufacturer AS mf
JOIN produces AS p  ON p.manufacturer_id = mf.manufacturer_id
JOIN shortage AS s  ON s.medicine_id = p.medicine_id
WHERE s.end_date IS NULL AND s.source_id = 1
GROUP BY mf.manufacturer_id, mf.name
HAVING COUNT(DISTINCT s.country_id) > 1
ORDER BY countries_affected DESC, medicines_affected DESC;


-- Q4: days between start and stored end date, by source and severity.
-- FDA end_date is the last update of a resolved record, not a confirmed
-- resolution date. BDPM has no resolved rows in this import.
SELECT
    ds.name                                         AS source,
    COALESCE(s.severity, 'Not graded')              AS severity,
    COUNT(*)                                        AS resolved_shortages,
    ROUND(AVG(DATEDIFF(s.end_date, s.start_date)), 1) AS avg_start_to_stored_end_days
FROM shortage AS s
JOIN data_source AS ds ON ds.source_id = s.source_id
WHERE s.end_date IS NOT NULL
GROUP BY ds.source_id, ds.name, s.severity
ORDER BY ds.source_id, FIELD(s.severity, 'Low', 'Medium', 'High', 'Critical');


-- Q5: for each ongoing shortage, which facility reported it most often.
-- (unchanged; facility reports exist only for seed shortages, so real rows
-- correctly do not appear)
SELECT
    shortage_id,
    facility_name,
    report_count,
    RANK() OVER (PARTITION BY shortage_id ORDER BY report_count DESC) AS rank_within_shortage
FROM (
    SELECT
        s.shortage_id,
        f.name          AS facility_name,
        COUNT(*)        AS report_count
    FROM facility_report AS fr
    JOIN facility AS f  ON f.facility_id = fr.facility_id
    JOIN shortage AS s  ON s.shortage_id = fr.shortage_id
    WHERE s.end_date IS NULL
    GROUP BY s.shortage_id, f.facility_id, f.name
) AS report_counts
ORDER BY shortage_id, rank_within_shortage;


-- Q6 (new): shared active-substance labels across the US and France feeds.
-- FDA has no structured strength in this snapshot. Name-only overlap is a
-- candidate match, not proof of an identical product or simultaneous shortage.
SELECT
    DISTINCT us_m.name AS candidate_substance
FROM shortage AS us
JOIN medicine AS us_m ON us_m.medicine_id = us.medicine_id
JOIN medicine AS fr_m ON fr_m.name = us_m.name
JOIN shortage AS fr ON fr.medicine_id = fr_m.medicine_id
WHERE us.source_id = 2 AND fr.source_id = 3
  AND us.end_date IS NULL AND fr.end_date IS NULL
ORDER BY candidate_substance;
