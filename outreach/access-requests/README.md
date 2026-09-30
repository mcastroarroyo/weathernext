# Phase 0 access requests: filing pack

This pack turns each day-1 access request of [10 §2](../../docs/10-setup-and-deployment.md#2-day-1-access-request-checklist) into a copy-paste task of about five minutes. The requests are web forms, registrations and e-mails, so a person signed in with the right Google or institutional account has to submit them; nothing here can be submitted automatically. IDs AR-01…AR-08 are the same as in [10 §2.1](../../docs/10-setup-and-deployment.md#21-checklist) and the Phase 0 tracker in [12 §2.1](../../docs/12-roadmap-team-budget.md#21-phase-0--mobilise-2026-09-29--2026-10-16).

- **Status date: Thu 2026-10-01.** The plan's filing date was Wed 2026-09-30, so every request is **one day late**. File today. The e-mail to weathernext@google.com is due **Fri 2026-10-02** (GOV-M1).
- **Never paste a key, token or password** into this file, a ticket, a chat or a commit. Keys go straight into Commons Secret Manager (§4.6–§4.9). The commands below read secrets with `read -rs` or pipe them straight into Secret Manager, so nothing is echoed or saved in shell history.
- **Placeholders** follow [10 §0.2](../../docs/10-setup-and-deployment.md#02-placeholders): `<DOMAIN>`, `<ORG_ID>`, `<BA_OPERATOR>`, `<BA_SPONSOR>`. This pack adds `<COMMONS_LICENSEE>` (the legal entity that holds the Commons approvals: the sponsor or the operator's Commons entity, **to confirm**, [13 §3.2](../../docs/13-governance-legal-risk.md#32-weathernext-clause-by-clause-reading-and-controls)) and `<CONTACT_NAME>`, `<CONTACT_ROLE>`, `<CONTACT_EMAIL>`, `<CONTACT_PHONE>` for the person who files.
- **(to confirm)** marks a URL, field or value that the research briefs did not verify. **# verify flag** marks a command flag to check with `--help` before first use ([10 §0.1](../../docs/10-setup-and-deployment.md#01-how-to-read-the-commands)).

## 1. Status tracker (as of 2026-10-01)

| AR | Service | What it unlocks | Account to use | GCP project needed | Where to apply | Expected lead time | Status | Follow-up | Fallback while waiting |
|---|---|---|---|---|---|---|---|---|---|
| AR-01 | **WeatherNext 3 and 2** Data Request (Commons) | WN3 and WN2 BigQuery listings (linked datasets `weathernext_3`, `weathernext_2` in `US`), Earth Engine assets, GCS Zarr | `wn-commons@<DOMAIN>` (role account); later one platform QA account (name to confirm) | `ectwin-commons-prod`, `ectwin-commons-dev` (named in the form) | [WeatherNext Data Request form](https://docs.google.com/forms/d/e/1FAIpQLSeCf1JY8G78UDWzbm0ly9kJxfSjUIJT5WyMR_HiNqCm-IHIBg/viewform) (link from a third-party repository; **to confirm** on the official WeatherNext pages); accept the [terms of use](https://storage.googleapis.com/weathernext-public/terms-of-use.pdf) | ≈5–7 business days (search summary) | To submit | 2026-10-12; escalate 2026-10-21 | ECMWF IFS/AIFS open data (`gs://ecmwf-open-data`, EE `ECMWF/NRT_FORECAST/IFS/OPER`), labelled "modelo de respaldo" |
| AR-01 · GOV-M1 (A16) | **E-mail to weathernext@google.com** | Written answers on Non-Retrievable publication, the Contractor role, the WN2 real-time threshold, WN3 members and the listing id | Send from `wn-commons@<DOMAIN>`; cc FL, DPO, PT | None (names `ectwin-commons-prod`) | `weathernext@google.com` (§4.2) | Unknown; due to send **2026-10-02** | To submit | 2026-10-12; escalate 2026-10-21 | Conservative rules until answered: NRVA rules N-1…N-4, 48 h real-time threshold for WN2, per-parish quantities treated as retrievable ([06 §3.4](../../docs/06-forecast-model-stack.md#34-terms-real-time-vs-historic-retrievable-vs-non-retrievable)) |
| AR-02 | **WN2 on-demand runs** on Vertex / Gemini Enterprise Agent Platform (allowlist) and GPU quota | Custom-initial-condition WN2 runs for the Phase 3 scenario engine | `wn-commons@<DOMAIN>` | `ectwin-commons-prod` (project and region that will run scenarios, to confirm) | Enquiry to `weathernext@google.com` (§4.3); [access-vmg guide](https://developers.google.com/weathernext/guides/access-vmg) (search summary) | (unverified) | To submit | 2026-10-12; GPU quota request by 2026-10-15 | Commons scenario library without WN2 re-runs (Phase 3 item; can slip) |
| AR-03 | **Google Flood Forecasting API** waitlist | API key on `ectwin-commons-prod`: gauges, flood status, significant events, flash floods | Data-team role account that can enable APIs in `ectwin-commons-prod` (e.g. `data@<DOMAIN>`, name to confirm) | `ectwin-commons-prod`: **reply to the approval e-mail with this project ID** | [Waitlist form](http://sites.research.google/gr/floodforecasting/api-waitlist/) ([Access & Set-up](https://support.google.com/flood-hub/answer/16364306?hl=en)) | "Might take several months" | To submit | 2026-10-12; escalate 2026-10-21 | GloFAS 30-day (EWDS), GEOGloWS-INAMHI, GRRR baseline |
| AR-04 (a) | **Earth Engine** registration: **Commercial, Limited plan** | EE for Commons operational production (LP-07: operational government use is commercial) | A project Owner (FL or a member of `ectwin-admins@`) | `ectwin-commons-prod`, `ectwin-commons-dev` (`ectwin-platform-prod` optional) | `https://code.earthengine.google.com/register?project=<ID>` (§4.5) | Minutes | To submit | 2026-10-02 (check `registrationState`) | None needed (minutes); budget line C4 ([12 §5.2](../../docs/12-roadmap-team-budget.md#52-cloud-lines)) |
| AR-04 (b) | **Earth Engine Partner tier** application (noncommercial, 100,000 EECU-h/month) | Free EECU quota for research and verification; Commons only if Google confirms in writing | FL | Named in the application: `ectwin-commons-prod`; a separate research project if Partner covers research only (name to confirm) | [Noncommercial tiers](https://developers.google.com/earth-engine/guides/noncommercial_tiers), [noncommercial page](https://earthengine.google.com/noncommercial/); application form: find on these pages (to confirm) | "Several weeks" | To submit | 2026-10-12; escalate 2026-10-21 | Commercial – Limited (US$0.40/EECU-h) stays the working basis |
| AR-05 | **TypeSafe Jev** | Typed decisions with `jev-1.13.0` for national triage (S1–S6) and build jobs (B1–B5) | `miguel@wursta.com` (held); move to an institutional role account before hand-over (§2.2) | `ectwin-commons-prod` (Secret Manager `typesafe-api-key`) | [console.typesafe.ai](https://console.typesafe.ai/) (keys under `/settings/keys`); `sales@typesafe.ai` for ZDR and higher limits | Account: done. Key storage: minutes. ZDR enquiry: (unverified) | **Access held (miguel@wursta.com) — key to be stored** | 2026-10-02 (key stored and tested); ZDR enquiry 2026-10-12 | System One Adapter → Gemini, or open-weight Von (D17) |
| AR-06 | **Copernicus CDS and EWDS** account; licence accepted for each dataset | C3S seasonal (`seasonal-monthly-single-levels`, …) and GloFAS (`cems-glofas-forecast`, `cems-glofas-seasonal`, `cems-glofas-historical`, `cems-glofas-reforecast`) | Role mailbox held by DL (e.g. `data@<DOMAIN>`); whether CDS accepts role accounts is (unverified) | None to register; token stored in `ectwin-commons-prod` | Token: `https://cds.climate.copernicus.eu/profile`; licences on each dataset page (e.g. [seasonal-monthly-single-levels](https://cds.climate.copernicus.eu/datasets/seasonal-monthly-single-levels)); EWDS API `https://ewds.climate.copernicus.eu/api` | Same day | To submit | 2026-10-02 | None for C3S; NMME/CFSv2 cover part of the horizon |
| AR-07 | **Copernicus Marine** account | Sea-level anomaly (`zos`) NRT via the `copernicusmarine` toolbox | `data@<DOMAIN>` or similar role account | None to register; credentials stored in `ectwin-commons-prod` | Copernicus Marine registration (find on the portal; to confirm) | Same day (estimate) | To submit | 2026-10-02 | EE copy `COPERNICUS/MARINE/GLOBAL_ANALYSISFORECAST_PHY_DAILY` |
| AR-08 | **NASA Earthdata** login | LHASA v2 nowcast (GES DISC), IMERG and other NASA files outside Earth Engine | `data@<DOMAIN>` or similar role account | None to register; credentials stored in `ectwin-commons-prod` | Earthdata registration (find on the Earthdata site; to confirm) | Same day (estimate) | To submit | 2026-10-02 | EE `NASA/GPM_L3/IMERG_V07`; LHASA inputs later |

**How to use the table.** When you submit, change *Status* to `Submitted YYYY-MM-DD (account)`, and archive the receipt or a screenshot on the programme-board card (deliverable P0-01). Board cards use the states *no solicitado / enviado / aprobado / rechazado* ([10 §2.3](../../docs/10-setup-and-deployment.md#23-tracking)). The follow-up dates apply that rule to a 2026-10-01 filing: a follow-up e-mail after 7 business days without movement, and escalation through the sponsor or Google contacts after 14. Exit gate **G0 (2026-10-16)** needs AR-01–AR-08 filed, plus at least one WeatherNext approval or the IFS fallback running.

**Not in this pack** (other owners and dates; see [10 §2.1](../../docs/10-setup-and-deployment.md#21-checklist)): AR-09 OAuth verification (submit 2026-10-05), AR-10 credits, AR-11 quotas, AR-12 Maps key (tenant-side), AR-13 letters and *convenios*, AR-14 domain verification.

## 2. Prerequisites

### 2.1 Projects that must exist first

| Project | Created in | Needed by |
|---|---|---|
| `ectwin-commons-prod` | [10 §3.2](../../docs/10-setup-and-deployment.md#32-folders-projects-billing-and-liens), billed to `<BA_SPONSOR>` | AR-01 (named in the form; holds the linked datasets), AR-02, AR-03 (the project ID in the reply), AR-04 (EE registration), and Secret Manager for the AR-03, AR-05, AR-06, AR-07 and AR-08 credentials |
| `ectwin-commons-dev` | Same | AR-01 (named in the form), AR-04 (EE registration) |
| `ectwin-platform-prod` | Same, billed to `<BA_OPERATOR>` | The `ops-budget` topic that carries the Commons budget alerts ([10 §3.6](../../docs/10-setup-and-deployment.md#36-central-budgets)); optional EE registration; the platform QA account of AR-01; AR-09 later |

EE commercial registration needs a billing account on the project. Storing a key needs the Secret Manager API enabled (step 3 below) and the empty secret containers (step 4). Project ids are global. If one is taken, stop and escalate to PL, because every document uses these ids.

### 2.2 Accounts

Approvals are granted per Google account (WeatherNext) or per GCP project (Flood API, Earth Engine), so the plan files them from **institutional role accounts** that outlive staff changes ([10 §1.6](../../docs/10-setup-and-deployment.md#16-people-and-role-based-accounts), [04 §9](../../docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead)).

| Account | Kind | Files or holds | Custodians | State on 2026-10-01 |
|---|---|---|---|---|
| `wn-commons@<DOMAIN>` | Workspace or Cloud Identity user with MFA | AR-01, AR-02, the GOV-M1 e-mail, and the Commons Analytics Hub subscriptions ([10 §5.5](../../docs/10-setup-and-deployment.md#55-weathernext-linked-datasets-in-commons)) | FL and DL | Check PQ-06 (due 2026-09-29) |
| `data@<DOMAIN>` or similar (name **to confirm**) | Role mailbox | AR-06 (CDS/EWDS, role mailbox held by DL per [13 §3.5](../../docs/13-governance-legal-risk.md#35-copernicus-glofascems-and-c3s-and-ecmwf)), AR-07, AR-08; proposed here for AR-03 as well | DL | To create |
| `miguel@wursta.com` | Staff account | **AR-05 TypeSafe access (held)** | Account holder | Active |
| Institutional TypeSafe account (proposed `jev-commons@<DOMAIN>`, name **to confirm**) | Role account | AR-05 after migration | AI lead and one deputy | Not created |
| An org admin (member of `ectwin-admins@`) | Staff | Creates projects, grants IAM, registers EE | PL | — |

- **TypeSafe on a staff account.** `miguel@wursta.com` holds TypeSafe access today, so use it now to unblock the Commons pipelines (§4.6). Before hand-over, or earlier if that person may leave the programme, open the institutional account, move billing to the sponsor, issue new keys there and add them as new secret versions. [08 §5.6](../../docs/08-ai-decision-layer-jev.md#56-caching-idempotency-and-rate-limiting) also keeps **separate TypeSafe accounts** for Commons prod, Commons dev/test and each tenant, because limits are per account; a load test on the same account can throttle production.
- **If `<DOMAIN>` or `wn-commons@<DOMAIN>` does not exist yet**, create it first (PQ-04, PQ-06), because WeatherNext approval does not move between accounts. If the form must go out today and the role account is still missing, file from a staff account and file again from the role account once it exists; the second request needs another ≈5–7 business days ([04 §9](../../docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead) asks for ≥10 business days before any hand-over).

### 2.3 Do this first (ordered)

1. **Confirm the prerequisites** PQ-01–PQ-06 of [10 §1.7](../../docs/10-setup-and-deployment.md#17-prerequisite-checklist): organisation and `<ORG_ID>`, groups, `<BA_OPERATOR>` and `<BA_SPONSOR>` (or the bridge account), `<DOMAIN>`, and `wn-commons@<DOMAIN>` with MFA.
2. **Create the folders and projects** as an org admin. The block below is copied from [10 §3.2](../../docs/10-setup-and-deployment.md#32-folders-projects-billing-and-liens); if the two ever differ, 10 §3.2 wins.

   ```bash
   ORG_ID="<ORG_ID>"; BA_OPERATOR="<BA_OPERATOR>"; BA_SPONSOR="<BA_SPONSOR>"

   # Folders
   F_ROOT=$(gcloud resource-manager folders create --display-name=ectwin --organization=$ORG_ID --format='value(name)')   # verify flag (output may be an operation; if so, read the id with folders list)
   for f in ectwin-platform ectwin-commons ectwin-sandbox ectwin-sponsored; do
     gcloud resource-manager folders create --display-name=$f --folder=${F_ROOT#folders/}
   done
   F_PLATFORM=$(gcloud resource-manager folders list --folder=${F_ROOT#folders/} --filter='displayName=ectwin-platform' --format='value(name)')
   F_COMMONS=$(gcloud resource-manager folders list --folder=${F_ROOT#folders/} --filter='displayName=ectwin-commons' --format='value(name)')
   F_SANDBOX=$(gcloud resource-manager folders list --folder=${F_ROOT#folders/} --filter='displayName=ectwin-sandbox' --format='value(name)')

   # Projects: dev and prod on day 2 (M0.1), stg by 2026-10-16
   mkproj() { # PROJECT_ID FOLDER BILLING PLANE ENV
     gcloud projects describe "$1" >/dev/null 2>&1 || \
       gcloud projects create "$1" --folder="${2#folders/}" \
         --labels=app=ectwin,plane=$4,env=$5,cost-center=$4
     gcloud billing projects link "$1" --billing-account="$3"
   }
   for ENV in dev prod; do
     mkproj ectwin-platform-$ENV $F_PLATFORM $BA_OPERATOR platform $ENV
     mkproj ectwin-commons-$ENV  $F_COMMONS  $BA_SPONSOR  commons  $ENV
   done
   mkproj ectwin-tenant-sandbox-1 $F_SANDBOX $BA_OPERATOR tenant dev
   mkproj ectwin-tenant-sandbox-2 $F_SANDBOX $BA_OPERATOR tenant dev

   # Protect production projects against accidental deletion
   for P in ectwin-platform-prod ectwin-commons-prod; do
     gcloud resource-manager liens create --project=$P \
       --restrictions=resourcemanager.projects.delete \
       --reason="GDE-Nino production - remove only with PM and PL approval"   # verify flag
   done
   ```

3. **Enable the baseline APIs** (copied from [10 §3.4](../../docs/10-setup-and-deployment.md#34-baseline-apis)). This enables Secret Manager, Earth Engine and Analytics Hub in the Commons projects.

   ```bash
   BASE="serviceusage.googleapis.com cloudresourcemanager.googleapis.com iam.googleapis.com \
    iamcredentials.googleapis.com sts.googleapis.com logging.googleapis.com monitoring.googleapis.com \
    cloudbilling.googleapis.com billingbudgets.googleapis.com secretmanager.googleapis.com \
    storage.googleapis.com artifactregistry.googleapis.com run.googleapis.com pubsub.googleapis.com \
    cloudscheduler.googleapis.com cloudquotas.googleapis.com"
   PLATFORM_EXTRA="firestore.googleapis.com identitytoolkit.googleapis.com firebase.googleapis.com \
    firebasehosting.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com cloudkms.googleapis.com \
    cloudidentity.googleapis.com"
   COMMONS_EXTRA="bigquery.googleapis.com bigquerystorage.googleapis.com analyticshub.googleapis.com \
    bigquerydatatransfer.googleapis.com workflows.googleapis.com workflowexecutions.googleapis.com \
    batch.googleapis.com compute.googleapis.com \
    earthengine.googleapis.com aiplatform.googleapis.com dlp.googleapis.com storagetransfer.googleapis.com"
   for ENV in dev prod; do
     gcloud services enable $BASE $PLATFORM_EXTRA --project=ectwin-platform-$ENV
     gcloud services enable $BASE $COMMONS_EXTRA  --project=ectwin-commons-$ENV
   done
   # floodforecasting.googleapis.com is enabled in ectwin-commons-prod only after AR-03 approval (§5.8).
   ```

4. **Create the empty secret containers** in `ectwin-commons-prod`. This is the first loop of [10 §5.8](../../docs/10-setup-and-deployment.md#58-secrets-and-external-credentials); the per-request sections below add versions.

   ```bash
   P=ectwin-commons-prod
   for S in floodforecasting-api-key typesafe-api-key cds-api-token copernicusmarine-credentials earthdata-credentials; do
     gcloud secrets describe $S --project=$P >/dev/null 2>&1 || \
       gcloud secrets create $S --project=$P --replication-policy=automatic
   done
   ```

5. **Open one programme-board card per row** of §1 (state *no solicitado*).
6. **File the long-lead requests first:** AR-03 Flood API (months), AR-04 (b) Partner tier (weeks), then AR-01 WeatherNext (≈5–7 business days) with the GOV-M1 e-mail, then AR-02.
7. **Finish the same-day items:** AR-04 (a) EE registration, AR-06 CDS/EWDS, AR-07 Copernicus Marine, AR-08 Earthdata, and storing the AR-05 TypeSafe key.

## 3. Common answers (reuse in every form)

| Field | Answer |
|---|---|
| Organisation (legal entity) | `<COMMONS_LICENSEE>`, for the GDE-Niño national Commons. The operator runs the pipelines as its Contractor ([13 §3.2](../../docs/13-governance-legal-risk.md#32-weathernext-clause-by-clause-reading-and-controls)) |
| Project name | GDE-Niño — *Gemelo Digital Ecuador – El Niño* (Ecuador El Niño Digital Twin) |
| Country | Ecuador |
| Sector / user type | Public-interest disaster-risk decision support (government, humanitarian, research) |
| One-line description | Probabilistic, Spanish-language decision support for Ecuador's El Niño response; it always sits beneath the official alerts and never replaces them. |
| Short description (≈50 words) | GDE-Niño turns global forecasts and river-flow data into parish-level probabilities, risk levels (*nivel de riesgo*) and impact estimates for Ecuador. It serves national agencies, provincial and municipal governments (*GAD*s), emergency operations committees (*COE*s), universities and humanitarian partners. Products are always shown beneath official SNGR and INAMHI alerts. |
| Users | SNGR, INAMHI, *COE*s, *GAD*s (221 cantons), ministries, universities, NGOs. Private insurers, banks and exporters use their own GCP projects and file their own requests for raw data |
| Commercial or noncommercial | The Commons is sponsor-funded and free to its users; no data is resold. Earth Engine is the exception: operational government use counts as **commercial** there (LP-07), so `ectwin-commons-prod` registers as Commercial – Limited |
| Area of interest | Ecuador including Galápagos: **longitude −92.1 to −75.1, latitude −5.1 to 1.7** (mainland clip −81.1 to −75.1) |
| WKT (if a polygon is asked) | `POLYGON((-92.1 -5.1, -75.1 -5.1, -75.1 1.7, -92.1 1.7, -92.1 -5.1))` |
| Timeline | Phase 0 began 2026-09-29; MVP go-live 2026-11-27; peak impacts expected Nov 2026 – Mar 2027; hand-over to a national public host planned for late 2027 |
| GCP projects | `ectwin-commons-prod` (production), `ectwin-commons-dev` (development) |
| Regions | BigQuery `US`; GCS and Cloud Run `us-central1`; heavy reads `us-east1` |
| Website / repository | `https://app.<DOMAIN>` (planned from 2026-11-13) · `<REPO_URL>` (Apache-2.0, proposed) |
| Contact | `<CONTACT_NAME>`, `<CONTACT_ROLE>`, `<CONTACT_EMAIL>`, `<CONTACT_PHONE>`; programme mailbox `wn-commons@<DOMAIN>` |

## 4. Requests

### 4.1 AR-01 — WeatherNext 3 and 2 Data Request (Commons)

**Where.** [WeatherNext Data Request form](https://docs.google.com/forms/d/e/1FAIpQLSeCf1JY8G78UDWzbm0ly9kJxfSjUIJT5WyMR_HiNqCm-IHIBg/viewform). The link comes from a third-party repository and the EE catalogue entry, so confirm it on the official WeatherNext pages ([dissemination guide](https://developers.google.com/weathernext/guides/dissemination)) before you submit. Read and accept the [terms of use](https://storage.googleapis.com/weathernext-public/terms-of-use.pdf), last modified 2026-09-03. **Who:** FL, signed in as `wn-commons@<DOMAIN>`. Approval is per Google account.

Likely form fields (the brief could not read the live form; map these answers to whatever it shows):

| Field | Answer |
|---|---|
| Name, e-mail | `<CONTACT_NAME>`; the signed-in account `wn-commons@<DOMAIN>` |
| Organisation, country | `<COMMONS_LICENSEE>`, Ecuador |
| Products | WeatherNext 3 and WeatherNext 2 (not the deprecated Gen/Graph) |
| Access channels | BigQuery (Analytics Hub listings), Earth Engine, Cloud Storage (Zarr; WN3 full ensemble from Phase 2, 2027-01) |
| GCP project IDs | `ectwin-commons-prod`, `ectwin-commons-dev` |
| Intended use | National El Niño decision support for Ecuador; publication of **non-retrievable value-added products only** (parish exceedance probabilities, risk levels, impact indices) and CC BY 4.0 historic verification data. Raw real-time fields stay internal |
| Commercial / noncommercial | Public-interest, sponsor-funded, free to users; no resale. Private users who want raw fields file their own requests |
| Area of interest | Ecuador bbox, longitude −92.1 to −75.1, latitude −5.1 to 1.7 |
| Data volume | Ecuador only: ≈600 WN2 cells and ≈4,000 WN3 0.1° cells × 4 runs/day, with filters on `init_time` and `geography`, so we expect to stay within or near 1 TiB/month of BigQuery scans (estimate). One-off WN2 2022→2026 hindcast extract: ≤≈0.69 TB scanned (upper estimate), ≈30 GB stored. WN3 Zarr: Ecuador subsets only (a global run is ≈50 GB) |
| Start date | Immediately (Phase 1 forecast cycle from 2026-10-19; go-live 2026-11-27) |
| Contact | `<CONTACT_NAME>`, `<CONTACT_EMAIL>`, `<CONTACT_PHONE>` |

**Justification** (paste into the free-text field):

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest decision-support platform for Ecuador during the very strong El Niño now under way, with peak impacts expected from November 2026 to March 2027. We request WeatherNext 3 and WeatherNext 2 access for the two Google Cloud projects of the national Commons, ectwin-commons-prod and ectwin-commons-dev. The Commons computes national products once and shares them free of charge with signed-in users from national agencies, municipal governments, emergency operations committees, universities and humanitarian partners. We will query only the Ecuador domain (longitude −92.1 to −75.1, latitude −5.1 to 1.7, including Galápagos) four times a day. The ensembles become parish-level probabilities of exceeding national rainfall thresholds, four-class risk levels and impact indices. Only Non-Retrievable Value-Added products and CC BY 4.0 historic data will be published; raw real-time fields stay internal. Every product sits beneath the official SNGR and INAMHI alerts, carries the required WeatherNext citation, and is verified weekly against INAMHI stations and CHIRPS. The WeatherNext 2 archive will also let us measure skill during the 2023 El Niño.

**After submitting.** Archive the receipt (P0-01), set the status, and send the GOV-M1 e-mail (§4.2) the same day or by 2026-10-02. Until approval the forecast cycle runs on the IFS fallback in `-dev`; M1.1 does not wait.

**After approval** (commands from [10 §5.5](../../docs/10-setup-and-deployment.md#55-weathernext-linked-datasets-in-commons), copied; the WN3 listing id is **to confirm after approval**):

```bash
# Once, as an org admin: let the approved account create the linked datasets in Commons and name
# Commons as the quota project (x-goog-user-project). Role choice to confirm with a dev subscription.
for R in roles/bigquery.user roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding ectwin-commons-prod --member="user:wn-commons@<DOMAIN>" --role=$R --condition=None
done

# Run as wn-commons@<DOMAIN> (gcloud auth login wn-commons@<DOMAIN>)
P=ectwin-commons-prod; X=projects/gcp-public-data-weathernext/locations/us/dataExchanges/weathernext_19397e1bcb7
sub() { # LISTING_ID DEST_DATASET
  curl -sS -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "x-goog-user-project: $P" -H "Content-Type: application/json" \
    "https://analyticshub.googleapis.com/v1/$X/listings/$1:subscribe" \
    -d '{"destinationDataset":{"datasetReference":{"projectId":"'"$P"'","datasetId":"'"$2"'"},"location":"US"}}'
}   # request shape to confirm, as in 03 §5.2
sub weathernext_2_19a39fe59dd weathernext_2
sub <WN3_LISTING_ID>          weathernext_3
# The exchange project may appear as number 871883017250 in listing paths (WN2); use what the console shows.

# Grant the forecast identity read access on the linked datasets (dataset-level):
for DS in weathernext_2 weathernext_3; do
  bq show --format=prettyjson $P:$DS > /tmp/$DS.json
  jq '.access += [{"role":"READER","userByEmail":"ectwin-forecast@'"$P"'.iam.gserviceaccount.com"}]' /tmp/$DS.json > /tmp/$DS.new.json
  bq update --source /tmp/$DS.new.json $P:$DS
done
```

Then run the first check in [10 §5.5](../../docs/10-setup-and-deployment.md#55-weathernext-linked-datasets-in-commons): a dry run, then a query capped with `--maximum_bytes_billed`. Both keep the partition filter and the Ecuador geography filter. Then run `wn-schema-check` once. Record which inits and member columns the WN3 tables carry, because that answers item 3 of the GOV-M1 e-mail. For the platform QA account, repeat the form from that account and name `ectwin-platform-prod` (account name to confirm).

**Fallback.** ECMWF IFS/AIFS open data, labelled "modelo de respaldo" ([06](../../docs/06-forecast-model-stack.md)).

### 4.2 AR-01 · GOV-M1 — e-mail to weathernext@google.com

Send by **Fri 2026-10-02** from `wn-commons@<DOMAIN>` and record the ticket id under A16 ([13 §3.2](../../docs/13-governance-legal-risk.md#32-weathernext-clause-by-clause-reading-and-controls), [05 §6.1](../../docs/05-data-catalog.md#61-agreements-needed)). Questions 1, 2 and 4–7 follow the wording in 13 §3.2, with the service-account, percentile and SMS points of [06 §13](../../docs/06-forecast-model-stack.md#13-open-questions) and [02](../../docs/02-users-requirements-ux.md) added. Question 3 adds WN3 member availability and the listing id ([03 §14](../../docs/03-architecture.md#14-open-questions)), and question 8 the WN2 archive provenance (06 §13).

```text
To:      weathernext@google.com
Cc:      <FL_EMAIL>, <DPO_EMAIL>, <PT_EMAIL>
Subject: GDE-Niño (Ecuador) – confirmation of Value Added Service use under the WeatherNext Terms of Use (3 Sep 2026)

Dear WeatherNext team,

On <FORM_SUBMISSION_DATE> we submitted the WeatherNext Data Request form from wn-commons@<DOMAIN> for
the Google Cloud projects ectwin-commons-prod and ectwin-commons-dev. They host the national "Commons"
of GDE-Niño (Gemelo Digital Ecuador – El Niño), a public-interest decision-support platform for
Ecuador's response to the current El Niño. The licensee is <COMMONS_LICENSEE>; peak impacts are
expected from November 2026 to March 2027, and we go live on 27 November 2026. We would be grateful
for written answers to the following questions, so that we apply your Terms of Use correctly.

1. Publication to signed-in users. We will publish, to signed-in public users in Ecuador, parish-level
   probabilities of exceeding national meteorological thresholds (at most 3 thresholds per variable,
   rounded to 1%) and 4-class risk levels derived from WeatherNext 3 and WeatherNext 2. Please confirm
   that these are Non-Retrievable Value Added Services under Section 3. We do not plan to publish
   per-parish percentiles or ensemble quantiles; please tell us if you would treat those as retrievable.
2. Contractor. Our pipelines are run by an operator under contract with the approved licensee. Please
   confirm that the operator qualifies as a "Contractor" under Section 2(c)(iii), and that a service
   account of the licensee's project may query the linked datasets created by the approved account.
3. WeatherNext 3 members. Do the WeatherNext 3 BigQuery and Earth Engine tables contain the 64
   individual members, or only the mean and percentile statistics (with full members in Cloud Storage
   only)? Are the hourly interim runs published in BigQuery, and what is the WeatherNext 3 listing id?
4. Real-time threshold for WeatherNext 2. Please confirm whether the 1-hour real-time threshold also
   applies to WeatherNext 2 (older catalogue text referred to 48 hours). Until we hear from you we apply
   48 hours to WeatherNext 2.
5. Citation in short formats. Please confirm that a short citation with a link to the full Section 4(b)
   text is acceptable on 1080×1350 image cards shared on messaging apps, and in SMS messages.
6. Operational use. Are national public agencies (SNGR, INAMHI) permitted to use Value Added Services
   operationally, given that the data is "not intended… for real world use"? All our products are shown
   beneath official alerts and are labelled as decision support, not warnings.
7. Hand-over. The platform will be handed over to a national public host in late 2027. Can the approved
   access be transferred to that host, or should the host apply now in parallel? (The licence is
   non-transferable, Section 2.)
8. Archive provenance. Which model versions produced the WeatherNext 2 archive for 2022–2024, and when
   were those forecasts generated? We plan to verify skill during the 2023 El Niño and need to know
   whether those years are in-sample.

We have a separate enquiry about the WeatherNext 2 on-demand allowlist, which we will send in its own
message.

Thank you for making WeatherNext available.

Kind regards,
<SENDER_NAME>
<SENDER_ROLE>, <ORGANISATION>
GDE-Niño – Gemelo Digital Ecuador – El Niño
<SENDER_EMAIL> · <SENDER_PHONE>
```

**If there is no answer by 2026-10-12**, reply to the same thread. By 2026-10-21, escalate through the sponsor or any Google contact the programme has. Until answers arrive, keep the conservative rules in the §1 fallback column.

### 4.3 AR-02 — WN2 on-demand allowlist (Vertex / Gemini Enterprise Agent Platform)

**Where.** An enquiry to `weathernext@google.com`. The [access-vmg guide](https://developers.google.com/weathernext/guides/access-vmg) (search summary) describes the allowlist, and the [WN2 notebook](https://raw.githubusercontent.com/GoogleCloudPlatform/vertex-ai-samples/main/notebooks/community/weathernext/weathernext_2_dws.ipynb) shows the run. GPU quota starts at 0: request it by 2026-10-15 ([06 §3.3](../../docs/06-forecast-model-stack.md#33-access-steps), step 6). Service `Vertex AI API`, quota "Custom model training preemptible Nvidia H100 GPUs per region" (or the A100 80GB equivalent), at least 16 GPUs (64 for a full run submitted at once).

**Justification / e-mail body:**

```text
To:      weathernext@google.com
Subject: GDE-Niño (Ecuador) – WeatherNext 2 on-demand allowlist request for ectwin-commons-prod

Dear WeatherNext team,

GDE-Niño (Gemelo Digital Ecuador – El Niño) is a public-interest decision-support platform for Ecuador's
response to the very strong El Niño now under way, with peak impacts expected from November 2026 to
March 2027. We have requested WeatherNext data access for our national Commons projects from
wn-commons@<DOMAIN>, and we now ask for the Google Cloud project ectwin-commons-prod to be allowlisted
for WeatherNext 2 on-demand runs on Vertex AI / Gemini Enterprise Agent Platform.

We plan a scenario engine for Phase 3 (from May 2027): perturbed sea-surface-temperature and
custom-initial-condition runs over past and present El Niño events, with results reduced to Ecuador's
parishes (longitude −92.1 to −75.1, latitude −5.1 to 1.7). Runs would use Dynamic Workload Scheduler or
Spot capacity on H100 or A100 GPUs, one member per GPU, starting with a single seed of eight members.
Our project pays all compute and storage costs. We will request GPU quota separately and would welcome
guidance on region and capacity. We will publish only non-retrievable derived products.

Kind regards,
<SENDER_NAME>, <SENDER_ROLE>, <ORGANISATION> · <SENDER_EMAIL>
```

**After approval.** File the GPU quota request. Run a smoke test (1 seed × 8 members on `a3-highgpu-8g`) and check that the quota is ≥16 ([06 §3.3](../../docs/06-forecast-model-stack.md#33-access-steps)). **Fallback.** Scenario library without WN2 re-runs; this Phase 3 item can slip.

### 4.4 AR-03 — Google Flood Forecasting API waitlist

**Where.** [Waitlist form](http://sites.research.google/gr/floodforecasting/api-waitlist/). Access is per GCP project and handled by priority; a request "might take several months" ([Access & Set-up](https://support.google.com/flood-hub/answer/16364306?hl=en), search summary). The API is free, licensed CC BY 4.0 per the [FAQ](https://support.google.com/flood-hub/answer/16364606?hl=en) (search summary), and has a quota of 200 requests/min per project. **Who:** DL, from an account that can enable APIs in `ectwin-commons-prod`.

| Likely field | Answer |
|---|---|
| Name, e-mail, organisation, country | `<CONTACT_NAME>`, `<CONTACT_EMAIL>`, `<COMMONS_LICENSEE>`, Ecuador |
| Organisation type | Public-interest disaster-risk platform working with national government (SNGR, INAMHI) and humanitarian partners |
| Use case | Central snapshots of Ecuador gauges, flood status, significant events and flash floods, 4× per day; archived for verification; shown with "Google Flood Hub" attribution beneath official warnings |
| Countries / area | Ecuador (`regionCode` EC), plus the transboundary basins with Colombia (Mira/Mataje) and Peru (Puyango-Tumbes, Catamayo-Chira); bbox longitude −92.1 to −75.1, latitude −5.1 to 1.7 |
| Expected volume | Fewer than ≈60 requests per run, 4 runs/day (schedule `15 1,7,13,19 * * *` UTC), well within 200 requests/min |
| GCP project | `ectwin-commons-prod`. Give it in the form if asked, and in any case **reply to the approval e-mail with it** |
| Commercial use | Public-good use. Snapshots stay in the non-commercial listing until Google confirms the terms for commercial viewers ([13 §3.3](../../docs/13-governance-legal-risk.md#33-flood-forecasting-api)) |

**Justification:**

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest decision-support platform for Ecuador's response to the very strong El Niño now under way; peak impacts are expected from November 2026 to March 2027, and river floods and flash floods are among the main hazards. We request Flood Forecasting API access for one Google Cloud project, ectwin-commons-prod, which serves national government partners (SNGR and INAMHI), emergency operations committees, municipal governments and humanitarian users. A single scheduled job would take snapshots of gauges, flood status, significant events and flash-flood polygons for Ecuador and its transboundary basins four times a day. It would use fewer than about 60 requests per run, far below the 200-requests-per-minute quota. Snapshots would be archived for verification, combined with GloFAS and GEOGloWS, and shown with Google Flood Hub attribution beneath official warnings, never as alerts. Municipal governments would read the results through the platform instead of each applying for its own key. We will share what we learn about Ecuador coverage, including gauges that the API does not serve, with the Flood Forecasting team.

**Direct request through a Google contact.** If someone on the programme has a Google contact, send this in addition to (not instead of) the waitlist form, so the request is on record in both places:

```text
Subject: Flood Forecasting API access for Ecuador's El Niño response (GDE-Niño)

Hi <GOOGLE_CONTACT_FIRST_NAME>,

Thank you for offering to help. I'd like to request access to the Google
Flood Forecasting API for GDE-Niño (Gemelo Digital Ecuador – El Niño), a
decision-support platform for Ecuador's response to the very strong El Niño
now under way. Ecuador's El Niño committee (CN-ERFEN) declared the event
active on 28 August, peak impacts are expected from November 2026 to
March 2027, and we plan to go live on 27 November 2026, before the coastal
rainy season peaks.

How we would use the API
- One scheduled job in a single Google Cloud project would take snapshots of
  Ecuador's gauges, flood status, significant events and flash-flood
  forecasts four times a day, including the basins Ecuador shares with
  Colombia and Peru. That is fewer than about 60 requests per run, well
  within the 200 requests/minute quota.
- Because the API keeps no history, we would archive the snapshots and
  combine them with GloFAS and GEOGloWS to produce parish-level flood
  probabilities and exposure for emergency operations committees (COE),
  municipalities and ministries.
- The platform issues no alerts. Official warnings from Ecuador's national
  risk agency (SNGR) and hydromet service (INAMHI) are shown verbatim above
  our products, and Flood Hub data carries attribution (CC BY 4.0). We are
  proposing data-sharing agreements with both agencies.
- Municipal governments would read the results through the platform instead
  of each applying for its own key.

Project details
- Google Cloud project ID: ectwin-commons-prod
  (project number: <PROJECT_NUMBER>)
- Organisation: <ORGANISATION>, <COUNTRY>
- Technical contact: <CONTACT_NAME>, <CONTACT_EMAIL>
- Waitlist form submitted on <DATE> from <ACCOUNT>

It would also help to confirm:
1. Whether derived products (parish-level probabilities, not raw gauge
   data) may be shown to signed-in users that include private companies,
   such as insurers and exporters, or whether a non-commercial restriction
   applies.
2. Current coverage in Ecuador: how many quality-verified gauges there are,
   and whether inundation maps are issued for them.
3. Whether querying flood status with cutoffTime (back to 2025-08-01) is the
   recommended way to build a history, and whether the Google Runoff
   Reanalysis & Reforecast (GRRR) will be extended beyond 2023.
4. Whether INAMHI, the national hydromet service, could get its own access,
   so the national authority holds a key directly.
5. Whether a temporary quota increase is possible during flood peaks, if we
   need one.

I'd be glad to set up a short call. Thank you very much.

Best regards,
<SENDER_NAME>
<ROLE>, <ORGANISATION>
<EMAIL> · <PHONE>
```

**On approval.** First reply to the approval e-mail:

```text
Subject: Re: <APPROVAL SUBJECT>

Thank you for approving GDE-Niño (Ecuador) for the Flood Forecasting API.
Our Google Cloud project ID is: ectwin-commons-prod
Contact for this project: <CONTACT_NAME>, <CONTACT_EMAIL>.

Kind regards,
<SENDER_NAME>
```

Then enable the API, create a restricted key and store it (copied from [10 §5.8](../../docs/10-setup-and-deployment.md#58-secrets-and-external-credentials)):

```bash
P=ectwin-commons-prod
# Flood Forecasting API, only after AR-03 approval:
gcloud services enable floodforecasting.googleapis.com --project=$P
gcloud services api-keys create --project=$P --display-name="ectwin-floodhub-commons" \
  --api-target=service=floodforecasting.googleapis.com                     # verify flag
KEY_NAME=$(gcloud services api-keys list --project=$P --filter='displayName=ectwin-floodhub-commons' --format='value(name)')
gcloud services api-keys get-key-string "$KEY_NAME" --format='value(keyString)' | \
  gcloud secrets versions add floodforecasting-api-key --data-file=- --project=$P   # verify flag
```

- If the enable page is not accessible, the Google account may not have been added as a "Service Consumer" (search summary); reply to the same thread.
- First call: `gauges:searchGaugesByArea` with `{"regionCode": "EC", "includeNonQualityVerified": true, "includeGaugesWithoutHydroModel": true}` to measure real Ecuador coverage ([10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request)).
- Un-pause the `ingest-floodhub-status` job (`enabled_when: flood_api_approved`, [10 §5.10](../../docs/10-setup-and-deployment.md#510-cloud-run-jobs-scheduler-and-workflows)).
- Rotate the key every 90 days ([11 §11.3](../../docs/11-operations-runbook.md#113-secret-rotation)). Tenants never receive this key.

**Fallback.** GloFAS 30-day (EWDS, §4.7), GEOGloWS-INAMHI and the GRRR baseline.

### 4.5 AR-04 — Earth Engine: (a) commercial Limited registration, (b) Partner-tier application

The rule is LP-07 ([13 §3.4](../../docs/13-governance-legal-risk.md#34-earth-engine-commercial-vs-noncommercial-registration), [10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request)). Operational government use is commercial, so `ectwin-commons-prod` registers as **Commercial – Limited** (US$0.40/EECU-h, [pricing](https://cloud.google.com/earth-engine/pricing)). File the **Partner-tier** application the same day, and switch only if Google confirms **in writing** that Partner covers the use. The noncommercial tiers (Contributor, Partner) are for research and verification projects only.

**(a) Registration** (browser step as a project Owner). The URLs and the state check are copied from [10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request):

```bash
for P in ectwin-commons-prod ectwin-commons-dev; do
  echo "Register: https://code.earthengine.google.com/register?project=$P"
done
# After registering (browser step), confirm the state; the field is output-only:
curl -sS -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: ectwin-commons-prod" \
  "https://earthengine.googleapis.com/v1/projects/ectwin-commons-prod/config" | jq -r .registrationState
```

| Likely field | Answer |
|---|---|
| Project | `ectwin-commons-prod` (then `ectwin-commons-dev`; `ectwin-platform-prod` only if needed) |
| Use type | **Commercial** (paid) |
| Plan | **Limited** (usage fees only) |
| Organisation, country | `<COMMONS_LICENSEE>`, Ecuador |
| Description | The one-line description in §3 |

Expected state: `REGISTERED_COMMERCIALLY`. After registering, set the daily EECU cap (`earthengine.googleapis.com/daily_eecu_usage_time`, unit **to confirm**) in *IAM & Admin → Quotas* within the budget ([04 §5.7.3](../../docs/04-identity-tenancy-byo-gcp.md#573-earth-engine-daily-cap), [cost controls](https://developers.google.com/earth-engine/guides/cost_controls)). Whether `ectwin-commons-dev` should also be commercial is **to confirm (FL)**; this pack assumes it mirrors prod.

**(b) Partner-tier application** (100,000 EECU-h/month; "several weeks"; yearly re-verification). The application form is linked from the [noncommercial tiers](https://developers.google.com/earth-engine/guides/noncommercial_tiers) and [noncommercial](https://earthengine.google.com/noncommercial/) pages (form URL to confirm).

| Likely field | Answer |
|---|---|
| Organisation type | Government-backed public-interest programme working with INAMHI and Ecuadorian universities (eligibility **to confirm**) |
| Project | `ectwin-commons-prod`, named for Google's written determination; a separate research project if Partner covers research only (name to confirm, PL) |
| Work area | Climate adaptation: El Niño impacts, flood mapping, forecast verification |
| Expected usage | ≈25–100 EECU-h/month for analogs and climatology ([09](../../docs/09-cost-model.md)), plus Sentinel-1 flood mapping during events |
| Area of interest | Ecuador bbox (§3) |

**Justification:**

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest climate-adaptation programme for Ecuador's response to the very strong El Niño now under way, with peak impacts expected from November 2026 to March 2027. Its national Commons computes shared products once and provides them free of charge to national agencies, municipal governments, emergency operations committees, universities and humanitarian partners. Earth Engine supports parish-level reductions of precipitation and ocean datasets, Sentinel-1 flood mapping, exposure layers and forecast verification against INAMHI stations and CHIRPS; we expect roughly 25–100 EECU-hours a month outside flood events. Because the Commons supports operational government decisions, we have registered ectwin-commons-prod for commercial use on the Limited plan. We apply for the Partner tier and ask Google to confirm in writing whether it can cover any of this work, in particular the verification and research carried out with INAMHI and Ecuadorian universities. If the Partner tier covers research only, we will move those workloads to a separate research project and keep operational production on the commercial plan.

**Fallback.** Commercial – Limited is the working basis (budget line C4). Over-quota noncommercial projects drop to a slower "restricted mode", not a hard stop ([04 §5.7.4](../../docs/04-identity-tenancy-byo-gcp.md#574-earth-engine-registration-and-tier-choice)).

### 4.6 AR-05 — TypeSafe (done): next steps for the key held by miguel@wursta.com

**Status.** `miguel@wursta.com` already has TypeSafe access. What remains is a dedicated Commons key in Secret Manager, the version pin, spend controls and the ZDR enquiry. The rules come from [08 §6](../../docs/08-ai-decision-layer-jev.md#6-where-keys-live-and-who-pays) and [10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request).

1. **Create a dedicated key for the Commons pipelines** in [console.typesafe.ai](https://console.typesafe.ai/) (keys under `/settings/keys`). Name it `ectwin-commons-prod` if the console allows names (to confirm). Do not reuse any key made for personal tests; if one was shared anywhere, revoke it. Use a separate key for dev and tuning (B1–B4), ideally under a separate account (§2.2).
2. **Store it immediately** in `ectwin-commons-prod`. The container comes from §2.3 step 4. Paste the key at the silent prompt, then press Enter:

   ```bash
   P=ectwin-commons-prod
   # Add a version without echoing or storing the value in shell history:
   read -rs V && printf %s "$V" | gcloud secrets versions add typesafe-api-key --data-file=- --project=$P
   unset V
   gcloud secrets versions list typesafe-api-key --project=$P   # shows the version, never the value
   ```

   Optional check that the key works. The Jev brief documents the SDK's default base URL and the route `GET /v1/models`, which lists the aliases (route to confirm). The key goes through stdin, not the command line:

   ```bash
   TYPESAFE_BASE_URL=https://api.typesafe.ai   # SDK default base URL
   printf 'Authorization: Bearer %s\n' "$(gcloud secrets versions access latest --secret=typesafe-api-key --project=ectwin-commons-prod)" | \
     curl -sS -H @- "$TYPESAFE_BASE_URL/v1/models" | jq .   # verify flag (-H @-)
   ```

3. **Pin `jev-1.13.0`.** Jobs set `JEV_MODEL=jev-1.13.0` and read `TYPESAFE_API_KEY=typesafe-api-key:latest` ([08 §5.7](../../docs/08-ai-decision-layer-jev.md#57-deployment-snippets)). Never use `jev-latest` in production, and log `response.model`.
4. **Spend alerts.** Set a monthly spend limit or alert in the TypeSafe console if it offers one (**to confirm**; none is documented). The plan's peak for national TypeSafe use is ≈US$90.79/month before taxes ([08 §6](../../docs/08-ai-decision-layer-jev.md#6-where-keys-live-and-who-pays)). TypeSafe is not billed through GCP, so GCP budgets do not see it; add the invoice to the monthly cost review. There is no free tier, and sign-ups reopened without the US$5 credit.
5. **Data handling.** Only data classes C0–C2 go to TypeSafe. **No ECU 911 or SNGR narrative text (class C3) is sent until TypeSafe ZDR/enterprise terms and the DPA review are signed.** Until then S2 runs on the open-weight Von backend or the Gemini adapter ([08 §10.2](../../docs/08-ai-decision-layer-jev.md#102-data-classes-and-backend-matrix)). Run DLP pseudonymisation before any external call, and put no personal data in `state` (LP-09).
6. **Rotation and ownership.** Rotate every 90 days; the `decision_call` logs must show the new key id ([11 §11.3](../../docs/11-operations-runbook.md#113-secret-rotation)). Move the account, billing and keys to an institutional role account before hand-over (§2.2): create the new key there, add it as a new version of `typesafe-api-key`, redeploy, and revoke the old key after 24 h ([10 §9.3](../../docs/10-setup-and-deployment.md#93-rotation)).
7. **ZDR and limits enquiry** (still to send; this closes AR-05):

   ```text
   To:      sales@typesafe.ai
   Subject: GDE-Niño (Ecuador) – enterprise plan, zero data retention and rate limits

   Hello,

   We use Jev (jev-1.13.0) through the account <TYPESAFE_ACCOUNT_EMAIL> for GDE-Niño, a public-interest
   El Niño decision-support platform for Ecuador. We plan about 3.5 million requests and 2.2 billion
   input tokens a month at the national peak (December 2026 – April 2027). Some inputs are pseudonymised
   emergency narratives from national agencies, which we may send only under zero-data-retention terms.

   Could you tell us:
   1. the terms and price of the enterprise plan with zero data retention, and the Data Processing
      Addendum, including the retention period and sub-processors;
   2. whether rate limits above 1,200 requests/min per account are available during event surges;
   3. whether you offer spend limits or budget alerts per account or per key;
   4. whether invoices (rather than card payment) are possible for a public-sector sponsor.

   Kind regards,
   <SENDER_NAME>, <SENDER_ROLE>, <ORGANISATION> · <SENDER_EMAIL>
   ```

**Fallback.** System One Adapter → Gemini, or open-weight Von (D17); failover is built into `DecisionBackend` ([services/decision/decision_backend.py](../../services/decision/decision_backend.py)).

### 4.7 AR-06 — Copernicus CDS and EWDS

**Where.** Create the CDS account (role mailbox held by DL, [13 §3.5](../../docs/13-governance-legal-risk.md#35-copernicus-glofascems-and-c3s-and-ecmwf)) and copy the personal access token from `https://cds.climate.copernicus.eu/profile`. EWDS uses **the same account and token** with its API at `https://ewds.climate.copernicus.eu/api`. Accept the licence **once, on each dataset's web page**; an unaccepted licence makes requests fail (TS-24).

| Dataset | Store | Used for | Licence accepted |
|---|---|---|---|
| `seasonal-monthly-single-levels` ([page](https://cds.climate.copernicus.eu/datasets/seasonal-monthly-single-levels)) | CDS | C3S multi-system seasonal, monthly | ☐ |
| `seasonal-original-single-levels` | CDS | C3S seasonal, daily/6-hourly | ☐ |
| `seasonal-postprocessed-single-levels` | CDS | Bias-adjusted anomalies (catalogue entry) | ☐ |
| `cems-glofas-forecast` | EWDS | GloFAS 30-day, 51 members | ☐ |
| `cems-glofas-seasonal` | EWDS | GloFAS seasonal (SEAS5) | ☐ |
| `cems-glofas-seasonal-reforecast` | EWDS | Seasonal skill baseline (catalogue entry) | ☐ |
| `cems-glofas-historical` | EWDS | ERA5-forced reanalysis | ☐ |
| `cems-glofas-reforecast` | EWDS | Reforecasts (`product_type=ensemble_perturbed_reforecast`) | ☐ |

Only the first page URL is in the briefs. Open the others by searching the dataset id in the CDS or EWDS catalogue (find in the portal; to confirm).

| Likely registration field | Answer |
|---|---|
| Name, e-mail | Role mailbox (`data@<DOMAIN>` or similar); `<CONTACT_NAME>` as the responsible person |
| Organisation, country, sector | `<COMMONS_LICENSEE>`, Ecuador, public sector / disaster-risk reduction |
| Purpose | The justification below |

**Justification (purpose of use):**

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest decision-support platform for Ecuador's response to the very strong El Niño now under way, with peak impacts expected from November 2026 to March 2027. We will use C3S multi-system seasonal forecasts to produce canton-level rainfall and temperature outlooks one to six months ahead. We will also use GloFAS 30-day, seasonal, reanalysis and reforecast river-discharge data to estimate flood likelihood on Ecuadorian rivers and to verify our products. Requests cover only the Ecuador domain (longitude −92.1 to −75.1, latitude −5.1 to 1.7) and run from scheduled Google Cloud jobs that submit asynchronously and poll, to keep the load on the Data Stores low. The derived products are shared free of charge with national agencies, municipal governments, emergency operations committees, universities and humanitarian partners, with Copernicus attribution. They are shown beneath official SNGR and INAMHI warnings and labelled "GloFAS (Copernicus) – referencial, no es advertencia oficial".

**Store the token** (jobs read `cds-api-token`; a local `~/.cdsapirc` is for tests only):

```bash
P=ectwin-commons-prod
read -rs V && printf %s "$V" | gcloud secrets versions add cds-api-token --data-file=- --project=$P
unset V
```

For local tests only, `~/.cdsapirc` holds `url: https://cds.climate.copernicus.eu/api` and `key: <PERSONAL-ACCESS-TOKEN>`. For EWDS use `cdsapi.Client(url="https://ewds.climate.copernicus.eu/api")` (cdsapi 0.7.7, [10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request)).

**Fallback.** There is no alternative for C3S; NMME and CFSv2 cover part of the horizon.

### 4.8 AR-07 — Copernicus Marine

**Where.** Copernicus Marine registration page (URL not in the briefs: find on the portal; to confirm). The account is reported as free **(unverified)**. Register with the role mailbox (`data@<DOMAIN>` or similar). The target product is `SEALEVEL_GLO_PHY_L4_NRT_008_046`, dataset `cmems_obs-sl_glo_phy-ssh_nrt_allsat-l4-duacs-0.125deg_P1D`, read with the `copernicusmarine` toolbox 2.5.0 ([05](../../docs/05-data-catalog.md)).

| Likely field | Answer |
|---|---|
| Name, e-mail | Role mailbox; `<CONTACT_NAME>` |
| Organisation, country, sector | `<COMMONS_LICENSEE>`, Ecuador, public sector / disaster-risk reduction |
| Area of interest | Eastern tropical Pacific and the Ecuadorian coast (Ecuador bbox in §3) |
| Intended use | The justification below |

**Justification:**

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest decision-support platform for Ecuador's response to the very strong El Niño now under way, with peak impacts expected from November 2026 to March 2027. We will use the Copernicus Marine near-real-time L4 sea-level product to track equatorial Kelvin waves and sea-level anomalies along the Ecuadorian coast. These signals give coastal municipalities, the national risk agency and fisheries and aquaculture users early warning of warm-water arrival, higher coastal sea levels and coastal flooding risk. We will download daily subsets for the eastern tropical Pacific and Ecuador only, using the copernicusmarine toolbox from a scheduled Google Cloud job, and store derived coastal series for verification. Derived indicators will be shared free of charge through the platform with "E.U. Copernicus Marine Service Information" attribution, beneath official warnings from INOCAR, INAMHI and SNGR, and labelled as decision support rather than alerts.

**Store the credentials** as JSON in `copernicusmarine-credentials` (field names **to confirm** with the ingest code; values never on the command line):

```bash
P=ectwin-commons-prod
read -r CM_USER && read -rs CM_PASS && \
  CM_USER="$CM_USER" CM_PASS="$CM_PASS" jq -cn '{username: env.CM_USER, password: env.CM_PASS}' | \
  gcloud secrets versions add copernicusmarine-credentials --data-file=- --project=$P
unset CM_USER CM_PASS
```

Test with `copernicusmarine login` **# verify flag** and a one-day subset of the dataset above ([10 §2.2](../../docs/10-setup-and-deployment.md#22-how-to-file-each-request)). **Fallback.** The EE copy `COPERNICUS/MARINE/GLOBAL_ANALYSISFORECAST_PHY_DAILY`; EE keeps only a rolling two-year window, so archive the derived series daily.

### 4.9 AR-08 — NASA Earthdata

**Where.** Earthdata registration page (URL not in the briefs: find on the Earthdata site; to confirm). Register with the role mailbox. The login serves the LHASA v2 nowcast from GES DISC (`Global_Landslide_Nowcast` v2.0.0), the inputs for re-running LHASA 2.1.1 centrally, and IMERG files outside Earth Engine ([05](../../docs/05-data-catalog.md)). GES DISC data may also need the application to be authorised in the Earthdata profile (to confirm).

| Likely field | Answer |
|---|---|
| Username, e-mail | Role mailbox (`data@<DOMAIN>` or similar) |
| Affiliation, country | `<COMMONS_LICENSEE>`, Ecuador |
| User type / study area | Government / public-interest; natural hazards (landslides, precipitation); Ecuador |
| Intended use | The justification below |

**Justification:**

> GDE-Niño (*Gemelo Digital Ecuador – El Niño*) is a public-interest decision-support platform for Ecuador's response to the very strong El Niño now under way, with peak impacts expected from November 2026 to March 2027. Heavy rainfall on Ecuador's Andean slopes and coast triggers landslides that cut roads and threaten communities. We will use NASA's LHASA landslide nowcast and its inputs, together with GPM IMERG precipitation, to estimate daily landslide hazard for Ecuador's parishes and to verify rainfall forecasts. Downloads cover only the Ecuador domain (longitude −92.1 to −75.1, latitude −5.1 to 1.7). They are made by a scheduled Google Cloud job, and the daily subsets are stored for verification. Derived hazard levels are shared free of charge with national agencies, municipal governments, emergency operations committees, universities and humanitarian partners, with NASA attribution. They are shown beneath official SNGR and INAMHI warnings and labelled as decision support.

**Store the credentials** in `earthdata-credentials` (same pattern; field names **to confirm**):

```bash
P=ectwin-commons-prod
read -r ED_USER && read -rs ED_PASS && \
  ED_USER="$ED_USER" ED_PASS="$ED_PASS" jq -cn '{username: env.ED_USER, password: env.ED_PASS}' | \
  gcloud secrets versions add earthdata-credentials --data-file=- --project=$P
unset ED_USER ED_PASS
```

**Fallback.** EE `NASA/GPM_L3/IMERG_V07`; LHASA inputs later.

## 5. After filing

- **Evidence.** Archive a receipt or screenshot for each row (P0-01), and record the GOV-M1 ticket id under A16.
- **Trackers.** Update §1 of this file and, when a status changes, the AR rows in [10 §2.1](../../docs/10-setup-and-deployment.md#21-checklist) and [12 §2.1](../../docs/12-roadmap-team-budget.md#21-phase-0--mobilise-2026-09-29--2026-10-16).
- **Contacts register.** Add `weathernext@google.com`, Flood Hub support and `sales@typesafe.ai`, with the account that filed each request ([10 §1.6](../../docs/10-setup-and-deployment.md#16-people-and-role-based-accounts)).
- **Calendar.** Follow-ups on 2026-10-12, escalations on 2026-10-21, gate G0 on 2026-10-16, the yearly EE noncommercial re-verification, and TypeSafe key rotation every 90 days.
