-- Schema for the medicine shortage tracker, run against an empty MySQL instance.
--
-- v2 (Assignment 4, real-data integration). Changes vs. v1 are marked "v2:" and
-- explained in docs/05_data_integration.md, section 5.

CREATE DATABASE IF NOT EXISTS medicine_shortage_tracker
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE medicine_shortage_tracker;

DROP TABLE IF EXISTS facility_report;
DROP TABLE IF EXISTS shortage;
DROP TABLE IF EXISTS data_source;
DROP TABLE IF EXISTS alternative;
DROP TABLE IF EXISTS produces;
DROP TABLE IF EXISTS facility;
DROP TABLE IF EXISTS medicine;
DROP TABLE IF EXISTS manufacturer;
DROP TABLE IF EXISTS authority;
DROP TABLE IF EXISTS country;

CREATE TABLE country (
    country_id  INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    region      VARCHAR(100),
    CONSTRAINT uq_country_name UNIQUE (name)
);

CREATE TABLE authority (
    authority_id INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(150) NOT NULL,
    country_id   INT NOT NULL,
    CONSTRAINT uq_authority_name_country UNIQUE (name, country_id),
    CONSTRAINT fk_authority_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- v2: hq_country_id is now nullable. Neither real dataset states where a
-- marketing-authorisation holder is headquartered, so NOT NULL forced us to
-- invent a value.
CREATE TABLE manufacturer (
    manufacturer_id INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    hq_country_id   INT NULL,
    CONSTRAINT uq_manufacturer_name UNIQUE (name),
    CONSTRAINT fk_manufacturer_country
        FOREIGN KEY (hq_country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- v2: name 150 -> 200, form 50 -> 100, strength 50 -> 150. Combination products
-- ("Amoxicillin + Clavulanic Acid") and FDA forms such as "Injection, Powder,
-- Lyophilized, For Solution" overflowed the old widths.
-- Worst-case unique key: (200+100+150) * 4 bytes = 1800 bytes < 3072 (InnoDB limit).
CREATE TABLE medicine (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    atc_code    VARCHAR(10),
    form        VARCHAR(100) NOT NULL,
    strength    VARCHAR(150) NOT NULL,
    CONSTRAINT uq_medicine_name_form_strength UNIQUE (name, form, strength)
);

CREATE TABLE facility (
    facility_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    type        ENUM('Pharmacy', 'Hospital') NOT NULL,
    country_id  INT NOT NULL,
    CONSTRAINT fk_facility_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- v2 (new): provenance of every shortage row. Lets us tell mock rows from real
-- rows, record license + retrieval date per dataset, and re-run imports safely.
CREATE TABLE data_source (
    source_id     INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    url           VARCHAR(255),
    license       VARCHAR(100) NOT NULL,
    license_url   VARCHAR(255),
    version_note  VARCHAR(255),          -- publication / last-updated info as reported by the source
    retrieved_on  DATE,
    CONSTRAINT uq_data_source_name UNIQUE (name)
);

-- v2: severity is nullable (neither real dataset grades severity; imputing one
--     would be fabricating data). supply_status keeps ANSM's rupture/tension
--     distinction. source_id/source_ref identify the originating record, and
--     UNIQUE(source_id, source_ref) makes the import idempotent (no duplicates
--     on re-run). Rows with source_id NULL are allowed but 04_data_sources.sql
--     tags all seed rows.
CREATE TABLE shortage (
    shortage_id   INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id   INT NOT NULL,
    country_id    INT NOT NULL,
    authority_id  INT NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE,
    severity      ENUM('Low', 'Medium', 'High', 'Critical') NULL,
    supply_status ENUM('Shortage', 'Supply constraint') NULL,
    reason        VARCHAR(255),
    source_id     INT NULL,
    source_ref    VARCHAR(64) NULL,
    CONSTRAINT uq_shortage_source_record UNIQUE (source_id, source_ref),
    CONSTRAINT chk_shortage_dates
        CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT fk_shortage_medicine
        FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_shortage_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_shortage_authority
        FOREIGN KEY (authority_id) REFERENCES authority (authority_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_shortage_source
        FOREIGN KEY (source_id) REFERENCES data_source (source_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Every advanced query filters on `end_date IS NULL` (ongoing shortages) and
-- groups by country or medicine, so index those access paths.
CREATE INDEX idx_shortage_ongoing   ON shortage (end_date, country_id);
CREATE INDEX idx_shortage_medicine  ON shortage (medicine_id, end_date);

-- bridge: manufacturer <-> medicine
CREATE TABLE produces (
    manufacturer_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    PRIMARY KEY (manufacturer_id, medicine_id),
    CONSTRAINT fk_produces_manufacturer
        FOREIGN KEY (manufacturer_id) REFERENCES manufacturer (manufacturer_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_produces_medicine
        FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- bridge: medicine <-> medicine (substitutes)
CREATE TABLE alternative (
    medicine_id             INT NOT NULL,
    alternative_medicine_id INT NOT NULL,
    PRIMARY KEY (medicine_id, alternative_medicine_id),
    CONSTRAINT chk_alternative_not_self
        CHECK (medicine_id <> alternative_medicine_id),
    CONSTRAINT fk_alternative_medicine
        FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_alternative_alt_medicine
        FOREIGN KEY (alternative_medicine_id) REFERENCES medicine (medicine_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- bridge: facility <-> shortage, one row per report
CREATE TABLE facility_report (
    report_id   INT AUTO_INCREMENT PRIMARY KEY,
    facility_id INT NOT NULL,
    shortage_id INT NOT NULL,
    report_date DATE NOT NULL,
    CONSTRAINT uq_facility_report UNIQUE (facility_id, shortage_id, report_date),
    CONSTRAINT fk_facility_report_facility
        FOREIGN KEY (facility_id) REFERENCES facility (facility_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_facility_report_shortage
        FOREIGN KEY (shortage_id) REFERENCES shortage (shortage_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);
