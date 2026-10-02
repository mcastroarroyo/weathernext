# GDE-Niño workspace rules

These rules apply to every task in this workspace.

## Safety and wording

- GDE-Niño is **decision support, never an alert**. In any text, UI or message, say «nivel de riesgo», never «alerta amarilla/naranja/roja». Official SNGR and INAMHI information always ranks above the twin.
- Every deployed page must keep the legal notice (`Aviso legal y de uso`) and the badge that says whether data is real or simulated. Do not remove or shorten them; the text is under legal review (`docs/legal/aviso-legal-borrador.md`).
- Label estimates as estimates: vulnerability, population per area, the parish split and ECU 911 calls are demo values.

## The user's cloud

- Deploy only to the project the user names, after a `--dry-run` they have seen and approved.
- Never change IAM, billing, organisation policies or budgets on the user's behalf; report what is missing.
- Default to a **private** Cloud Run service. Make it public only on explicit request.
- Never delete resources without explicit confirmation of each one (see the `teardown-gde-nino` skill).
- Never create or download service-account keys; use the user's `gcloud` login or Workload Identity Federation.

## Data and the repository

- Never write project IDs, project numbers, keys, tokens or personal data into files that are committed. Use environment variables (`GCP_PROJECT_ID`) and `--project` flags.
- The MIT *Red Vial Estatal* data lives only in `demo/twin/data/mit/` and is git-ignored. Never commit it or derived files (`red_vial_mit.*`).
- Respect source licences and attribution: ECMWF Open Data and GEOGloWS (CC BY 4.0), INEC boundaries via OCHA COD-AB (CC BY-IGO).

## Working style

- When a command fails, show the exact error and stop; do not retry with broader permissions.
- This project is built and maintained with AI assistance under human supervision. Summarise every change you make, and leave decisions with legal or public impact to a person.
