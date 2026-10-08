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
| 15 | Hopital Necker Paris | 1 | 1 |
| 15 | Pharmacie Lafayette | 1 | 1 |

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

## Query 7

```
Q7: which company groups are named in ongoing shortages in both France and
the United States, and how many in each?
Author: Mihály Kányási
Relevance: the same supplier group failing in two markets points to a
cross-border supply risk, the "early warning when shortages cross borders"
future work from the Week 4 video. Groups are matched on the first word of
the reported name (Teva Sante / Teva Pharmaceuticals Usa), which misses
renamed subsidiaries (Mylan / Viatris); a reported company or licence
holder is not proof of who physically makes the medicine.
```

17 row(s)

| company_group | france_shortages | us_shortages | reported_as |
|---|---|---|---|
| Teva | 28 | 10 | Teva Pays-Bas; Teva Pharmaceuticals Usa; Teva Sante |
| Fresenius | 3 | 31 | Fresenius Kabi France; Fresenius Kabi Usa; Fresenius Medical Care Deutschland Allemagne |
| Hikma | 1 | 29 | Hikma Farmaceutica Portugal; Hikma Pharmaceuticals Usa |
| Accord | 22 | 7 | Accord Healthcare; Accord Healthcare Espagne; Accord Healthcare France |
| Sandoz | 19 | 3 | Sandoz |
| Baxter | 5 | 16 | Baxter; Baxter Healthcare |
| Janssen | 12 | 1 | Janssen Cilag; Janssen Cilag International; Janssen Pharmaceuticals |
| Pfizer | 9 | 4 | Pfizer; Pfizer Europe Ma Eeig Belgique; Pfizer Holding France |
| Cheplapharm | 11 | 1 | Cheplapharm Arzneimittel; Cheplapharm Arzneimittel Allemagne; Cheplapharm Registration Allemagne |
| Eugia | 1 | 11 | Eugia Pharma Malta Malte; Eugia Us |
| Mylan | 1 | 8 | Mylan Institutional A Viatris Company; Mylan Pharmaceuticals Inc A Viatris Company; Mylan Pharmaceuticals Irlande; Mylan Specialty A Viatris Company |
| Sun | 5 | 4 | Sun Pharma France; Sun Pharmaceutical Industries; Sun Pharmaceutical Industries Europe Pays Bas |
| Amphastar | 1 | 6 | Amphastar France Pharmaceuticals; Amphastar Pharmaceuticals |
| Ferring | 4 | 1 | Ferring; Ferring France |
| Takeda | 3 | 2 | Takeda Pharmaceuticals International Irlande; Takeda Pharmaceuticals Usa |
| Bristol | 1 | 1 | Bristol Myers Squibb |
| Novo | 1 | 1 | Novo Nordisk; Novo Nordisk Danemark |

## Query 8

```
Q8: which therapeutic areas (ATC main groups) have the most ongoing
shortages in France, and how many are full stock-outs?
Author: Mihály Kányási
Relevance: national agencies prioritise by therapeutic area, and hospital
and pharmacy buyers need to know where substitutes will be hardest to find.
Uses the BDPM feed only, because openFDA has no ATC codes.
```

14 row(s)

| atc_main_group | ongoing_shortages | out_of_stock | supply_constraint | distinct_substances | pct_of_all_ongoing |
|---|---|---|---|---|---|
| N: Nervous system | 78 | 9 | 69 | 24 | 26.2 |
| Unknown (no ATC code in source) | 42 | 18 | 24 | 31 | 14.1 |
| A: Alimentary tract and metabolism | 27 | 4 | 23 | 17 | 9.1 |
| C: Cardiovascular system | 26 | 2 | 24 | 16 | 8.7 |
| B: Blood and blood-forming organs | 23 | 0 | 23 | 10 | 7.7 |
| J: Anti-infectives for systemic use | 19 | 3 | 16 | 13 | 6.4 |
| L: Antineoplastic and immunomodulating agents | 19 | 6 | 13 | 15 | 6.4 |
| H: Systemic hormonal preparations | 18 | 0 | 18 | 8 | 6.0 |
| S: Sensory organs | 17 | 4 | 13 | 15 | 5.7 |
| V: Various | 15 | 2 | 13 | 6 | 5.0 |
| R: Respiratory system | 6 | 0 | 6 | 1 | 2.0 |
| P: Antiparasitic products | 5 | 3 | 2 | 4 | 1.7 |
| M: Musculo-skeletal system | 2 | 0 | 2 | 2 | 0.7 |
| D: Dermatologicals | 1 | 0 | 1 | 1 | 0.3 |
