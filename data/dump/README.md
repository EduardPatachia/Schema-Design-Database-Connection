# Medicine shortage database dump

MySQL dump of the database from our KEN2110 Databases group project at
Maastricht University (2026). It stores medicine shortages per country, the
authority that reported them and the companies involved.

Code and documentation:
https://github.com/EduardPatachia/Schema-Design-Database-Connection

## Contents

`medicine_shortage_tracker.sql` creates the `medicine_shortage_tracker`
database with 12 tables and all their constraints. It has 387 shortages:

- 15 made-up shortages from our seed data
- 74 from openFDA Drug Shortages (US), feed updated 30/09/2026
- 298 from the French BDPM (ANSM), shortage file updated 28/09/2026

To load it (MySQL 8.0.16 or newer):

```
mysql -u root -p < medicine_shortage_tracker.sql
```

## Licence

CC BY 4.0. The dump uses data from:

- openFDA (https://open.fda.gov), CC0 1.0. Data provided by the U.S. Food and
  Drug Administration.
- Base de données publique des médicaments (BDPM), ANSM. Shortage file updated
  28/09/2026, product and composition files 29/09/2026, ATC file 03/06/2026.
  Licence Ouverte / Open Licence.

## Personal data

There is no personal data in the dump. Shortages are stored per medicine and
not per patient, the reported companies are all companies, and the facility
names are made up.

## Authors

Eduard Patachia, Andrew Macari, Isaac Tighe, Mihály Kányási
