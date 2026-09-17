USE medicine_shortage_tracker;

-- countries with the most ongoing shortages, by severity
SELECT
    c.name                                            AS country,
    COUNT(*)                                           AS ongoing_shortages,
    ROUND(AVG(FIELD(s.severity, 'Low','Medium','High','Critical')), 2) AS avg_severity_score
FROM shortage AS s
JOIN country AS c ON c.country_id = s.country_id
WHERE s.end_date IS NULL
GROUP BY c.country_id, c.name
ORDER BY ongoing_shortages DESC, avg_severity_score DESC;


-- for medicines currently short, which alternatives are actually available
SELECT
    m.name                       AS medicine_in_shortage,
    alt.name                     AS alternative_medicine,
    CASE WHEN alt_shortage.shortage_id IS NULL THEN 'Available'
         ELSE 'Also short' END   AS alternative_status
FROM shortage AS s
JOIN medicine AS m ON m.medicine_id = s.medicine_id
JOIN alternative AS a ON a.medicine_id = m.medicine_id
JOIN medicine AS alt ON alt.medicine_id = a.alternative_medicine_id
LEFT JOIN shortage AS alt_shortage
       ON alt_shortage.medicine_id = alt.medicine_id
      AND alt_shortage.end_date IS NULL
WHERE s.end_date IS NULL
ORDER BY medicine_in_shortage, alternative_medicine;


-- manufacturers with shortages hitting more than one country at once
SELECT
    mf.name                          AS manufacturer,
    COUNT(DISTINCT s.country_id)     AS countries_affected,
    COUNT(DISTINCT s.medicine_id)    AS medicines_affected
FROM manufacturer AS mf
JOIN produces AS p  ON p.manufacturer_id = mf.manufacturer_id
JOIN shortage AS s  ON s.medicine_id = p.medicine_id
WHERE s.end_date IS NULL
GROUP BY mf.manufacturer_id, mf.name
HAVING COUNT(DISTINCT s.country_id) > 1
ORDER BY countries_affected DESC;


-- average resolution time in days, by severity
SELECT
    severity,
    COUNT(*)                                  AS resolved_shortages,
    ROUND(AVG(DATEDIFF(end_date, start_date)), 1) AS avg_duration_days
FROM shortage
WHERE end_date IS NOT NULL
GROUP BY severity
ORDER BY FIELD(severity, 'Low', 'Medium', 'High', 'Critical');


-- for each ongoing shortage, which facility reported it most often
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
