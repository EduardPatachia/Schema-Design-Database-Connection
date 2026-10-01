"""Clean the raw files and load them into MySQL.

    python etl_load.py [--bdpm-update-date DD/MM/YYYY]

Prerequisite: sql/01_schema.sql, 02_seed.sql, 04_data_sources.sql already run,
and `python etl_download.py` done. Safe to re-run: shortages are upserted on
UNIQUE(source_id, source_ref), medicines and reported companies on their
unique names.

Everything that does not load ends up in data/rejects/*.csv with a reason:
either the cleaner refused it, or MySQL rejected it (that is the constraint
check the assignment asks for).
"""
import argparse
import csv
import json
from pathlib import Path

import mysql.connector

from db_config import get_connection
from etl_clean import clean_bdpm, clean_fda, read_bdpm

ROOT = Path(__file__).resolve().parent.parent
RAW, REJ = ROOT / "data" / "raw", ROOT / "data" / "rejects"

SRC_FDA, SRC_BDPM = 2, 3
COUNTRY = {"FDA": "United States", "BDPM": "France"}
AUTHORITY = {"FDA": "FDA", "BDPM": "ANSM"}


def upsert_medicine(cur, it):
    cur.execute(
        """INSERT INTO medicine (name, atc_code, form, strength) VALUES (%s,%s,%s,%s)
           ON DUPLICATE KEY UPDATE medicine_id = LAST_INSERT_ID(medicine_id),
                                   atc_code = COALESCE(atc_code, VALUES(atc_code))""",
        (it["name"], it["atc_code"], it["form"], it["strength"]),
    )
    return cur.lastrowid


def upsert_reported_company(cur, name):
    cur.execute(
        """INSERT INTO reported_company (name) VALUES (%s)
           ON DUPLICATE KEY UPDATE company_id = LAST_INSERT_ID(company_id)""",
        (name,),
    )
    return cur.lastrowid


def lookup(cur, sql, args):
    cur.execute(sql, args)
    row = cur.fetchone()
    if row is None:
        raise SystemExit(f"Missing reference row for {args}: did you run 04_data_sources.sql?")
    return row[0]


def load(cur, tag, source_id, result):
    country_id = lookup(cur, "SELECT country_id FROM country WHERE name=%s", (COUNTRY[tag],))
    authority_id = lookup(cur, "SELECT authority_id FROM authority WHERE name=%s AND country_id=%s",
                          (AUTHORITY[tag], country_id))
    db_rejects, loaded = [], 0
    for it in result["items"]:
        cur.execute("SAVEPOINT import_row")
        try:
            med_id = upsert_medicine(cur, it)
            cur.execute(
                """INSERT INTO shortage (medicine_id, country_id, authority_id, start_date, end_date,
                                         severity, supply_status, reason, source_id, source_ref)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                   ON DUPLICATE KEY UPDATE shortage_id=LAST_INSERT_ID(shortage_id),
                                           end_date=VALUES(end_date), supply_status=VALUES(supply_status),
                                           start_date=VALUES(start_date), reason=VALUES(reason)""",
                (med_id, country_id, authority_id, it["start_date"], it["end_date"], it["severity"],
                 it["supply_status"], it["reason"], source_id, it["source_ref"]),
            )
            shortage_id = cur.lastrowid
            for company in it["companies"]:
                cur.execute("INSERT IGNORE INTO shortage_company (shortage_id, company_id) VALUES (%s,%s)",
                            (shortage_id, upsert_reported_company(cur, company)))
            loaded += 1
        except mysql.connector.Error as e:
            cur.execute("ROLLBACK TO SAVEPOINT import_row")
            db_rejects.append((f'{it["name"]} | {it["form"]} | {it["strength"]}', f"MySQL {e.errno}: {e.msg}"))
    return loaded, db_rejects


def write_rejects(tag, rows):
    REJ.mkdir(parents=True, exist_ok=True)
    with open(REJ / f"{tag.lower()}_rejects.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["record", "reason"])
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bdpm-update-date", help="update date shown on the BDPM download page, DD/MM/YYYY")
    args = ap.parse_args()

    manifest = json.loads((RAW / "manifest.json").read_text())
    fda = json.loads((RAW / "fda_shortages.json").read_text())
    fda_res = clean_fda(fda["results"])
    bdpm_res = clean_bdpm(read_bdpm(RAW / "CIS_bdpm.txt"), read_bdpm(RAW / "CIS_COMPO_bdpm.txt"),
                          read_bdpm(RAW / "CIS_CIP_Dispo_Spec.txt"), read_bdpm(RAW / "CIS_MITM.txt"))

    conn = get_connection()
    try:
        cur = conn.cursor()
        retrieved = manifest["retrieved_at"][:10]
        cur.execute("UPDATE data_source SET retrieved_on=%s, version_note=%s WHERE source_id=%s",
                    (retrieved, f"meta.last_updated = {manifest['files']['fda_shortages.json'].get('source_last_updated')}", SRC_FDA))
        cur.execute("UPDATE data_source SET retrieved_on=%s, version_note=%s WHERE source_id=%s",
                    (retrieved, f"BDPM update date shown on download page: {args.bdpm_update_date or 'not recorded'}", SRC_BDPM))
        for tag, sid, res in (("FDA", SRC_FDA, fda_res), ("BDPM", SRC_BDPM, bdpm_res)):
            loaded, db_rej = load(cur, tag, sid, res)
            write_rejects(tag, res["rejects"] + db_rej)
            print(f"[{tag}] stats={res['stats']}")
            print(f"[{tag}] loaded={loaded}  cleaner_rejects={len(res['rejects'])}  mysql_rejects={len(db_rej)}")
            if loaded < 50:
                print(f"[{tag}] WARNING: fewer than 50 shortage rows; assignment asks for >= 50 unique rows per dataset")
        conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
