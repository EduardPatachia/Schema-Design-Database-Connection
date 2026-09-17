import db_operations as db


def main():
    print("=== add a medicine ===")
    new_id = db.add_medicine(
        name="Ceftriaxone", atc_code="J01DD04", form="Injection", strength="1g"
    )
    print(f"inserted medicine_id={new_id}")
    print(db.get_medicine(new_id))

    print("\n=== list medicines ===")
    for medicine in db.list_medicines():
        print(medicine)

    print("\n=== update its strength ===")
    rows = db.update_medicine_strength(new_id, "2g")
    print(f"rows updated: {rows}")
    print(db.get_medicine(new_id))

    print("\n=== report a shortage for it ===")
    shortage_id = db.add_shortage(
        medicine_id=new_id,
        country_id=1,  # Netherlands
        authority_id=1,  # CBG-MEB
        start_date="2026-03-01",
        severity="Medium",
        reason="demo shortage from crud_demo.py",
    )
    print(f"inserted shortage_id={shortage_id}")

    print("\n=== list ongoing shortages ===")
    for shortage in db.list_ongoing_shortages():
        print(shortage)

    print("\n=== resolve the demo shortage ===")
    rows = db.resolve_shortage(shortage_id, "2026-03-20")
    print(f"rows updated: {rows}")

    print("\n=== clean up ===")
    print(f"shortage rows deleted: {db.delete_shortage(shortage_id)}")
    print(f"medicine rows deleted: {db.delete_medicine(new_id)}")


if __name__ == "__main__":
    main()
