---
name: deploy-gde-nino
description: Deploy the GDE-Niño El Niño digital twin (Cloud Run page + BigQuery dataset) into the user's own Google Cloud project. Use when the user asks to install, deploy, set up or publish GDE-Niño / the gemelo digital in their GCP project.
---

# Deploy GDE-Niño into the user's Google Cloud project

The deployment target is always **the user's own project**. Never assume a project: ask for the project ID and region, and repeat them back before changing anything.

## Before running

1. Confirm `gcloud auth list` shows the account the user expects; if not, ask them to run `gcloud auth login` themselves.
2. Ask:
   - Project ID and region (default `us-central1`).
   - Public or private service. **Default is private**; only pass `--public` if the user explicitly wants anyone with the link to open it, and remind them the page must keep its legal notice.
   - Whether to load today's real forecast (`--with-forecast`, ~15 min and a ~675 MB ECMWF download, writes BigQuery tables) or deploy with the El Niño scenario only.
   - Whether they hold the MIT *Red Vial Estatal* shapefile. If so, it goes in `demo/twin/data/mit/` before deploying; it must never be committed.
3. Show the plan with a dry run and wait for an explicit "yes":

```bash
.agents/skills/deploy-gde-nino/scripts/deploy.sh --project <PROJECT_ID> --region <REGION> --dry-run
```

## Run

```bash
.agents/skills/deploy-gde-nino/scripts/deploy.sh --project <PROJECT_ID> --region <REGION> [--with-forecast] [--public]
```

What it does: preflight (account, project access, billing, roles) → enables Cloud Run, Cloud Build, Artifact Registry and BigQuery APIs → creates `ectwin_commons` (US) if missing → optional forecast pipeline → builds the page → deploys Cloud Run service `gde-nino` labelled `app=ectwin`.

## After running

- Run the `verify-deployment` skill.
- Report the service URL, whether it is public or private, and what was created.
- Costs: Cloud Run scales to zero; BigQuery storage is a few MB per forecast run; the ECMWF download is free (CC BY 4.0). Suggest a budget alert filtered on label `app=ectwin`.

## Stop and ask the user when

- The preflight shows no billing or insufficient roles: report the exact message; do not try to change IAM or billing.
- An organisation policy blocks public access (`--public`): keep the service private and report the error.
- Any command fails: show the exact error and stop; do not retry with broader permissions.
