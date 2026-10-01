"""Cleaning and transformation for the two real datasets.

No database access in here, so every rule can be unit-tested (etl_test_clean.py).
Both cleaners return the same shape:

    {"items": [...shortage dicts ready to load...],
     "rejects": [(record_id, reason), ...],
     "stats": {...counts for the documentation...}}
"""
import hashlib
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date, datetime

# --- generic helpers -------------------------------------------------------

# Every spelling of "no value" we have to expect (FDA omits keys or sends "",
# BDPM leaves tab-separated fields empty).
MISSING = {"", "n/a", "na", "null", "none", "-", "--", "unknown", "nr"}
UNSPECIFIED = "Unspecified"  # sentinel: UNIQUE(name, form, strength) ignores NULLs, so NOT NULL + sentinel


def is_missing(v):
    if v is None:
        return True
    if isinstance(v, (list, tuple)):
        return all(is_missing(x) for x in v)
    return str(v).strip().lower() in MISSING


def fold(s):
    """Strip accents: 'Comprimé' -> 'Comprime'."""
    s = unicodedata.normalize("NFKD", str(s))
    return "".join(c for c in s if not unicodedata.combining(c))


def squash(s):
    return re.sub(r"\s+", " ", s).strip()


def parse_date(value, fmt):
    """Return an ISO date string, or None for missing/unparseable/implausible.
    The format is passed explicitly because the sources disagree:
    openFDA = MM/DD/YYYY, BDPM = DD/MM/YYYY."""
    if is_missing(value):
        return None
    try:
        d = datetime.strptime(str(value).strip(), fmt).date()
    except ValueError:
        return None
    if not (1990 <= d.year <= date.today().year + 1):
        return None
    return d.isoformat()


# --- naming normalisation ----------------------------------------------------

# US (USAN) vs international (INN) names for the same substance. Illustrative,
# not exhaustive: extend as the loader's "unmatched" report shows new pairs.
INN_SYNONYMS = {
    "acetaminophen": "paracetamol",
    "epinephrine": "adrenaline",
    "norepinephrine": "noradrenaline",
    "albuterol": "salbutamol",
    "meperidine": "pethidine",
    "cyclosporine": "ciclosporin",
    "rifampin": "rifampicin",
    "glyburide": "glibenclamide",
}
_SYN_RE = re.compile(r"\b(" + "|".join(INN_SYNONYMS) + r")\b")

# French pharmaceutical forms -> the English (FDA/SPL-style) spelling used in
# the seed data. Longest key wins; unmapped forms are kept (accent-folded).
FORM_FR_EN = {
    "comprime pellicule": "Tablet, Film Coated",
    "comprime effervescent": "Tablet, Effervescent",
    "comprime orodispersible": "Tablet, Orally Disintegrating",
    "comprime": "Tablet",
    "gelule": "Capsule",
    "capsule molle": "Capsule",
    "capsule": "Capsule",
    "poudre pour solution injectable": "Injection, Powder, For Solution",
    "poudre pour suspension buvable": "Powder, For Suspension",
    "solution injectable": "Injection, Solution",
    "solution pour perfusion": "Injection, Solution",
    "suspension buvable": "Suspension",
    "solution buvable": "Solution",
    "sirop": "Syrup",
    "collyre": "Ophthalmic Solution",
    "creme": "Cream",
    "pommade": "Ointment",
    "suppositoire": "Suppository",
}
_FORM_KEYS = sorted(FORM_FR_EN, key=len, reverse=True)

LEGAL_SUFFIXES = {"inc", "llc", "ltd", "limited", "corp", "corporation", "co", "sa", "sas",
                  "sarl", "gmbh", "ag", "bv", "nv", "plc", "lp", "spa"}


def canonical_name(raw):
    s = squash(fold(raw)).lower()
    s = _SYN_RE.sub(lambda m: INN_SYNONYMS[m.group(1)], s)
    return s.title()[:200]


def canonical_form(raw, lang="en"):
    if is_missing(raw):
        return UNSPECIFIED
    s = squash(fold(raw)).lower()
    if lang == "fr":
        for key in _FORM_KEYS:
            if s.startswith(key):
                return FORM_FR_EN[key]
    return s.title()[:100]


def canonical_strength(parts):
    """['500 MG', '125 MG'] -> '500mg + 125mg'; '250 MG/5 ML' -> '250mg/5ml'."""
    if isinstance(parts, str):
        parts = [parts]
    out = []
    for p in parts or []:
        if is_missing(p):
            continue
        s = str(p).replace("\u00b5g", "mcg").replace("\u03bcg", "mcg")  # micro sign / greek mu
        s = fold(s).lower()
        s = re.sub(r"\s+", "", s)
        s = re.sub(r"units?\b", "u", s)
        out.append(s)
    return " + ".join(out)[:150] if out else UNSPECIFIED


def canonical_company(raw):
    if is_missing(raw):
        return None
    s = re.sub(r"[^\w&\- ]", " ", fold(raw))
    tokens = squash(s).split(" ")
    while tokens and tokens[-1].lower() in LEGAL_SUFFIXES:
        tokens.pop()
    return " ".join(tokens).title()[:200] if tokens else None


def _ref(name, form, strength, kind):
    return hashlib.sha1(f"{name}|{form}|{strength}|{kind}".encode()).hexdigest()


# --- aggregation: many source records -> one shortage per medicine & episode kind

def aggregate(rows):
    """rows: dicts with name, form, strength, start, end, ongoing, ... .
    Source files are per *presentation* (FDA: per NDC, BDPM: per CIP13/CIS),
    our `shortage` is per *medicine*, so records collapse onto
    (name, form, strength, ongoing|resolved)."""
    groups = defaultdict(list)
    for r in rows:
        kind = "ongoing" if r["ongoing"] else "resolved"
        groups[(r["name"], r["form"], r["strength"], kind)].append(r)
    items = []
    for (name, form, strength, kind), g in groups.items():
        g.sort(key=lambda r: r["start"])
        first = g[0]
        companies = sorted({c for r in g for c in r["companies"] if c})
        statuses = {r.get("supply_status") for r in g if r.get("supply_status")}
        items.append({
            "name": name, "form": form, "strength": strength,
            "atc_code": next((r["atc"] for r in g if r.get("atc")), None),
            "start_date": first["start"],
            "end_date": None if kind == "ongoing" else max(r["end"] for r in g),
            "severity": None,
            "supply_status": "Shortage" if "Shortage" in statuses else ("Supply constraint" if statuses else None),
            "reason": next((r["reason"] for r in g if r.get("reason")), None),
            "companies": companies,
            "source_ref": _ref(name, form, strength, kind),
            "n_source_records": len(g),
        })
    return items


# --- dataset A: openFDA drug shortages --------------------------------------

def clean_fda(records):
    rows, rejects, stats = [], [], Counter()
    for i, r in enumerate(records):
        rid = r.get("presentation") or f"record #{i}"
        stats["raw_records"] += 1
        generic = r.get("generic_name")
        if is_missing(generic):
            rejects.append((rid, "missing generic_name"))
            continue
        form_raw = r.get("dosage_form")
        # Some records embed the dosage form in the generic name
        # ("... Dimesylate Tablet, Chewable"): strip it so it is not stored twice.
        g = squash(str(generic))
        if not is_missing(form_raw) and g.lower().endswith(str(form_raw).strip().lower()):
            g = g[: -len(str(form_raw).strip())].strip(" ,")
            stats["form_stripped_from_name"] += 1
        status = str(r.get("status", "")).strip().lower()
        if status not in ("current", "resolved"):
            stats[f"skipped_status:{status or 'missing'}"] += 1   # e.g. "To Be Discontinued"
            continue
        start = parse_date(r.get("initial_posting_date"), "%m/%d/%Y")
        if start is None:
            rejects.append((rid, "missing/invalid initial_posting_date"))
            continue
        end = None
        if status == "resolved":
            # FDA gives no real end date: update_date of a Resolved record is the best proxy.
            end = parse_date(r.get("update_date"), "%m/%d/%Y")
            if end is None:
                rejects.append((rid, "resolved but update_date missing/invalid"))
                continue
            if end < start:
                rejects.append((rid, f"end {end} before start {start} (would violate chk_shortage_dates)"))
                continue
        reason = r.get("shortage_reason") or r.get("resolved_note")
        rows.append({
            "name": canonical_name(g),
            "form": canonical_form(form_raw),
            "strength": canonical_strength(r.get("strength")),
            "atc": None,
            "start": start, "end": end, "ongoing": status == "current",
            "reason": None if is_missing(reason) else squash(str(reason))[:255],
            "companies": [canonical_company(r.get("company_name"))],
        })
    items = aggregate(rows)
    stats["presentations_kept"] = len(rows)
    stats["shortages_after_dedup"] = len(items)
    return {"items": items, "rejects": rejects, "stats": dict(stats)}


# --- dataset B: BDPM (France) -------------------------------------------------

def read_bdpm(path):
    """BDPM files: tab-separated, no header, no quoting. Encoding is not
    declared in the format document, so try UTF-8 first, fall back to cp1252."""
    raw = open(path, "rb").read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode("cp1252", errors="replace")
    return [[f.strip() for f in line.split("\t")] for line in text.splitlines() if line.strip()]


def _col(row, i):
    return row[i] if i < len(row) else ""


def clean_bdpm(cis_rows, compo_rows, dispo_rows, mitm_rows):
    stats, rejects = Counter(), []
    # CIS_bdpm: 0 CIS | 1 denomination | 2 forme | ... | 10 titulaire(s)
    cis = {_col(r, 0): r for r in cis_rows}
    # CIS_COMPO: 0 CIS | 3 substance name | 4 dosage | 6 SA/ST
    subs = defaultdict(list)
    for r in compo_rows:
        if _col(r, 6).upper() == "SA" and not is_missing(_col(r, 3)):
            subs[_col(r, 0)].append((canonical_name(_col(r, 3)), _col(r, 4)))
    # CIS_MITM: 0 CIS | 1 ATC
    atc = {_col(r, 0): _col(r, 1) for r in mitm_rows if not is_missing(_col(r, 1))}

    rows = []
    # CIS_CIP_Dispo_Spec: 0 CIS | 1 CIP13 | 2 code statut | 3 libelle | 4 date debut | 5 date MAJ | 6 date remise dispo
    for r in dispo_rows:
        stats["raw_records"] += 1
        c, code = _col(r, 0), _col(r, 2)
        rid = f"CIS {c} / CIP13 {_col(r, 1) or '(all presentations)'}"
        if code not in ("1", "2"):
            stats[f"skipped_status:{code}"] += 1   # 3 = discontinued, 4 = back in stock
            continue
        if c not in cis:
            rejects.append((rid, "CIS not in CIS_bdpm.txt (product off the market > 2 years)"))
            continue
        if c not in subs:
            rejects.append((rid, "no active substance (SA) in CIS_COMPO_bdpm.txt"))
            continue
        start = parse_date(_col(r, 4), "%d/%m/%Y") or parse_date(_col(r, 5), "%d/%m/%Y")
        if start is None:
            rejects.append((rid, "no usable start/update date"))
            continue
        pairs = sorted(set(subs[c]))
        rows.append({
            "name": " + ".join(dict.fromkeys(p[0] for p in pairs)),
            "form": canonical_form(_col(cis[c], 2), "fr"),
            "strength": canonical_strength([p[1] for p in pairs]),
            "atc": atc.get(c),
            "start": start, "end": None, "ongoing": True,
            "supply_status": "Shortage" if code == "1" else "Supply constraint",
            "reason": None,   # BDPM publishes no reason
            "companies": [canonical_company(t) for t in _col(cis[c], 10).split(";") if t.strip()],
        })
    items = aggregate(rows)
    stats["presentations_kept"] = len(rows)
    stats["shortages_after_dedup"] = len(items)
    return {"items": items, "rejects": rejects, "stats": dict(stats)}
