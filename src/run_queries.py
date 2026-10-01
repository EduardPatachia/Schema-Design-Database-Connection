"""Run every query in sql/03_advanced_queries.sql and save the output to
docs/query_results.md (commit that file as evidence of the re-run).

    python run_queries.py
"""
import re
from pathlib import Path

from db_config import get_connection

ROOT = Path(__file__).resolve().parent.parent
LIMIT = 25  # rows shown per query in the markdown


def split_queries(text):
    """Split on ';' only in code lines (comments may contain semicolons)."""
    queries, head, body = [], [], []
    for line in text.splitlines():
        if line.strip().startswith("--"):
            if not body:
                head.append(line)
            continue
        if line.strip():
            body.append(line)
        if line.rstrip().endswith(";"):
            sql = "\n".join(body).rstrip().rstrip(";")
            if not sql.upper().startswith("USE "):
                queries.append(("\n".join(head), sql))
            head, body = [], []
    return queries


def md_table(cols, rows):
    out = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    out += ["| " + " | ".join("NULL" if v is None else str(v) for v in r) + " |" for r in rows[:LIMIT]]
    if len(rows) > LIMIT:
        out.append(f"\n_{len(rows) - LIMIT} more rows not shown._")
    return "\n".join(out)


def main():
    sql = (ROOT / "sql" / "03_advanced_queries.sql").read_text(encoding="utf-8")
    conn = get_connection()
    parts = ["# Advanced query results after real-data integration\n"]
    try:
        cur = conn.cursor()
        for i, (head, body) in enumerate(split_queries(sql), 1):
            cur.execute(body)
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]
            parts.append(f"## Query {i}\n\n```\n{re.sub(r'^-- ?', '', head, flags=re.M)}\n```\n\n"
                         f"{len(rows)} row(s)\n\n{md_table(cols, rows)}\n")
    finally:
        conn.close()
    (ROOT / "docs").mkdir(exist_ok=True)
    (ROOT / "docs" / "query_results.md").write_text("\n".join(parts), encoding="utf-8")
    print("wrote docs/query_results.md")


if __name__ == "__main__":
    main()
