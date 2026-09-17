-- ============================================================================
-- KEN2110 Databases – Assignment 3: Schema Design & Implementation
-- Medicine Shortage Tracker
--
-- Relational schema derived from the final ERD (Assignment 2). Targets MySQL
-- 8.0+. Run this script against an empty database, e.g.:
--
--   mysql -u root -p < sql/01_schema.sql
--
-- It creates the database, all tables, primary/foreign keys and the
-- constraints (NOT NULL, UNIQUE, CHECK, ENUM) that keep the data valid.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS medicine_shortage_tracker
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE medicine_shortage_tracker;

-- Drop in FK-safe order so the script is re-runnable during development.
DROP TABLE IF EXISTS facility_report;
DROP TABLE IF EXISTS shortage;
DROP TABLE IF EXISTS alternative;
DROP TABLE IF EXISTS produces;
DROP TABLE IF EXISTS facility;
DROP TABLE IF EXISTS medicine;
DROP TABLE IF EXISTS manufacturer;
DROP TABLE IF EXISTS authority;
DROP TABLE IF EXISTS country;

-- ----------------------------------------------------------------------------
-- COUNTRY
-- ----------------------------------------------------------------------------
CREATE TABLE country (
    country_id  INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    region      VARCHAR(100),
    CONSTRAINT uq_country_name UNIQUE (name)
);

-- ----------------------------------------------------------------------------
-- AUTHORITY  (Country OVERSEES Authority, 1:M)
-- ----------------------------------------------------------------------------
CREATE TABLE authority (
    authority_id INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(150) NOT NULL,
    country_id   INT NOT NULL,
    CONSTRAINT uq_authority_name_country UNIQUE (name, country_id),
    CONSTRAINT fk_authority_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- MANUFACTURER  (HQ located in a Country)
-- ----------------------------------------------------------------------------
CREATE TABLE manufacturer (
    manufacturer_id INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    hq_country_id   INT NOT NULL,
    CONSTRAINT uq_manufacturer_name UNIQUE (name),
    CONSTRAINT fk_manufacturer_country
        FOREIGN KEY (hq_country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- MEDICINE
-- ----------------------------------------------------------------------------
CREATE TABLE medicine (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    atc_code    VARCHAR(10),
    form        VARCHAR(50),
    strength    VARCHAR(50),
    CONSTRAINT uq_medicine_name_form_strength UNIQUE (name, form, strength)
);

-- ----------------------------------------------------------------------------
-- FACILITY  (pharmacy / hospital, located in a Country)
-- ----------------------------------------------------------------------------
CREATE TABLE facility (
    facility_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    type        ENUM('Pharmacy', 'Hospital') NOT NULL,
    country_id  INT NOT NULL,
    CONSTRAINT fk_facility_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- SHORTAGE  (one Medicine, in one Country, reported by one Authority)
-- ----------------------------------------------------------------------------
CREATE TABLE shortage (
    shortage_id  INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id  INT NOT NULL,
    country_id   INT NOT NULL,
    authority_id INT NOT NULL,
    start_date   DATE NOT NULL,
    end_date     DATE,
    severity     ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL,
    reason       VARCHAR(255),
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
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- PRODUCES  (Manufacturer <-> Medicine, M:N bridge)
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- ALTERNATIVE  (Medicine <-> Medicine, M:N self-referencing bridge)
-- ----------------------------------------------------------------------------
CREATE TABLE alternative (
    medicine_id            INT NOT NULL,
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

-- ----------------------------------------------------------------------------
-- FACILITY_REPORT  (Facility <-> Shortage, M:N bridge with a report date)
-- Surrogate PK (report_id) + a UNIQUE natural key, matching the final ERD.
-- ----------------------------------------------------------------------------
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
