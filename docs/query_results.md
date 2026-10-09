# Advanced query results after real-data integration

## Query 1

```
Q1: countries with the most ongoing imported shortages, by severity.
Both sources omit severity; AVG ignores NULL and rows_with_severity shows
the denominator. Synthetic teaching rows are excluded from this comparison.
Author: Eduard Patachia (EduardPatachia), updated for the real data by
Isaac Tighe (isaactighe) and Andrei Macari (andriuhanfs)
Relevance: shows which countries have the most shortages right now, so
authorities know where the problem is biggest.
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
Author: Eduard Patachia (EduardPatachia), updated for the real data by
Isaac Tighe (isaactighe) and Andrei Macari (andriuhanfs)
Relevance: if the alternative is also short in the same country, patients
can't be switched to it.
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
Author: Eduard Patachia (EduardPatachia), updated for the real data by
Isaac Tighe (isaactighe) and Andrei Macari (andriuhanfs)
Relevance: a manufacturer with shortages in several countries is something
one country can't solve on its own.
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
Author: Eduard Patachia (EduardPatachia), updated for the real data by
Isaac Tighe (isaactighe) and Andrei Macari (andriuhanfs)
Relevance: long shortages are harder to cover with stock.
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
Author: Eduard Patachia (EduardPatachia)
Relevance: shows which hospitals and pharmacies are reporting each shortage.
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
Author: Isaac Tighe (isaactighe), updated by Andrei Macari (andriuhanfs)
Relevance: if a substance is short in both countries, it can't just be
imported from the other one.
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
Author: Mihály Kányási (marcellhoi4)
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
Author: Mihály Kányási (marcellhoi4)
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

## Query 9

```
Q9: how long have ongoing shortages lasted, per country, and what share has
run for more than a year?
Author: Eduard Patachia (EduardPatachia)
Relevance: a short disruption can be bridged from stock, but a shortage that
stays open for months or years means patients and pharmacies have had to
switch treatment or import. Comparing France and the United States shows
where shortages are chronic rather than temporary. Durations are measured
from the reported start_date to today, so the numbers grow when re-run; a
shortage still listed as ongoing may have stopped being updated by its source.
```

2 row(s)

| country | ongoing_shortages | avg_days_ongoing | longest_days_ongoing | over_one_year | pct_over_one_year |
|---|---|---|---|---|---|
| United States | 70 | 2022 | 5395 | 66 | 94.3 |
| France | 298 | 625 | 4452 | 182 | 61.1 |

## Query 10

```
Q10: what reasons do the reporting sources give for ongoing shortages, and
how many shortages have no stated reason?
Author: Eduard Patachia (EduardPatachia)
Relevance: prevention depends on cause. Manufacturing problems, demand
spikes and discontinuations call for different policy responses, so the most
common stated reasons show where action would help most. Only openFDA
publishes a reason; BDPM does not, so France appears only as "Not stated".
Reasons are free text, so near-identical wordings are counted separately.
```

10 row(s)

| country | stated_reason | ongoing_shortages | distinct_medicines | pct_of_country |
|---|---|---|---|---|
| France | Not stated | 298 | 298 | 100.0 |
| United States | Other | 27 | 27 | 38.6 |
| United States | Demand increase for the drug | 14 | 14 | 20.0 |
| United States | Discontinuation of the manufacture of the drug | 8 | 8 | 11.4 |
| United States | Delay in shipping of the drug | 5 | 5 | 7.1 |
| United States | Not stated | 5 | 5 | 7.1 |
| United States | Requirements related to complying with good manufacturing practices | 5 | 5 | 7.1 |
| United States | Shortage of an active ingredient | 4 | 4 | 5.7 |
| United States | Regulatory delay | 1 | 1 | 1.4 |
| United States | Shortage of an inactive ingredient component | 1 | 1 | 1.4 |

## Query 11

```
Q11: which ongoing shortages are full stock-outs of a medicine that has no
recorded alternative?
Author: Isaac Tighe (isaactighe)
Relevance: these are the cases where patients are most at risk under our
problem statement: the medicine is not available at all and the database
knows of no substitute to switch to. Neither real source supplies
alternatives, so a missing alternative here means "none recorded", not
"none exists"; the list shows where verified substitute data is most needed.
```

51 row(s)

| country | medicine | form | strength | shortage_since |
|---|---|---|---|---|
| France | Potassium (Clavulanate De) + Ticarcilline Sodique | Injection, Powder, For Solution | 0,238g + 5,572g | 2014-08-01 |
| France | Potassium (Clavulanate De) + Ticarcilline Sodique | Injection, Powder, For Solution | 0,238g + 3,343g | 2014-08-01 |
| France | Methotrexate | Solution A Diluer Pour Perfusion | 100mg | 2023-01-12 |
| France | Acide Para-Aminosalicylique | Granules Gastro-Resistant(E) | 4g | 2023-07-20 |
| France | Alprostadil | Injection, Solution | 0,5mg | 2023-10-06 |
| France | Urokinase (Mammifere/Humain/Urine) | Injection, Powder, For Solution | 100000ui | 2023-10-06 |
| France | Urokinase (Mammifere/Humain/Urine) | Injection, Powder, For Solution | 600000ui | 2023-10-06 |
| France | Pyrimethamine | Tablet | 50,0mg | 2023-10-27 |
| France | Sulfate De Vindesine | Injection, Powder, For Solution | 5mg | 2023-10-27 |
| France | Phosphate D'Iproniazide | Tablet | 77,42mg | 2023-11-15 |
| France | Facteur Ii De Coagulation Humain + Facteur Ix De Coagulation Humain + Facteur Vii De Coagulation Humain + Facteur X De Coagulation Humain + Proteine C Humaine + Proteine S | Poudre Et Solvant Pour Solution Injectable | 14-35ui + 25ui + 7-20ui + 14-35ui + 11-39ui + 1-8ui | 2023-11-27 |
| France | Avalglucosidase Alfa | Poudre Pour Solution A Diluer Pour Perfusion | 100mg | 2024-02-14 |
| France | Midazolam | Solution | 2mg | 2024-02-15 |
| France | Hydrocortisone (Acetate D') | Mousse | 2g | 2024-02-29 |
| France | Aztreonam | Injection, Powder, For Solution | 1g | 2024-04-04 |
| France | Praziquantel | Tablet, Film Coated | 600mg | 2024-09-09 |
| France | Clorazepate Dipotassique | Lyophilisat Et Solution Pour Usage Parenteral | 20mg | 2024-10-02 |
| France | Pomalidomide | Capsule | 2mg | 2024-12-20 |
| France | Pomalidomide | Capsule | 4mg | 2024-12-20 |
| France | Pomalidomide | Capsule | 1mg | 2024-12-20 |
| France | Pomalidomide | Capsule | 3mg | 2024-12-20 |
| France | Acide Glutamique + Acide Lactobionique + Chlorure De Calcium Dihydrate + Chlorure De Magnesium Hexahydrate + Chlorure De Potassium + Glutathion + Histidine + Hydroxyde De Sodium + Mannitol | Solution | 2,942g + 28,664g + 0,037g + 2,642g + 1,118g + 0,921g + 4,65g + 4g + 10,93g | 2025-02-06 |
| France | Epirubicine (Chlorhydrate D') | Poudre Pour Solution Pour Perfusion | 10mg | 2025-03-14 |
| France | Chlorhydrate De Maprotiline | Tablet, Film Coated | 25mg | 2025-03-28 |
| France | Maprotiline (Chlorhydrate De) | Tablet, Film Coated | 75mg | 2025-03-28 |

_26 more rows not shown._

## Query 12

```
Q12: in each country, how many ongoing shortages fall on each dosage form,
and what share of that country's shortages is it?
Author: Isaac Tighe (isaactighe)
Relevance: our problem statement is that patients lose access to medicines
they depend on. Injectables are used mostly in hospitals, where a missing
vial can delay surgery or chemotherapy, while tablets and capsules are
dispensed by community pharmacies. Knowing which forms are short tells each
country whether hospitals or pharmacies need the warning first. BDPM forms
are translated with FORM_FR_EN; forms with no translation stay in French and
'Unspecified' means the source gave no form.
```

57 row(s)

| country | dosage_form | ongoing_shortages | distinct_substances | pct_of_country |
|---|---|---|---|---|
| Belgium | Injection | 1 | 1 | 100.0 |
| France | Tablet, Film Coated | 52 | 25 | 17.3 |
| France | Injection, Solution | 48 | 26 | 16.0 |
| France | Tablet | 47 | 30 | 15.7 |
| France | Capsule | 43 | 13 | 14.3 |
| France | Injection, Powder, For Solution | 20 | 13 | 6.7 |
| France | Ophthalmic Solution | 19 | 15 | 6.3 |
| France | Solution A Diluer Pour Perfusion | 6 | 6 | 2.0 |
| France | Suspension Injectable A Liberation Prolongee | 6 | 1 | 2.0 |
| France | Tablet, Orally Disintegrating | 5 | 1 | 1.7 |
| France | Lyophilisat Pour Usage Parenteral | 4 | 1 | 1.3 |
| France | Poudre Et Solvant Pour Solution Injectable | 4 | 4 | 1.3 |
| France | Poudre Et Solvant Pour Suspension Injectable A Liberation Prolongee | 4 | 2 | 1.3 |
| France | Poudre Pour Solution A Diluer Pour Perfusion | 4 | 4 | 1.3 |
| France | Suspension Injectable | 4 | 4 | 1.3 |
| France | Granules | 3 | 2 | 1.0 |
| France | Lyophilisat Et Solution Pour Usage Parenteral | 3 | 3 | 1.0 |
| France | Solution | 3 | 3 | 1.0 |
| France | Granules Gastro-Resistant(E) | 2 | 2 | 0.7 |
| France | Poudre Et Poudre Pour Solution Buvable | 2 | 2 | 0.7 |
| France | Poudre Et Solvant Pour Suspension Injectable | 2 | 2 | 0.7 |
| France | Poudre Pour Solution Pour Perfusion | 2 | 2 | 0.7 |
| France | Suspension | 2 | 2 | 0.7 |
| France | Cream | 1 | 1 | 0.3 |
| France | Film Orodispersible | 1 | 1 | 0.3 |

_32 more rows not shown._
