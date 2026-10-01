"""Run with:  python etl_test_clean.py

The fixtures below are SYNTHETIC records written to mimic the documented field
layout of each source. They only test the cleaning rules; they are not data
and are never loaded into the database.
"""
from etl_clean import (canonical_company, canonical_form, canonical_name, canonical_strength,
                       clean_bdpm, clean_fda, parse_date)


def test_helpers():
    assert parse_date("03/04/2026", "%m/%d/%Y") == "2026-03-04"      # US order
    assert parse_date("03/04/2026", "%d/%m/%Y") == "2026-04-03"      # FR order
    assert parse_date("", "%d/%m/%Y") is None
    assert parse_date("31/02/2026", "%d/%m/%Y") is None              # impossible date
    assert parse_date("01/01/1900", "%d/%m/%Y") is None              # implausible
    assert canonical_name("ACETAMINOPHEN") == "Paracetamol"          # USAN -> INN
    assert canonical_name("Paracétamol") == "Paracetamol"            # accent fold
    assert canonical_strength(["500 MG"]) == "500mg"
    assert canonical_strength(["250 MG/5 ML"]) == "250mg/5ml"
    assert canonical_strength(["100 Units/mL"]) == "100u/ml"
    assert canonical_strength([]) == "Unspecified"
    assert canonical_form("comprimé pelliculé", "fr") == "Tablet, Film Coated"
    assert canonical_form("Injection, Solution") == "Injection, Solution"
    assert canonical_company("Takeda Pharmaceuticals America, Inc.") == "Takeda Pharmaceuticals America"


def test_fda():
    recs = [
        # two NDC presentations of the same medicine -> must collapse to one shortage
        {"generic_name": "Amoxicillin", "dosage_form": "Capsule", "strength": ["500 MG"], "status": "Current",
         "initial_posting_date": "11/03/2025", "company_name": "Sandoz Inc", "presentation": "A"},
        {"generic_name": "amoxicillin ", "dosage_form": "Capsule", "strength": ["500 mg"], "status": "Current",
         "initial_posting_date": "12/01/2025", "company_name": "Teva Pharmaceuticals USA, Inc.", "presentation": "B"},
        # form embedded in the generic name
        {"generic_name": "Lisdexamfetamine Dimesylate Tablet, Chewable", "dosage_form": "Tablet, Chewable",
         "strength": ["30 MG"], "status": "Current", "initial_posting_date": "01/05/2026", "presentation": "C"},
        # resolved with a sane end date
        {"generic_name": "Ibuprofen", "dosage_form": "Tablet", "strength": ["400 MG"], "status": "Resolved",
         "initial_posting_date": "01/01/2025", "update_date": "02/01/2025", "presentation": "D"},
        # violations that must be rejected, not loaded
        {"generic_name": "Ibuprofen", "dosage_form": "Tablet", "strength": ["600 MG"], "status": "Resolved",
         "initial_posting_date": "05/01/2025", "update_date": "01/01/2025", "presentation": "E"},
        {"generic_name": "", "status": "Current", "initial_posting_date": "01/01/2025", "presentation": "F"},
        {"generic_name": "Foo", "status": "Current", "initial_posting_date": "", "presentation": "G"},
        {"generic_name": "Bar", "dosage_form": "Tablet", "status": "To Be Discontinued",
         "initial_posting_date": "01/01/2025", "presentation": "H"},
    ]
    out = clean_fda(recs)
    amox = [i for i in out["items"] if i["name"] == "Amoxicillin"]
    assert len(amox) == 1 and amox[0]["start_date"] == "2025-11-03" and amox[0]["end_date"] is None
    assert amox[0]["companies"] == ["Sandoz", "Teva Pharmaceuticals Usa"], amox[0]["companies"]
    lis = [i for i in out["items"] if i["name"].startswith("Lisdex")][0]
    assert lis["name"] == "Lisdexamfetamine Dimesylate" and lis["form"] == "Tablet, Chewable"
    ibu = [i for i in out["items"] if i["name"] == "Ibuprofen"]
    assert len(ibu) == 1 and ibu[0]["end_date"] == "2025-02-01"
    assert len(out["rejects"]) == 3, out["rejects"]
    assert out["stats"]["skipped_status:to be discontinued"] == 1


def test_bdpm():
    cis = [["1", "PARACETAMOL EG 500 mg, comprimé", "comprimé", "orale", "AMM", "", "Commercialisée", "01/01/2010", "", "", " EG LABO ; BIOGARAN", "Non"],
           ["2", "AMOXICILLINE X", "gélule", "orale", "AMM", "", "Commercialisée", "01/01/2010", "", "", "SANDOZ", "Non"]]
    compo = [["1", "comprimé", "10", "PARACETAMOL", "500 mg", "un comprimé", "SA", "1"],
             ["1", "comprimé", "11", "EXCIPIENT", "", "", "ST", "1"],
             ["2", "gélule", "20", "AMOXICILLINE", "500 mg", "une gélule", "SA", "1"]]
    dispo = [["1", "3400000000001", "2", "Tension d'approvisionnement", "10/02/2026", "11/02/2026", "", ""],
             ["1", "", "1", "Rupture de stock", "01/02/2026", "11/02/2026", "", ""],     # same CIS -> collapses
             ["2", "", "4", "Remise à disposition", "01/01/2026", "01/01/2026", "", ""],  # skipped
             ["999", "", "1", "Rupture de stock", "01/01/2026", "01/01/2026", "", ""],    # unknown CIS -> reject
             ["2", "", "1", "Rupture de stock", "", "", "", ""]]                          # no date -> reject
    mitm = [["1", "N02BE01", "PARACETAMOL", ""]]
    out = clean_bdpm(cis, compo, dispo, mitm)
    assert len(out["items"]) == 1, out["items"]
    p = out["items"][0]
    assert (p["name"], p["form"], p["strength"], p["atc_code"]) == ("Paracetamol", "Tablet", "500mg", "N02BE01")
    assert p["start_date"] == "2026-02-01" and p["supply_status"] == "Shortage"
    assert p["companies"] == ["Biogaran", "Eg Labo"]
    assert len(out["rejects"]) == 2 and out["stats"]["skipped_status:4"] == 1


if __name__ == "__main__":
    test_helpers(); test_fda(); test_bdpm()
    print("all cleaning tests passed")
