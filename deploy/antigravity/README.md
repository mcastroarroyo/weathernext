# Deploying GDE-Niño with Google Antigravity

Institutions install the twin in **their own** Google Cloud project with an AI agent in [Google Antigravity](https://antigravity.google). This folder holds the bootstrap script and the agent scaffold (rules + skills) the agent follows.

## 1. Bootstrap the workspace (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/mcastroarroyo/weathernext/claude/demo-twin-real-data/deploy/antigravity/bootstrap.sh | bash
```

It checks `git`, `gcloud`/`bq`, Python, Node.js and Antigravity, clones the repository to `~/gde-nino`, installs `.agents/` and `AGENTS.md` at the workspace root (git-excluded), and opens the folder in Antigravity. It installs no software, does not sign in and touches no cloud project. Options: `--dir <path>`, `--branch <branch>`, `--no-open`.

## 2. Ask the agent

Sign in first with `gcloud auth login`, then in Antigravity:

> Deploy GDE-Niño in my project `<PROJECT_ID>`, region `us-central1`.

The `deploy-gde-nino` skill asks the open questions (private or public, real forecast or scenario only, MIT data), shows a `--dry-run`, and deploys only after you approve.

| Skill | What it does |
|---|---|
| `deploy-gde-nino` | Preflight (account, access, billing, roles) → enable APIs → BigQuery `ectwin_commons` → optional forecast pipeline → build page → Cloud Run `gde-nino` (private by default, label `app=ectwin`) |
| `refresh-forecast` | Latest ECMWF ENS + GEOGloWS → BigQuery → page → redeploy (`demo/twin/refresh.sh`) |
| `verify-deployment` | Read-only checks: service responds, legal notice present, public/private, BigQuery rows |
| `teardown-gde-nino` | Lists resources and deletes only what the user confirms one by one |

The rules (`workspace/.agents/rules/gde-nino.md`) keep the agent inside guardrails: no alerts wording, legal notice always present, no IAM/billing changes, no keys, no project IDs or MIT data in commits, stop on errors.

## Without Antigravity

The skills are plain scripts and work from any terminal:

```bash
deploy/antigravity/workspace/.agents/skills/deploy-gde-nino/scripts/deploy.sh --project <PROJECT_ID> --dry-run
```

## Responsibility

Deployment happens in the institution's project, under its account, permissions, costs and policies (see clause 6 of [`docs/legal/aviso-legal-borrador.md`](../../docs/legal/aviso-legal-borrador.md)). The scaffold was built with AI assistance (Claude Code) and should be reviewed before production use.
