# GDE-Niño — agent guide

This workspace deploys and operates the **Gemelo Digital Ecuador – El Niño** twin in the user's own Google Cloud project. Read `.agents/rules/gde-nino.md` first; it overrides anything else.

## What lives where

| Path | Purpose |
|---|---|
| `demo/twin/` | The twin page, forecast pipeline (ECMWF ENS + GEOGloWS) and Cloud Run container |
| `docs/` | The full plan (architecture, data catalogue, governance) |
| `docs/legal/aviso-legal-borrador.md` | Draft legal notice (pending legal review) |
| `.agents/skills/` | `deploy-gde-nino`, `refresh-forecast`, `verify-deployment`, `teardown-gde-nino` |

## Typical requests

- "Install / deploy GDE-Niño in my project" → `deploy-gde-nino` (dry run first, private by default).
- "Update the forecast" → `refresh-forecast`.
- "Is it working?" → `verify-deployment`.
- "Remove it" → `teardown-gde-nino` (explicit confirmation per resource).

## Prerequisites on this machine

`gcloud` (with `bq`), `git`, Python 3.10+, Node.js 18+ (for `npx mapshaper` in `demo/twin/data/prep_geo.sh`). The user signs in with `gcloud auth login`; the agent never handles passwords or keys.
