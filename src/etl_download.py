"""Download the raw data into data/raw/ and write data/raw/manifest.json
(retrieval time, size, sha256, source-reported update info).

    python etl_download.py

Needs plain internet access; no API key or registration for either source.

If a BDPM download URL changes, the files can also be downloaded manually from
https://base-donnees-publique.medicaments.gouv.fr/telechargement
and saved in data/raw/ under the same file names.
"""
import hashlib
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"
FDA_URL = "https://api.fda.gov/drug/shortages.json"
BDPM_URL = "https://base-donnees-publique.medicaments.gouv.fr/download/file/{}"
BDPM_FILES = ["CIS_bdpm.txt", "CIS_COMPO_bdpm.txt", "CIS_CIP_Dispo_Spec.txt", "CIS_MITM.txt"]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "KEN2110-student-project"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def download_fda():
    records, skip, meta = [], 0, {}
    while True:
        page = json.loads(get(f"{FDA_URL}?limit=1000&skip={skip}"))
        meta = page["meta"]
        records.extend(page["results"])
        skip += len(page["results"])
        if not page["results"] or skip >= page["meta"]["results"]["total"]:
            break
    path = RAW / "fda_shortages.json"
    path.write_text(json.dumps({"meta": meta, "results": records}, ensure_ascii=False))
    return path, {"records": len(records), "source_last_updated": meta.get("last_updated")}


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    manifest = {"retrieved_at": datetime.now(timezone.utc).isoformat(timespec="seconds"), "files": {}}
    path, extra = download_fda()
    manifest["files"][path.name] = extra
    for name in BDPM_FILES:
        path = RAW / name
        path.write_bytes(get(BDPM_URL.format(name)))
        manifest["files"][name] = {"bytes": path.stat().st_size}
    for name, info in manifest["files"].items():
        info["sha256"] = hashlib.sha256((RAW / name).read_bytes()).hexdigest()
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
