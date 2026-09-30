# Pilot brief: GAD Municipal de Otavalo

**Status (2026-09-30):** nominated as a pilot; no letter of intent yet. **Proposed tier:** T4 Sponsored with a T1 profile, or T1 on its own organisation-owned project if the GAD can buy GCP in time ([README](./README.md#why-these-tiers)). **Owner:** PT.

This brief uses only facts from the plan documents (01–14) and the research briefs. Everything specific to Otavalo that the plan does not contain is marked **(to confirm)**. GDE-Niño is decision support and issues no alerts. Only SNGR declares alerts, and INAMHI issues its own *advertencias* ([13 §1](../../docs/13-governance-legal-risk.md#1-alert-authority-and-product-positioning)).

## 1. Profile

| Item | Value | Source or status |
|---|---|---|
| Institution | *Gobierno Autónomo Descentralizado* (GAD) Municipal del cantón Otavalo ("Municipio de Otavalo") | Legal name and legal representative **(to confirm)** |
| Territory | Canton Otavalo, province of Imbabura (DPA `10`), Sierra region | Province code from [01 §6.2](../../docs/01-context-el-nino-ecuador.md#62-by-province); canton code `1004` **(to confirm with INEC CLASIFICADOR_GEOGRAFICO_2024)** |
| Plan priority | Imbabura is **P3** (national baseline only), with main pathway "limited direct signal". It is outside the MVP flood geography (CTX-08) | [01 §6.2](../../docs/01-context-el-nino-ecuador.md#62-by-province) |
| Tenant type | Organisational tenant, `org_type=gad`; `licence_profile=noncommercial` (NC layers visible); Earth Engine commercial if used operationally | [04 §3.2](../../docs/04-identity-tenancy-byo-gcp.md#32-organisational-vs-personal-tenants), [13 §4.1](../../docs/13-governance-legal-risk.md#41-tenant-licence-profile) |
| Nearest persona | **P04**, head of risk unit in a mid-size cantonal GAD: 1–3 staff covering many roles, no GIS specialist, no quick way to buy GCP, turnover after 29 Nov, power cuts | [02 §2.3](../../docs/02-users-requirements-ux.md#23-persona-cards). Otavalo's actual staffing **(to confirm)** |
| Expected users | The municipal risk unit (exact unit name **to confirm**), the cantonal COE and its *mesas técnicas*, and the municipal IT (TIC) unit as tenant administrator (P13). The water-supply operator may also use it **(to confirm)** | 02 §2.2 |
| Languages | Spanish; a Kichwa-speaking population whose share is **to confirm** (INEC Census 2022) | The plan gives Kichwa ≈527k speakers nationally (INEC 2010, secondary) ([08 §9.7](../../docs/08-ai-decision-layer-jev.md#97-kichwa)) |
| Connectivity | National: 57.7% of people have a smartphone, and the urban–rural gap in internet use is ≈28.4 points (low confidence). Canton figures **(to confirm)** | [02 §2.1](../../docs/02-users-requirements-ux.md#21-context-that-shapes-every-persona) |
| Domain and accounts | `otavalo.gob.ec` **(to confirm)**. Whether the GAD has Google Workspace or Cloud Identity, and therefore a GCP organisation, is **(to confirm)** | Decides between T4 and T1 (§5) |

## 2. Decisions and lead times

The rows come from the lead-time matrix in [01 §9.2](../../docs/01-context-el-nino-ecuador.md#92-lead-time-matrix). How Otavalo actually takes each decision is to be validated in the W2–W3 interviews ([02 §9.1](../../docs/02-users-requirements-ux.md#91-weekly-plan)).

| Row | Decision (owner in the plan) | Lead-time band | What the twin gives | First release |
|---|---|---|---|---|
| LT-11 | Priorities for dredging, channel cleaning and drainage maintenance (prefectures and municipalities) | L4, 1–3 months | Reach and drainage-hotspot ranking | MVP (coastal focus; Sierra coverage **to confirm**) |
| LT-16 | Shelter readiness, kit dispatch, volunteer rosters (cantonal COEs) | L3–L2, 2 weeks to 15 days | COE canton pack (PDF, WhatsApp card) | MVP |
| LT-19 | Local alert changes, COE activation, MTT sessions. **The decision is official (SNGR and COEs); the twin only supports it** | L2–L1, 15 days to 6 hours | Parish impact-probability ranking; MTT annex | MVP |
| LT-26 | Landslide and flash-flood response (ECU 911, municipalities) | L0, 0–6 hours | Nowcast layer plus official gauge data (display) | MVP (display), P2 |
| LT-24 | Intake and treatment adjustments (water utilities), **if the GAD or its utility runs water supply (to confirm)** | L2–L1 | Intake watch (to confirm with the utility) | P2 |
| LT-03 | Relocating or reinforcing polling sites for 29 Nov (CNE with Police and Armed Forces) | L4 → L2 | Polling-site exposure list by 30 Oct; daily rain-probability card 15–29 Nov | MVP |

Persona P04 frames the local decisions as "activate cantonal COE; clear drains; evacuate riverbanks", at a lead time of hours to 3 days ([02 §2.2](../../docs/02-users-requirements-ux.md#22-persona-summary)).

## 3. Hazards and modules

**The direction of the El Niño rainfall signal in Otavalo is not asserted here.**

- The plan rates Imbabura "limited direct signal" ([01 §6.2](../../docs/01-context-el-nino-ecuador.md#62-by-province)).
- For the Sierra as a whole, the plan puts the western slopes on the D4a spill-over pathway (heavy rain, landslides). It puts the inter-Andean valleys and eastern slopes on the D4b drying pathway. Both assignments are **unverified** ([01 §6.1](../../docs/01-context-el-nino-ecuador.md#61-by-region)).
- Otavalo's rural parishes may span more than one of these settings **(to confirm)**, so the northern-Sierra signal is treated as mixed.
- **Action (proposed):** FL and LI confirm the expected signal for Imbabura with INAMHI before G1a (2026-11-06), and add it as an item in the verification backlog ([01 §5.4](../../docs/01-context-el-nino-ecuador.md#54-conflicts-and-verification-backlog-phase-0-due-16-oct-2026)).

**Plausible local concerns.** All of these are **(to confirm with the GAD and INAMHI)**:

| Concern | Why it is plausible (plan source) | Module and product | Phase | Caveat |
|---|---|---|---|---|
| Rain-triggered landslides and debris flows, especially on access roads | Sierra hazards include landslides, debris flows and road cuts ([01 §6.1](../../docs/01-context-el-nino-ecuador.md#61-by-region)) | M4 LHASA daily parish hazard, `landslide_hazard_parish` (IMP-06) ([07 §4.4](../../docs/07-impact-modules-and-triggers.md#44-m4-landslides-movimientos-en-masa)) | P2; G1 by 2027-01-15 | LHASA thresholds are calibrated on Ecuadorian events; the Sierra event inventory is incomplete |
| Intense short-duration (convective) rain and flash flows in *quebradas* through built-up areas | Generic intense-rain risk; the plan has no Andean *quebrada* product | Parish exceedance of `tp_1h_max`, `tp_24h` and `tp_72h` (`parish_exceedance`, national). M2 as specified is coastal, built around tide-blocked drainage ([07 §4.2](../../docs/07-impact-modules-and-triggers.md#42-m2-pluvial-and-urban-drainage-guayaquil-first-inundación-pluvial-urbana)) | P1 (probabilities) | **Gap:** no *quebrada*-specific product; to raise with IM |
| Water supply stress and drought, and frost in inter-Andean valleys | Sierra: "possible drought and frost in the inter-Andean valleys (unverified)". Water supply: "no public dataset found" ([01 §7.1](../../docs/01-context-el-nino-ecuador.md#71-sector-summary)). M8 lists "Andean GADs" as users | M8 drought-lite: SPI, SPEI and VHI by canton or basin (IMP-14) ([07 §4.8](../../docs/07-impact-modules-and-triggers.md#48-m8-hydropower-and-drought-pautemazarsopladora-coca-codo-sinclair)) | P2 lite, 2026-12-15 | Utility data **(to confirm)** |
| Power cuts from the hydro-drought pathway | Mazar stood at 2,134.2 masl on 28 Sep; the 2024 cuts reached up to 14–15 h/day ([02 §2.1](../../docs/02-users-requirements-ux.md#21-context-that-shapes-every-persona)) | M8 reservoir watch card (IMP-13, national) | P1 | Affects GAD operations and connectivity rather than local hazard |
| Loss of road access to rural parishes | Road cuts; single-access parishes (M9) | M9 road-segment exposure (IMP-15); RA2CE isolation ([07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure)) | Static in P1 (six coastal provinces); dynamic in P2 by 2027-01-15 | Imbabura coverage **to confirm** with IM |

**What Otavalo sees at go-live (2026-11-27), whatever the scope decision:**

- the official-alert band;
- the ENSO panel;
- national parish exceedance probabilities;
- the daily PDF for its canton by 06:30 ECT and the WhatsApp card (FR-044);
- analog years (IMP-21) and the reservoir watch card;
- the T1-profile workspace (saved views, 1–3 daily AOIs, subscriptions, a branded PDF).

**Limits that apply.**

- **Confidence.** Sierra rain products carry ***confianza baja*** by default until held-out-station CRPSS reaches 0.10 ([14 §5.3](../../docs/14-verification-and-validation.md#53-confidence-labels)).
- **Triggers.** Sierra rain triggers stay at TU-0 ([14 §5.2](../../docs/14-verification-and-validation.md#52-indicator-acceptance-criteria-proposed-to-agree-with-inamhi-and-each-trigger-owner)).
- **Coastal-only products.** The Phase 1 exit criteria require the risk index v1 and exposure products only for the six coastal P1 provinces ([07 §8](../../docs/07-impact-modules-and-triggers.md#8-outputs-catalogue-and-phasing)). Whether Imbabura parishes show a *nivel de riesgo* and exposure counts at go-live is **(to confirm with IM and DL)**.

**Suggestion for the SC (not decided):** decide by G1a whether to add Imbabura to the `2026.11` exposure release, or whether Otavalo pilots the national-baseline view only.

## 4. Proposed AOIs

A T1 profile allows 1–3 AOIs with daily pipelines ([02 §3.2](../../docs/02-users-requirements-ux.md#32-what-each-tier-can-do)). All parishes still appear in the canton PDF and the parish table.

| AOI | Content | Purpose |
|---|---|---|
| AOI-1 *Cantón Otavalo* | The whole canton (DPA `1004`), with a parish table | Daily summary for the COE brief |
| AOI-2 *Otavalo urbano* | The urban parishes (listed below), plus *quebradas* and drainage points drawn by the risk unit **(to confirm)** | Intense-rain watch |
| AOI-3 *Vías de acceso rurales* | Priority access roads to rural parishes, drawn with the risk unit and MIT. For example, the road to Selva Alegre (location **to confirm**) | Landslide and access watch |

**Parishes of the canton.** Names and codes are all **(to confirm with INEC CLASIFICADOR_GEOGRAFICO_2024)**. The plan's gazetteer uses 6-digit `dpa_parish` codes, and whether `parish_type` is available is itself unverified ([05 §3.2](../../docs/05-data-catalog.md#32-dpa-dimension-and-name-matching)).

| `dpa_parish` (to confirm) | Parish | Type (to confirm) |
|---|---|---|
| 100401 | Jordán | Urban |
| 100402 | San Luis | Urban |
| 100450 | Otavalo (cantonal seat code) | Seat |
| 100451 | Dr. Miguel Egas Cabezas | Rural |
| 100452 | Eugenio Espejo | Rural |
| 100453 | González Suárez | Rural |
| 100454 | Pataquí | Rural |
| 100455 | San José de Quichinche | Rural |
| 100456 | San Juan de Ilumán | Rural |
| 100457 | San Pablo | Rural |
| 100458 | San Rafael | Rural |
| 100459 | Selva Alegre | Rural |

## 5. GCP project set-up

| Item | Proposal | Source |
|---|---|---|
| Tier and route | **T4 Sponsored with a T1 profile, route R-B.** A project in the sponsor's `ectwin-sponsored` folder, which may sit in the sponsor's own organisation, on the sponsor's T4 billing account | [10 §3.1](../../docs/10-setup-and-deployment.md#31-target-hierarchy), [09 §7.2](../../docs/09-cost-model.md#72-procurement-routes) |
| Why not T1 at once | A T1 tenant needs an **organisation-owned** project with billing. If the GAD has no Cloud Identity or Workspace organisation **(to confirm)**, T4 is its only organisation-owned option this season. Procurement through a reseller (R-A) takes weeks to months | [04 §3.2](../../docs/04-identity-tenancy-byo-gcp.md#32-organisational-vs-personal-tenants), [13 §7.1](../../docs/13-governance-legal-risk.md#71-how-public-tenants-can-pay-for-their-gcp-project) |
| Project id | `gad-otavalo-ectwin-prod`, following the `<org>-ectwin-prod` pattern. Ids are global and permanent, so add a suffix if it is taken | Suggestion |
| Labels | `ectwin-tenant=true`, `ectwin-sponsor=<SPONSOR_CODE>`, `ectwin-dpa=1004` (code **to confirm**) | FR-010 |
| Owners | **At least 2 institutional Owners with TOTP**, using GAD accounts rather than personal Gmail. Suggested: the head of the risk unit and an IT (TIC) officer, with at least one career official whose post does not change with the election **(suggestion)**. WeatherNext is not needed for T1, but if it is added later, use a role-based account such as `gde-datos@otavalo.gob.ec` (domain **to confirm**) | [04 §3.2](../../docs/04-identity-tenancy-byo-gcp.md#32-organisational-vs-personal-tenants), [04 §9](../../docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead) |
| Billing | Sponsor T4 billing account `<SPONSOR_T4_BILLING_ACCOUNT>`. The sponsor is not yet named: ask 3 is due 2026-10-09. The sponsor also sees the project's cost view | [00 §9](../../docs/00-executive-summary.md#9-decisions-and-asks-for-leadership-this-week) |
| Budget and guardrails (T4 column, T1 profile) | Monthly budget US$20 (set by the sponsor; T4 default). `QueryUsagePerDay` 1 TiB. `QueryUsagePerUserPerDay` 200 GiB. `maximumBytesBilled` 50 GiB. Per-run cap 20 GiB. Earth Engine 1 EECU-h/day. Cloud Run parallelism 2. Confirmation above US$1 | [04 §8.2](../../docs/04-identity-tenancy-byo-gcp.md#82-defaults-per-tier-estimates-tune-in-pilot) |
| Expected cost | T1 anchor ≈US$0–14/month. A typical GAD is ≈US$2.20 with commercial Earth Engine and no Google tiles, before 15% IVA. The sponsor pays; budget line C7 funds 5 T4 projects at US$14 in Phase 1 | [09 §4.4](../../docs/09-cost-model.md#44-tenant-t1-light-municipality-20-users-dashboards-plus-one-aoi-job), [12 §5.2](../../docs/12-roadmap-team-budget.md#52-cloud-lines) |
| Licence, Earth Engine and WeatherNext | `noncommercial` profile: subscribe to `ectwin_commons` and `ectwin_commons_nc`. Earth Engine is optional for T1; if used, register commercially for operational use (TP-06). No WeatherNext request needed (TP-07) | [10 §6.1](../../docs/10-setup-and-deployment.md#61-before-you-start-tenant-administrator) |
| Connection path | Path A in Cloud Shell with the Spanish tutorial [TUTORIAL.es.md](../../infra/tenant-bootstrap/TUTORIAL.es.md) | [10 §6.4](../../docs/10-setup-and-deployment.md#64-run-the-bootstrap) |
| Alternative (T1, own project) | `gcloud projects create gad-otavalo-ectwin-prod --organization=<TENANT_ORG_ID>`, with the GAD's own billing account. The same T1 budget (US$20) and guardrails apply. A T4 project can later move to this route ([04 §10.1](../../docs/04-identity-tenancy-byo-gcp.md#101-scenarios), T4 graduation) | [10 §6.2](../../docs/10-setup-and-deployment.md#62-create-the-project-if-needed) |

```bash
# 1. Sponsor admin, in the ectwin-sponsored folder (10 §6.2). The DPA code in the label is to confirm.
SFOLDER="<SPONSORED_FOLDER_ID>"; SCODE="<SPONSOR_CODE>"; SBA="<SPONSOR_T4_BILLING_ACCOUNT>"; ADMIN="<GAD_ADMIN_EMAIL>"
gcloud projects create gad-otavalo-ectwin-prod --folder=$SFOLDER \
  --labels=ectwin-tenant=true,ectwin-sponsor=$SCODE,ectwin-dpa=1004
gcloud billing projects link gad-otavalo-ectwin-prod --billing-account=$SBA
gcloud projects add-iam-policy-binding gad-otavalo-ectwin-prod --member=user:$ADMIN --role=roles/owner

# 2. GAD administrator in Cloud Shell, with the connection code from the web app (04 §4.2)
scripts/bootstrap-tenant.sh --project gad-otavalo-ectwin-prod --dry-run
scripts/bootstrap-tenant.sh --project gad-otavalo-ectwin-prod --tier T4 --budget-usd 20 --connection-code c-<CODE>
scripts/verify-tenant.sh --project gad-otavalo-ectwin-prod
```

## 6. Onboarding steps and dates

The steps follow the plan's Phase 0–1 calendar ([12 §2.1–2.2](../../docs/12-roadmap-team-budget.md#2-phase-plans)) and the adoption playbook ([12 §7.3](../../docs/12-roadmap-team-budget.md#73-adoption-playbook-for-a-new-tenant)). Dates marked "proposed" are this brief's suggestion.

| # | Step | Date | Who | Done when |
|---|---|---|---|---|
| 1 | Kick-off call (D0): confirm T4 or T1, focal point, 2 Owners, IT contact, signatory | By 2026-10-09 (proposed) | PT, GAD | Route chosen |
| 2 | Include an Otavalo risk-unit officer in the W2–W3 interviews (P04, Sierra) and, if possible, the round-2 usability sessions (26–30 Oct) | 5–16 Oct; 26–30 Oct | UX | Interview notes |
| 3 | **Letter of intent signed** (draft in §10) | **By 2026-10-16** | Mayor or legal representative; PT | Counts toward P0-06 and G0 (f) |
| 4 | Sponsor named, T4 folder and billing account ready (ask 3) | 2026-10-09 | PM, sponsor | Folder id and billing account known |
| 5 | T4 project requested and created (FR-010: ≤2 business days) | By 2026-10-23 (proposed) | Sponsor admin | Project with labels |
| 6 | **Onboarding clinic**: live session in which the GAD administrator runs the bootstrap with PL and FAC support (path A, [TUTORIAL.es.md](../../infra/tenant-bootstrap/TUTORIAL.es.md)), then `verify-tenant.sh` and *Conectar*. This is the W2 "first pilot bootstrap (sponsored T4)" | 26–30 Oct | GAD TA, PL, FAC | Preflight green |
| 7 | Invite the second Owner; record the tenant register (project id, billing, budget, Owners) | Same week | GAD | TA-04; [10 §6.13](../../docs/10-setup-and-deployment.md#613-invite-the-team-and-document-ownership) |
| 8 | Interim terms of use and privacy notice accepted (B1a) | By 2026-11-06 (G1a) | GAD Owner, DPO | Acceptance record |
| 9 | Subscribe to the Commons listing (M1.2); create the three AOIs; first run | From 2026-11-06 | GAD TA | TA-03 |
| 10 | Training wave 1 (remote): C2 for administrators, C1 for users | 9–13 Nov | TR, FAC | F1 |
| 11 | IT-M8 (3 pilot tenants green); processor contract (*Adenda LOPDP*) signed (B1b) | 2026-11-13 | PL, DPO | TA-01 to TA-05 |
| 12 | Training wave 2 is in person in Guayaquil and Portoviejo only, so hold a remote C3/C4 session or an added Sierra session **(to decide)** | 16–20 Nov | TR | Attendance |
| 13 | Pre-election Owner check: support outreach to GAD tenants ([11 §9.4](../../docs/11-operations-runbook.md#94-onboarding-turnover-and-offboarding)) | 2–20 Nov | Support, GAD | ≥2 Owners with TOTP |
| 14 | G1b go/no-go; go-live; freeze 26 Nov – 1 Dec; **local elections 29 Nov** | 24 / 27 Nov | SC | — |
| 15 | D30 health check: usage, cost against the anchor, open issues | ≈30 days after connection (late Nov) | PT, GAD TA | Checklist reviewed |
| 16 | Re-onboarding of the new authorities: ownership transfer (FR-016), C1 for new staff | Within 30 days of taking office (date **unverified**, V12) | TR | Owners ≥2; new staff trained |

## 7. Data exchange

| Direction | What | Mechanism and condition |
|---|---|---|
| Platform → Otavalo | Official alerts verbatim; the Commons listing `ectwin_commons` and `ectwin_commons_nc`; canton PDF and WhatsApp card; notifications | Linked datasets in the tenant; the tenant pays its own queries, which fall inside free tiers at T1 |
| Otavalo → its own project | Local layers (*quebradas*, risk zones, shelters, water intakes, if they exist, **to confirm**), AOIs, reports | These stay in the GAD's tenant project. The operator has no access to tenant content (FR-064) |
| Otavalo → Commons (optional) | Local layers or impact reports for national products and verification | Needs a letter of agreement like **A13**, which today covers Guayaquil/Segura EP, Manabí, Manta and Portoviejo ([05 §6.1](../../docs/05-data-catalog.md#61-agreements-needed)). **Suggest adding Otavalo to A13 (to confirm)** |
| Personal data | None needed for the pilot. Member accounts are covered by the processor contract (B1b). A future Kichwa audio or SMS channel needs DPIA-04 (2027-05-15) | [13](../../docs/13-governance-legal-risk.md) |

## 8. Success criteria

| # | Criterion | Target | By | Source |
|---|---|---|---|---|
| O1 | Letter of intent signed | Signed | 2026-10-16 | P0-06 |
| O2 | T4 project from request to approval | ≤2 business days | Late Oct | FR-010 |
| O3 | Tenant acceptance: `verify-tenant.sh --strict` exits 0; preflight green (PF-12 and PF-13 may be amber for T1); first AOI run succeeded; 2 Owners with TOTP | All green | 2026-11-13 (IT-M8) | [10 §6.14](../../docs/10-setup-and-deployment.md#614-tenant-acceptance) |
| O4 | Onboarding time and autonomy | ≤45 min median in the field; finished without live support | 2026-11-27 | [02 §10](../../docs/02-users-requirements-ux.md#10-success-metrics) |
| O5 | Pilot pipeline success | ≥98% over 7 days | Before G1b | ST-30, M1.4 |
| O6 | Cost | Within the T1 anchor (≤US$14/month); budget US$20 not exceeded | 7 days before G1b; monthly | [12 §9](../../docs/12-roadmap-team-budget.md#9-pilot-gono-go-checklist) G1 |
| O7 | Pilot users completed C1 and administrators C2 before any write role | 100% | 13 Nov | F1 |
| O8 | Users who correctly tell the official alert from the platform level | ≥95% | G1a / G1b | A3, K7 |
| O9 | Platform output mistaken for an official alert | 0 | Ongoing | K8 |
| O10 | Otavalo canton PDF available by 06:30 ECT | 5 of 5 test days (Phase 1); ≥97% of days (Phase 2) | Phase 1–2 | K9, NFR-007 |
| O11 | Adoption | ≥3 users active by D7; champion (*referente*) named by D14; brief prepared with the twin for 5 days | D7–D14 | [12 §7.3](../../docs/12-roadmap-team-budget.md#73-adoption-playbook-for-a-new-tenant) |
| O12 | Morning brief preparation time (self-reported) | ≤15 min | 2026-11-27 | 02 §10 |
| O13 | Workspace survives the change of authorities | Hand-over without data loss (FR-016 test); Owners ≥2; new staff trained within 30 days | 30 days after taking office | 12 §7.3 |
| O14 | Users read *confianza baja* and probabilities correctly (T6-type items) | ≥80% | Phase 1 | 02 §10 |
| O15 | Kichwa needs documented: channels, topics, reviewing institution | Note delivered | 2027-03-31 (proposed) | FR-076 |

## 9. Risks and mitigations

| Risk | Plan link | Mitigation |
|---|---|---|
| **Change of authorities after the 29 Nov 2026 local elections**; take-office date unverified | CTX-12; R27 / PRG-10; [04 §3.7](../../docs/04-identity-tenancy-byo-gcp.md#37-ownership-recovery-and-hand-over) | Institutional, role-based accounts only; ≥2 Owners, including career staff; tenant register kept; support outreach 2–20 Nov; FR-016 hand-over; re-onboarding pack within 30 days; reclaim path if no Owner is left |
| **Procurement:** the GAD cannot buy GCP before the peak | R14 / PRG-09 | T4 sponsored project (R-B); procurement kit (P0-07); graduation to the GAD's own billing later |
| The sponsor, and so the T4 folder, is not yet in place | R15; ask 3 (2026-10-09) | Until the project exists, staff use T0 (read-only national view and canton PDF). Escalate at SC #2 (21 Oct) if the W2 bootstrap is at risk |
| No Cloud Identity or Workspace organisation at the GAD **(to confirm)** | [04 §3.2](../../docs/04-identity-tenancy-byo-gcp.md#32-organisational-vs-personal-tenants) | T4 in the sponsor folder; never a personal project |
| **Connectivity** and power cuts | [02 §2.1](../../docs/02-users-requirements-ux.md#21-context-that-shapes-every-persona); PRG-12 | PDF ≤500 KB, WhatsApp card, text-first PWA (≤200 KB first view), downloadable PDFs. Request a 4G router and power-bank kit from line O10 **(to decide)** |
| **Kichwa-speaking users:** no Kichwa product before Phase 3; mistranslation harms (R32); equity (R23) | FR-076; [08 §9.7](../../docs/08-ai-decision-layer-jev.md#97-kichwa); 13 L-17 | Spanish plain language with D1 and D3 read aloud. Any Kichwa item produced with a native reviewer and ETH sign-off. Jev never decides automatically on Kichwa text. Collect needs now for Phase 3 audio and SMS (line O8, full variant only) |
| Low forecast skill in the Sierra | [14 §5.3](../../docs/14-verification-and-validation.md#53-confidence-labels); R23 | *Confianza baja* by default; no Sierra rain triggers (TU-0); INAMHI *advertencias* shown verbatim above model output; regional verification published |
| Expectations outside the MVP geography | CTX-08; [07 §8](../../docs/07-impact-modules-and-triggers.md#8-outputs-catalogue-and-phasing) | Explain at kick-off what Phase 1 gives Imbabura; SC decision on adding Imbabura exposure (§3) |
| Wrong hazard framing (wet vs dry) | 01 §6.1–6.2 | Confirm with INAMHI (§3); show analogs with the D6 disclaimer; no directional claims in pilot material |

**Open items to confirm:** the legal name, signatory and domain; whether the GAD has Google Workspace or Cloud Identity; the DPA codes and parish list; the Kichwa-speaking share and preferred channels; the INAMHI view of the El Niño signal; the water-supply operator and intakes; the take-office date (V12); which roads serving Otavalo are state roads (with MIT); and the sponsor and its T4 billing account.

## 10. Borrador: carta de invitación e intención de participación

> *Borrador para revisión (PT y DPO). Reemplace los campos entre corchetes.*

[Ciudad], [fecha]

Señor/a [NOMBRE]
Alcalde/sa del Cantón Otavalo
Gobierno Autónomo Descentralizado Municipal de Otavalo

De nuestra consideración:

El programa *Gemelo Digital Ecuador – El Niño* (GDE-Niño) invita al GAD Municipal de Otavalo a participar como institución piloto durante la temporada 2026-2027.

GDE-Niño es una herramienta de **apoyo a la decisión**. Muestra probabilidades de lluvia, exposición y niveles de riesgo por parroquia, siempre debajo de las alertas oficiales. **GDE-Niño no emite alertas.** Las alertas oficiales las declara la Secretaría Nacional de Gestión de Riesgos (SNGR), con base en la información de INAMHI, INOCAR y el CN-ERFEN.

La participación incluye:

1. Un proyecto institucional de Google Cloud patrocinado (nivel T4, perfil T1), sin costo para el municipio durante la temporada, o un proyecto propio si el GAD ya puede contratarlo.
2. Al menos dos propietarios con cuentas institucionales y un/a referente de la Unidad de Gestión de Riesgos. Así el espacio de trabajo pertenece a la institución y se mantiene después de las elecciones del 29 de noviembre.
3. Capacitación virtual entre el 9 y el 13 de noviembre de 2026, y retroalimentación durante la temporada, incluidas las necesidades de información en kichwa.
4. La aceptación de los términos de uso, el aviso de privacidad y el contrato de encargo de tratamiento de datos.

El GAD recibirá el reporte cantonal diario, áreas de interés propias y acompañamiento técnico. Esta carta expresa una intención y no genera obligaciones financieras para el municipio. Agradeceremos su respuesta hasta el **16 de octubre de 2026**.

Atentamente,

[NOMBRE], [CARGO]
GDE-Niño – [institución responsable / patrocinador]

**Intención de participación.** El GAD Municipal de Otavalo manifiesta su intención de participar como institución piloto de GDE-Niño. Designa como propietarios del proyecto a [NOMBRE 1, cargo, correo institucional] y [NOMBRE 2, cargo, correo institucional], y como referente técnico/a a [NOMBRE, cargo].

[Firma] · [Nombre] · [Cargo] · [Fecha]
