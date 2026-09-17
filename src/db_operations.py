"""Basic CRUD operations against the medicine_shortage_tracker database.

Every function opens its own connection and uses parameterized queries
(never string-formatted SQL) to stay safe from SQL injection.
"""

from db_config import get_connection


# ---------------------------------------------------------------------------
# Medicine
# ---------------------------------------------------------------------------

def add_medicine(name, atc_code, form, strength):
    """Insert a new medicine and return its generated medicine_id."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO medicine (name, atc_code, form, strength)
            VALUES (%s, %s, %s, %s)
            """,
            (name, atc_code, form, strength),
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def get_medicine(medicine_id):
    """Fetch a single medicine by id, or None if it doesn't exist."""
    conn = get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT * FROM medicine WHERE medicine_id = %s", (medicine_id,)
        )
        return cursor.fetchone()
    finally:
        conn.close()


def list_medicines():
    """Return every medicine, ordered by name."""
    conn = get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM medicine ORDER BY name")
        return cursor.fetchall()
    finally:
        conn.close()


def update_medicine_strength(medicine_id, new_strength):
    """Update the strength of an existing medicine. Returns rows affected."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE medicine SET strength = %s WHERE medicine_id = %s",
            (new_strength, medicine_id),
        )
        conn.commit()
        return cursor.rowcount
    finally:
        conn.close()


def delete_medicine(medicine_id):
    """Delete a medicine by id. Returns rows affected."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM medicine WHERE medicine_id = %s", (medicine_id,)
        )
        conn.commit()
        return cursor.rowcount
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Shortage
# ---------------------------------------------------------------------------

def add_shortage(medicine_id, country_id, authority_id, start_date, severity, reason, end_date=None):
    """Insert a new shortage record and return its generated shortage_id."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO shortage
                (medicine_id, country_id, authority_id, start_date, end_date, severity, reason)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (medicine_id, country_id, authority_id, start_date, end_date, severity, reason),
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def list_ongoing_shortages():
    """Return every shortage that has not yet been resolved (end_date IS NULL)."""
    conn = get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT s.shortage_id, m.name AS medicine, c.name AS country,
                   s.severity, s.start_date, s.reason
            FROM shortage AS s
            JOIN medicine AS m ON m.medicine_id = s.medicine_id
            JOIN country  AS c ON c.country_id = s.country_id
            WHERE s.end_date IS NULL
            ORDER BY s.start_date
            """
        )
        return cursor.fetchall()
    finally:
        conn.close()


def resolve_shortage(shortage_id, end_date):
    """Mark a shortage as resolved by setting its end_date. Returns rows affected."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE shortage SET end_date = %s WHERE shortage_id = %s",
            (end_date, shortage_id),
        )
        conn.commit()
        return cursor.rowcount
    finally:
        conn.close()


def delete_shortage(shortage_id):
    """Delete a shortage by id (cascades to its facility_report rows). Returns rows affected."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM shortage WHERE shortage_id = %s", (shortage_id,)
        )
        conn.commit()
        return cursor.rowcount
    finally:
        conn.close()
