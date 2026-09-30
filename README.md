# GDE-Niño — Gemelo Digital Ecuador – El Niño

**GDE-Niño** (the "Ecuador El Niño Digital Twin") is an implementation-ready plan for a decision-support digital twin that helps Ecuador's government and private actors manage the very strong El Niño now under way, with peak impacts expected Nov 2026 – Mar 2027. It runs the loop *observe → forecast → simulate impacts → what-if → decide → verify*, from hours to seven months ahead. It turns WeatherNext, the Google Flood Forecasting API, GloFAS, seasonal outlooks and exposure data into parish-level probabilities, impact estimates and evidence packs, always shown beneath the official alerts. Signed-in users get a free national view; organisations save and run their work in their own Google Cloud project. TypeSafe Jev keeps typed AI decisions cheap.

> *Apoyo a la decisión probabilístico y en español, en el propio proyecto de Google Cloud de cada institución; nunca una alerta oficial.*

**Status: Planning package — September 2026; not yet implemented.** The repository holds 16 planning documents and six reference starters, but no application code. Phase 0 began on 2026-09-29 and the MVP go-live target is **2026-11-27** ([12](docs/12-roadmap-team-budget.md#1-urgency-and-phase-overview)).

## Key design decisions

1. **Decision support, never alerts.** Official alerts appear verbatim above model output; the twin says *nivel de riesgo*, never "alerta amarilla/naranja/roja".
2. **Three planes.** P1 control plane `ectwin-platform-prod` (operator-paid); P2 Commons `ectwin-commons-prod` (sponsor-paid, computes national products once); P3 each organisation's own GCP project (tenant-paid).
3. **Sign-in required.** Google or email/password via Identity Platform; TOTP MFA for Owners, Admins, operators and *Firmantes técnicos*.
4. **No project (T0), nothing saved.** A read-only national view built from Commons products.
5. **Own project to save.** Sessions, AOIs, reports, runs and models live in the tenant's Firestore, BigQuery and bucket, in an organisation-owned project.
6. **One revocable grant.** The broker holds only `roles/iam.serviceAccountTokenCreator` on `ectwin-runner` and mints 900-second tokens; no service-account keys are used.
7. **Whoever owns or runs it pays.** The operator never resells GCP; sponsored T4 projects cover *GAD*s and *COE*s that cannot procure quickly.
8. **Forecast stack.** WeatherNext 3 leads for 0–15 days, WeatherNext 2 adds El Niño hindcasts and scenarios, and IFS/AIFS is the fallback. Flood API snapshots (at least every 6 h) join GloFAS and GEOGloWS; C3S, NMME and CFSv2 cover the season.
9. **WeatherNext licence discipline.** The Commons publishes only non-retrievable value-added derivatives or CC BY 4.0 historic data, never raw real-time fields.
10. **Probabilistic and verified.** Probabilities, spread, analogs and a confidence indicator; truth from INAMHI stations and CHIRPS v3; public weekly scorecards from 2026-11-23.
11. **Jev for typed decisions, Gemini for prose.** Code computes every number; `jev-1.13.0` answers typed questions (yes/no: below 0.30 no, 0.30–0.70 human review, above 0.70 yes); humans sign off anything public.
12. **Regions.** BigQuery in `US`; GCS and Cloud Run in `us-central1`; tenant Firestore and `.gob.ec` ingestion in `southamerica-west1`.
13. **Guardrails by default.** Budget alerts at 50/90/100%, BigQuery quotas, `maximumBytesBilled` and an Earth Engine cap; at 100%, scheduled jobs pause and billing stays on.
14. **Spanish-first and open.** Mobile web app (≤200 KB first view), daily PDFs for 221 cantons, WhatsApp cards and an Apache-2.0 core.

## Document map

| File | Question it answers | Primary audience |
|---|---|---|
| [00-executive-summary.md](docs/00-executive-summary.md) | What is proposed, at what cost, and what to decide now? | Sponsor, SNGR, INAMHI |
| [00-resumen-ejecutivo.md](docs/00-resumen-ejecutivo.md) | The same, in Spanish | Ecuadorian authorities |
| [01-context-el-nino-ecuador.md](docs/01-context-el-nino-ecuador.md) | Why now, and who decides what? | Everyone |
| [02-users-requirements-ux.md](docs/02-users-requirements-ux.md) | Who uses it, and what must it do (76 FRs, 34 NFRs)? | Product, UX, pilots |
| [03-architecture.md](docs/03-architecture.md) | How is it built: planes, components, storage, API? | Engineers |
| [04-identity-tenancy-byo-gcp.md](docs/04-identity-tenancy-byo-gcp.md) | How do sign-in, project connection and access control work? | Platform engineers, tenant IT, DPO |
| [05-data-catalog.md](docs/05-data-catalog.md) | Which data, under which licence, and how is it ingested? | Data engineers, legal |
| [06-forecast-model-stack.md](docs/06-forecast-model-stack.md) | Which forecast serves each horizon? | Forecast scientists |
| [07-impact-modules-and-triggers.md](docs/07-impact-modules-and-triggers.md) | How do hazards become impacts, risk levels and triggers? | Risk analysts, insurers, financiers |
| [08-ai-decision-layer-jev.md](docs/08-ai-decision-layer-jev.md) | Where do Jev and Gemini help, safely and cheaply? | AI engineers, DPO |
| [09-cost-model.md](docs/09-cost-model.md) | What does it cost, and who pays? | Finance, sponsor, tenants |
| [10-setup-and-deployment.md](docs/10-setup-and-deployment.md) | How do we reach the first run and the first tenant? | Platform lead, SRE, tenant admins |
| [11-operations-runbook.md](docs/11-operations-runbook.md) | How is it run daily and at the peak? | Operations, on-call |
| [12-roadmap-team-budget.md](docs/12-roadmap-team-budget.md) | When, by whom, and for how much? | Sponsor, programme management |
| [13-governance-legal-risk.md](docs/13-governance-legal-risk.md) | What are the legal limits and top risks? | Legal, DPO, Steering Committee |
| [14-verification-and-validation.md](docs/14-verification-and-validation.md) | How do we prove it works? | Forecast leads, trigger partners |

## Reference starter files

Reference code, not production code; checks re-run on 2026-09-30.

| Path | What it does | How it was validated |
|---|---|---|
| [infra/tenant-bootstrap/](infra/tenant-bootstrap/README.md) | Terraform module v0.1.0 that makes a project a tenant: runner account, datasets, bucket, Firestore, budget and the single broker grant (46 resources for T1) | `terraform fmt`, `terraform validate` and 5 offline plan tests pass (Terraform 1.16.4, providers 8.5.0). Not yet applied to a real project (AC-01, 2026-10-09) |
| [scripts/bootstrap-tenant.sh](scripts/bootstrap-tenant.sh) | Idempotent `gcloud`/`bq` equivalent, with `--dry-run` and `--revoke-broker` | `bash -n` and `shellcheck -S style` clean; stubbed end-to-end runs. CLI flags **(to confirm)** |
| [scripts/verify-tenant.sh](scripts/verify-tenant.sh) | Read-only checks VT-01 to VT-20, with `--json` and `--strict` | The same shell checks and stubbed runs |
| [catalog/data-sources.yaml](catalog/data-sources.yaml) | Registry of 99 sources with endpoint, licence, cadence, plane and owner | Parses, with unique ids; 96 identifiers confirmed in the research briefs. `.gob.ec` endpoints are re-probed by 2026-10-09 |
| [schemas/decisions/](schemas/decisions/) | 11 Jev templates (S1–S6, B1–B5): `/v1/systemone` bodies pinned to `jev-1.13.0` | All parse as JSON and render through `render_template()` |
| [services/decision/decision_backend.py](services/decision/decision_backend.py) | `DecisionBackend` with TypeSafe, gateway, Gemini adapter (placeholder) and open-weight backends; failover, circuit breaker, data-class guard | Offline tests with mocked HTTP pass. Live API tests are pending (AI-03, 2026-10-09) |

## Quick start

### (a) Decision makers

1. Read the [executive summary](docs/00-executive-summary.md) or [resumen ejecutivo](docs/00-resumen-ejecutivo.md), then act on the six asks for this week in [§9](docs/00-executive-summary.md#9-decisions-and-asks-for-leadership-this-week).
2. Headline numbers: 12-month cash is ≈US$1,600,220 (full) or ≈US$1,022,922 (minimum). Bridge funding is US$305,311 (floor US$223,776), and cloud is 1.6% of the full budget ([12 §5](docs/12-roadmap-team-budget.md#5-budget)). The risks are ranked in [13 §11](docs/13-governance-legal-risk.md#11-risk-register).

### (b) Engineers

1. Read [03](docs/03-architecture.md), [04](docs/04-identity-tenancy-byo-gcp.md) and [10](docs/10-setup-and-deployment.md), and file the day-1 access requests in [10 §2](docs/10-setup-and-deployment.md#2-day-1-access-request-checklist).
2. Run the starter checks:

   ```bash
   bash -n scripts/*.sh && shellcheck -S style scripts/*.sh
   cd infra/tenant-bootstrap && terraform init -backend=false && terraform validate && terraform test
   ```

### (c) Tenant organisations

Full walkthrough: [10 §6](docs/10-setup-and-deployment.md#6-tenant-onboarding-walkthrough-p3) and the [bootstrap manual](infra/tenant-bootstrap/README.md).

1. **Prepare** an organisation-owned GCP project with billing, or request a T4 sponsored project.
2. **Sign in** and enrol TOTP. In *Conectar proyecto*, choose a tier and commercial or noncommercial use, then copy the 24-hour connection code.
3. **Bootstrap** in Cloud Shell (≈8–12 min) with `scripts/bootstrap-tenant.sh --project <TENANT_PROJECT> --tier T1 --budget-usd 20 --connection-code <CODE>`. Terraform also works; one-time OAuth (path B) is expected from 2026-11-13 (estimate).
4. **Verify** with `scripts/verify-tenant.sh --project <TENANT_PROJECT>`, then choose *Conectar* to run preflight checks PF-01 to PF-15.
5. **Register Earth Engine** (commercial Limited plan for operational government use unless Google confirms otherwise) and subscribe to `ectwin_commons`. From T2 up, also file the WeatherNext form.
6. **Start** the pipelines, draw an AOI and invite a second Owner.

Monthly cost before 15% IVA: T1 ≈US$0–14, T2 ≈US$20–60, T3 ≈US$540–800 ([09 §4](docs/09-cost-model.md#4-monthly-estimates)).

## Key external services

| Service | Role | Links |
|---|---|---|
| WeatherNext 3 and 2 | 64-member AI weather ensembles, 0–15 days; data free today | [dissemination guide](https://developers.google.com/weathernext/guides/dissemination) · [terms of use](https://storage.googleapis.com/weathernext-public/terms-of-use.pdf) · [request form](https://docs.google.com/forms/d/e/1FAIpQLSeCf1JY8G78UDWzbm0ly9kJxfSjUIJT5WyMR_HiNqCm-IHIBg/viewform) (third-party link; to confirm) · [repository](https://github.com/google-deepmind/weathernext) |
| Flood Forecasting API | Gauges, flood status, flash floods; per-project waitlist | [waitlist](http://sites.research.google/gr/floodforecasting/api-waitlist/) · `https://floodforecasting.googleapis.com/v1` · [OpenHydroNet](https://github.com/google-research/flood-forecasting) |
| TypeSafe Jev | Typed decisions at US$0.042 per 1M input tokens | [models](https://docs.typesafe.ai/models) · [console](https://console.typesafe.ai/) · `https://api.typesafe.ai/v1/systemone` |
| Earth Engine | Raster analytics; each tenant registers | [pricing](https://cloud.google.com/earth-engine/pricing) · [noncommercial tiers](https://developers.google.com/earth-engine/guides/noncommercial_tiers) · [cost controls](https://developers.google.com/earth-engine/guides/cost_controls) |
| Identity Platform | Sign-in and MFA; free to 50,000 MAU | [pricing](https://cloud.google.com/identity-platform/pricing) · [multi-tenancy](https://docs.cloud.google.com/identity-platform/docs/multi-tenancy-authentication) |

## Request traceability

Where each element of the original request is answered:

| Request element | Answered in |
|---|---|
| WeatherNext | [06 §3](docs/06-forecast-model-stack.md#3-weathernext-3-and-weathernext-2); [09 §3](docs/09-cost-model.md#3-cost-minimisation-levers) L04, L05, L26 |
| Flood Forecasting API | [06 §4](docs/06-forecast-model-stack.md#4-river-forecasting); [04 §9](docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead) |
| Jev to minimise creation cost | [08 §3](docs/08-ai-decision-layer-jev.md#3-jev-in-the-build-phase-minimising-the-cost-of-creating-the-twin); [09 §3.1](docs/09-cost-model.md#31-creation-cost-levers-from-the-three-named-technologies), [§5](docs/09-cost-model.md#5-one-time-build-phase-cloud-costs) B9 |
| Sign in with Google or email | [04 §2](docs/04-identity-tenancy-byo-gcp.md#2-identity-identity-platform-and-sessions); [02 §5.2](docs/02-users-requirements-ux.md#52-requirements) FR-001 |
| Own project to save | [04 §5](docs/04-identity-tenancy-byo-gcp.md#5-what-the-bootstrap-provisions-in-the-tenant-project); [03 §5.6](docs/03-architecture.md#5-storage-layout); [04 §12.2](docs/04-identity-tenancy-byo-gcp.md#122-data-inventory) |
| No project (T0) | [02 §3.1](docs/02-users-requirements-ux.md#31-rules); [J9](docs/02-users-requirements-ux.md#4-user-journeys) |
| Who pays | [09 §1](docs/09-cost-model.md#1-who-pays-what); [04 §7](docs/04-identity-tenancy-byo-gcp.md#7-who-pays-for-each-call) |
| Private sector | [02 §2](docs/02-users-requirements-ux.md#2-personas) P10, P11, J4, J5, [J10](docs/02-users-requirements-ux.md#j10--insurer-or-bank-portfolio-exposure-and-claims-surge-planning); [07 §6.6](docs/07-impact-modules-and-triggers.md#66-evidence-packs-including-parametric-insurance) |
| Data freshness | [02 §6.2](docs/02-users-requirements-ux.md#62-data-freshness-targets); [05 §4.2](docs/05-data-catalog.md#42-source-registry-and-health-checks); [11 §4.3](docs/11-operations-runbook.md#43-operational-tables) |
| Setup | [10](docs/10-setup-and-deployment.md) |
| Running | [11](docs/11-operations-runbook.md) |
| Roadmap and budget | [12](docs/12-roadmap-team-budget.md) |

## Disclaimer

- **Decision support, not official alerts.** Only SNGR declares alerts; INAMHI, CN-ERFEN and INOCAR issue their own warnings and statements. Outputs are labelled *apoyo a la decisión / pronóstico experimental*. In an emergency, follow SNGR, ECU 911 and your *COE*.
- **WeatherNext data is experimental.** The Real-Time Weather Forecasting Experimental Data terms were last modified on 2026-09-03. Terms can change on 14 days' notice, fees can start on one month's notice, and access can be suspended ([13 §3](docs/13-governance-legal-risk.md#3-third-party-terms-matrix)).
- **This is a plan.** Prices are dated 2026-09-29, many figures are estimates, and some El Niño figures still await checks at source ([01 §5.4](docs/01-context-el-nino-ecuador.md#54-conflicts-and-verification-backlog-phase-0-due-16-oct-2026)).

## Licence

Apache-2.0 is proposed for code, IaC and schemas, and CC BY 4.0 for documentation ([13 §6](docs/13-governance-legal-risk.md#6-open-source-licensing)). **There is no `LICENSE` file yet**, so both remain proposals. Third-party data keeps its own licences, and GPL engines such as SFINCS ship only as separate source-built images.

## Contributing

- **Workflow (proposed):** short branches, Conventional Commit subjects, DCO sign-off (`git commit -s`) and SPDX headers ([10 §10.4](docs/10-setup-and-deployment.md#104-conventions)). Run the starter checks, and never commit secrets, keys or personal data.
- **Docs:** write in English with Spanish terms in italics, and cite sources inline. Mark **(unverified)** and **(to confirm)** items. Never invent URLs, IDs or numbers, and use relative links.
- **Consistency:** change the owning document first (costs 09, dates 12, names 03), then its echoes. Never use "alerta amarilla/naranja/roja" for platform outputs.
