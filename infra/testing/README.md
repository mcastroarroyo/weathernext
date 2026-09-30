# GDE-Niño test environment

The test environment runs the first GDE-Niño pipelines in an existing Google Cloud project (a Wursta test project) before the production projects of [10-setup-and-deployment.md](../../docs/10-setup-and-deployment.md) exist. GitHub Actions deploys and runs everything through Workload Identity Federation, so no service-account keys exist anywhere. The project ID is never written in this public repository; it lives only in the GitHub secret `GCP_PROJECT_ID`.

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| Service account | `ectwin-ci` | Used by GitHub Actions (Terraform, loads, queries) |
| Service account | `ectwin-runner` | Runs pipeline jobs inside the project (later phases) |
| Workload Identity pool / provider | `ectwin-github` / `github` | Trusts only GitHub Actions tokens from `mcastroarroyo/weathernext` |
| GCS bucket | `<PROJECT_ID>-ectwin-tfstate` | Terraform state (versioned) |
| BigQuery datasets (`US`) | `ectwin_commons`, `ectwin_ops` | National shared products and run logs (the "Commons" of the plan) |
| BigQuery datasets (`US`) | `ectwin_pilot_mit`, `ectwin_pilot_otavalo`, `ectwin_pilot_ecu911` | Simulated tenant workspaces for the three pilot institutions; in production each institution uses its own GCP project |
| GCS buckets (`us-central1`) | `<PROJECT_ID>-ectwin-raw`, `<PROJECT_ID>-ectwin-curated` | Raw captures (never auto-deleted) and pipeline outputs |
| Artifact Registry | `ectwin` (Docker) | Pipeline images (later phases) |
| Secret Manager | `ewds-api-key`, `cds-api-token`, `typesafe-api-key`, `floodforecasting-api-key`, `earthdata-credentials`, `copernicusmarine-credentials` | Empty containers; people add the values, CI never does |

Everything carries the labels `app=ectwin`, `env=test` and the `ectwin` prefix, so it can share the project with other work.

## Set-up (once, about 15 minutes)

1. **Cloud Shell bootstrap** (project Owner, test project selected):

   ```bash
   git clone https://github.com/mcastroarroyo/weathernext.git && cd weathernext
   git checkout claude/ecuador-digital-twin-el-nino-xts888
   bash scripts/testing/bootstrap-ci-wif.sh --project <PROJECT_ID>
   ```

   It enables the APIs, creates the two service accounts, the state bucket and the Workload Identity pool, and prints three values. If it stops at the OIDC provider, an organisation policy restricts identity providers; ask the organisation admin to allow `https://token.actions.githubusercontent.com` for this project and re-run.
2. **GitHub secrets.** Store the three printed values as repository **secrets** (Settings → Secrets and variables → Actions): `GCP_PROJECT_ID`, `GCP_WIF_PROVIDER`, `GCP_CI_SA`. Secrets are masked in the public Actions logs.
3. **Deploy.** Actions → `testing-deploy` → Run workflow (branch `claude/ecuador-digital-twin-el-nino-xts888`, apply ticked). It creates the datasets, buckets, registry and secret containers.
4. **Copernicus key (for GloFAS).** Create an ECMWF/Copernicus account, accept the licence on the EWDS page of `cems-glofas-forecast` (and `cems-glofas-seasonal`), copy the API key from the profile page and store it without echoing:

   ```bash
   read -rs KEY && printf %s "$KEY" | gcloud secrets versions add ewds-api-key --data-file=- --project=<PROJECT_ID> && unset KEY
   ```

   Until this exists, the GloFAS step is skipped and the rest still runs.
5. **Run the pipelines.** Actions → `testing-pipelines` → Run workflow, `suite = baseline` first (boundaries, Google flood reanalysis and flood history), then `suite = daily` (ECMWF ensemble rainfall by canton, ENSO indices, GloFAS if the key exists). `daily` also runs on a schedule.
6. **Check.** BigQuery → dataset `ectwin_commons` should list `dim_admin`, `grrr_outlets`, `grrr_return_periods`, `grrr_annual_max`, `grrr_elnino_peaks`, `inundation_history_canton`, `ecmwf_ens_canton_exceedance`, `enso_indices` (and `glofas_reach_forecast` once the key is stored).

Optional, when needed: register Earth Engine for the project at `https://code.earthengine.google.com/register?project=<PROJECT_ID>` (a company testing for public institutions registers as **commercial**; the Limited plan charges only usage), and set a project budget with alerts in Billing.

## Cost guardrails

- Every query sets `maximum_bytes_billed`; the pipelines read public buckets (Google flood data, ECMWF open data) without copying global files.
- Expected cost of the baseline run is cents (a few hundred MB of GCS reads, small BigQuery loads, which are free); the daily run is a few MB.
- Remove everything with `terraform destroy` in this folder (state in the `-ectwin-tfstate` bucket), then delete the two service accounts and the Workload Identity pool.

## Moving to production

The same Terraform variables and pipelines point at `ectwin-commons-prod` once it exists ([10 §5](../../docs/10-setup-and-deployment.md)). Pilot datasets move to each institution's own project with [the tenant bootstrap](../tenant-bootstrap/README.md). Approvals tied to this test project (Flood Forecasting API, Earth Engine registration) must be requested again, or extended, for the production projects.
