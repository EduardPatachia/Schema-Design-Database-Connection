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

-- Constraint tests: each statement below must be REJECTED by MySQL. A plain
-- failing INSERT would abort `mysql < 06_validation.sql`, so every test runs
-- inside expect_rejected(), which catches the error, rolls back, and reports
-- it. Any row saying "ACCEPTED" means a constraint is missing.
-- Needs MySQL 8.0.16+ (older versions parse CHECK constraints but ignore them).
DROP PROCEDURE IF EXISTS expect_rejected;
DELIMITER //
CREATE PROCEDURE expect_rejected(IN test_name VARCHAR(100), IN test_sql TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_no = MYSQL_ERRNO, @err_msg = MESSAGE_TEXT;
        ROLLBACK;
        SELECT test_name AS test, 'rejected (expected)' AS result, @err_no AS mysql_error, @err_msg AS message;
    END;
    START TRANSACTION;
    SET @test_sql = test_sql;
    PREPARE stmt FROM @test_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    ROLLBACK;
    SELECT test_name AS test, 'ACCEPTED (constraint missing!)' AS result, NULL AS mysql_error, NULL AS message;
END //
DELIMITER ;

-- chk_shortage_dates: a shortage cannot end before it starts.
CALL expect_rejected('end_date before start_date',
    "INSERT INTO shortage (medicine_id, country_id, authority_id, start_date, end_date)
     VALUES (1, 1, 1, '2026-01-10', '2026-01-01')");

-- chk_alternative_not_self: a medicine cannot be its own alternative.
CALL expect_rejected('medicine as its own alternative',
    "INSERT INTO alternative (medicine_id, alternative_medicine_id) VALUES (1, 1)");

-- fk_shortage_authority_country (v3): country must match the authority's country.
CALL expect_rejected('shortage country differs from authority country',
    "INSERT INTO shortage (medicine_id, country_id, authority_id, start_date)
     VALUES (1, 2, 1, '2026-01-10')");

-- uq_shortage_source_record: the same source record cannot be imported twice.
CALL expect_rejected('duplicate source record',
    "INSERT INTO shortage (medicine_id, country_id, authority_id, start_date, source_id, source_ref)
     SELECT medicine_id, country_id, authority_id, start_date, source_id, source_ref
     FROM shortage WHERE source_id = 3 LIMIT 1");

DROP PROCEDURE expect_rejected;
