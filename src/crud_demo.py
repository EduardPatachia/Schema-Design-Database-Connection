"""Runnable demonstration of the CRUD operations in db_operations.py.

Usage (after loading the schema and seed data, see the root README):

    cd src
    pip install -r requirements.txt
    python crud_demo.py
"""

import db_operations as db


def main():
    print("=== CREATE: adding a new medicine ===")
    new_id = db.add_medicine(
        name="Ceftriaxone", atc_code="J01DD04", form="Injection", strength="1g"
    )
    print(f"Inserted medicine_id={new_id}")
    print(db.get_medicine(new_id))

    print("\n=== READ: listing all medicines ===")
    for medicine in db.list_medicines():
        print(medicine)

    print("\n=== UPDATE: changing the strength of the new medicine ===")
    rows = db.update_medicine_strength(new_id, "2g")
    print(f"Rows updated: {rows}")
    print(db.get_medicine(new_id))

    print("\n=== CREATE: reporting a new shortage for that medicine ===")
    shortage_id = db.add_shortage(
        medicine_id=new_id,
        country_id=1,          # Netherlands
        authority_id=1,        # CBG-MEB
        start_date="2026-03-01",
        severity="Medium",
        reason="Demo shortage created by crud_demo.py",
    )
    print(f"Inserted shortage_id={shortage_id}")

    print("\n=== READ: listing ongoing shortages ===")
    for shortage in db.list_ongoing_shortages():
        print(shortage)

    print("\n=== UPDATE: resolving the demo shortage ===")
    rows = db.resolve_shortage(shortage_id, "2026-03-20")
    print(f"Rows updated: {rows}")

    print("\n=== DELETE: removing the demo shortage and medicine ===")
    print(f"Shortage rows deleted: {db.delete_shortage(shortage_id)}")
    print(f"Medicine rows deleted: {db.delete_medicine(new_id)}")

    print("\nDone. Database left in its original (seeded) state.")


if __name__ == "__main__":
    main()
