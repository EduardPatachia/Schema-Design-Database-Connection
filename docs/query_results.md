# Advanced query results after real-data integration

## Query 1

```
Q1: countries with the most ongoing imported shortages, by severity.
Both sources omit severity; AVG ignores NULL and rows_with_severity shows
the denominator. Synthetic teaching rows are excluded from this comparison.
```

2 row(s)

| country | ongoing_shortages | rows_with_severity | avg_severity_score |
|---|---|---|---|
| France | 298 | 0 | NULL |
| United States | 70 | 0 | NULL |

## Query 2

```
Q2: for medicines currently short, do their listed alternatives also have
a reported shortage in the SAME country? No report does not prove stock.
```

4 row(s)

| country | medicine_in_shortage | shortage_form | shortage_strength | alternative_medicine | alternative_form | alternative_strength | alternative_status |
|---|---|---|---|---|---|---|---|
| Italy | Amoxicillin | Capsule | 500mg | Amoxicillin | Suspension | 250mg/5ml | No reported shortage |
| Italy | Amoxicillin | Capsule | 500mg | Azithromycin | Tablet | 250mg | No reported shortage |
| Netherlands | Amoxicillin | Suspension | 250mg/5ml | Amoxicillin | Capsule | 500mg | No reported shortage |
| Sweden | Paracetamol | Tablet | 500mg | Ibuprofen | Tablet | 400mg | No reported shortage |

## Query 3

```
Q3: manufacturers with shortages hitting more than one country at once.
Produces is populated only by the teaching seed: a source's reported company
or authorisation holder does not establish who physically makes the drug.
```

5 row(s)

| manufacturer | countries_affected | medicines_affected |
|---|---|---|
| Pfizer | 4 | 3 |
| Teva | 3 | 3 |
| Sandoz | 2 | 2 |
| Krka | 2 | 2 |
| Sanofi | 2 | 1 |

## Query 4

```
Q4: days between start and stored end date, by source and severity.
FDA end_date is the last update of a resolved record, not a confirmed
resolution date. BDPM has no resolved rows in this import.
```

4 row(s)

| source | severity | resolved_shortages | avg_start_to_stored_end_days |
|---|---|---|---|
| Synthetic seed data | Low | 1 | 16.0 |
| Synthetic seed data | Medium | 3 | 48.0 |
| Synthetic seed data | High | 2 | 59.0 |
| openFDA Drug Shortages | Not graded | 4 | 1518.8 |

## Query 5

```
Q5: for each ongoing shortage, which facility reported it most often.
(unchanged; facility reports exist only for seed shortages, so real rows
correctly do not appear)
```

13 row(s)

| shortage_id | facility_name | report_count | rank_within_shortage |
|---|---|---|---|
| 2 | De Kring Apotheek | 2 | 1 |
| 2 | Amsterdam UMC | 1 | 2 |
| 4 | CHU Brussels | 1 | 1 |
| 4 | Multipharma Bruxelles | 1 | 1 |
| 6 | Charite Berlin | 1 | 1 |
| 8 | Hopital Necker Paris | 1 | 1 |
| 8 | Pharmacie Lafayette | 1 | 1 |
| 10 | Hospital Clinic Barcelona | 1 | 1 |
| 11 | Farmacia San Marco Milan | 2 | 1 |
| 12 | Farmacia San Marco Milan | 1 | 1 |
| 14 | Karolinska Stockholm | 1 | 1 |
| 15 | Pharmacie Lafayette | 1 | 1 |
| 15 | Hopital Necker Paris | 1 | 1 |

## Query 6

```
Q6 (new): shared active-substance labels across the US and France feeds.
FDA has no structured strength in this snapshot. Name-only overlap is a
candidate match, not proof of an identical product or simultaneous shortage.
```

3 row(s)

| candidate_substance |
|---|
| Furosemide |
| Ifosfamide |
| Riluzole |
