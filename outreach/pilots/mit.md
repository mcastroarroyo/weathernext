# Pilot brief: MIT, Ministerio de Infraestructura y Transporte (ex-MTOP)

**Status (2026-09-30):** nominated as a pilot ("MIT.gob.ec"); no letter of intent yet. **Proposed tier:** T2 Standard, with the option to grow to T3 Heavy for tenant-side landslide and road modelling ([README](./README.md#why-these-tiers)). **Owner:** PT; data agreement A8 also with PT.

This brief uses only facts from the plan documents (01–14) and the research briefs. Anything else is marked **(to confirm)**. GDE-Niño is decision support and issues no alerts. Only SNGR declares alerts ([13 §1](../../docs/13-governance-legal-risk.md#1-alert-authority-and-product-positioning)).

## 1. Profile

| Item | Value | Source or status |
|---|---|---|
| Institution | Ministerio de Infraestructura y Transporte (MIT), formerly MTOP. The name is as given at nomination; the plan's item V10 also records a "…y Tecnología" variant, so the **legal name is to confirm** before the letter is signed | [01 §5.4](../../docs/01-context-el-nino-ecuador.md#54-conflicts-and-verification-backlog-phase-0-due-16-oct-2026) V10; CTX-13 |
| Domain | `mit.gob.ec`, the successor to `obraspublicas.gob.ec` (TLS mismatch). `geoportal.mtop.gob.ec` is dead | [05 §4.2](../../docs/05-data-catalog.md#42-source-registry-and-health-checks) |
| Role in the plan | "Road network; closures; machinery"; "Priority corridors; Bailey bridges"; exchanges: road inventory (to request), segment and bridge exposure; **T2 tenant** | [01 §8.2](../../docs/01-context-el-nino-ecuador.md#82-actors-roles-and-what-the-twin-exchanges-with-them) |
| 2026 response reported | 8 Bailey bridges; 73 machines (World Bank-financed, >US$15M); US$69M for roads; 5 priority corridors [S] | [01 §5.3](../../docs/01-context-el-nino-ecuador.md#53-response-and-financing-already-in-motion) |
| Exposure reported | 3,113 km of state roads highly exposed: 1,870 km to floods and 1,243 km to landslides. Flood-exposed: Manabí 740 km, Guayas 594 km, Los Ríos 222 km. 94 transport structures: Santa Elena 28, Guayas 23, Manabí 23 [S] | [01 §7.1](../../docs/01-context-el-nino-ecuador.md#71-sector-summary) |
| Tenant type | Organisational tenant, `org_type=ministerio`; `licence_profile=noncommercial`; Earth Engine commercial (operational use) | [13 §4.1](../../docs/13-governance-legal-risk.md#41-tenant-licence-profile) |
| Users | Sector analysts (training audience AUD-5: 5 trained by 2026-11-27, 60 by 2027-03-31, shared with MAG, MSP and CELEC/CENACE); a tenant IT administrator (P13); the directorates that plan machinery and corridors **(to confirm)**. The plan has no MIT persona card, so interviews in W3 fill that gap | [12 §7.1](../../docs/12-roadmap-team-budget.md#71-audiences-and-targets) |
| Open data | "No open road-network download was found at the successor `mit.gob.ec`"; road network and bridges come by agreement (A8) | [07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure) |
| Identity and cloud | Whether `mit.gob.ec` uses Google Workspace or Cloud Identity, whether MIT has a GCP organisation and billing account, and whether that organisation enforces domain-restricted sharing are all **(to confirm)** | Decides the connection path (§5) |

## 2. Decisions and lead times

| Row ([01 §9.2](../../docs/01-context-el-nino-ecuador.md#92-lead-time-matrix)) | Decision | Lead-time band | What the twin gives | First release |
|---|---|---|---|---|
| **LT-12** | Machinery and Bailey-bridge pre-positioning; 5 priority corridors (MIT, prefectures) | L4–L3: 1–3 months, then 2–6 weeks | Road-segment exposure layer; isolated-parish count | MVP static exposure by 2026-11-20; RA2CE isolation in P2 by 2027-01-15 ([07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure)) |
| **LT-27** | Road closures (MIT, ECU 911) | L1–L0: 6–72 hours, then 0–6 hours | Segment-level hazard plus a link to ECU 911 road status | P2 |
| LT-03 | Road access to the 368 at-risk polling sites for 29 Nov (the CNE owns the decision; MIT's role **to confirm**) | L4 → L2 | Polling-site exposure list (30 Oct); daily rain-probability card 15–29 Nov | MVP |

Seasonal decisions such as machinery contracts, the corridor budget and the use of the US$69M roads allocation map to the L5–L4 bands. How MIT actually takes them is **(to confirm in the W3 interviews)**.

## 3. Hazards and modules

| Module | Product (table) | What MIT gets | Phase and acceptance |
|---|---|---|---|
| **M9 Transport and critical infrastructure** ([07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure)) | IMP-15 *Vías y puentes en riesgo; parroquias aisladas* (`road_segment_risk`, `isolation_parish`); IMP-17 `facility_exposure` | Segment hazard as the maximum of the M1, M3 and M4 classes along the segment (plus Segura EP `Vías_Inundables` in Guayaquil). A bridge flag when its reach has P(Q ≥ RP10) ≥ 0.3 (placeholder). RA2CE isolation of parishes | **P1:** static exposure by 2026-11-20. The Phase 1 exit covers the six coastal P1 provinces ([07 §8](../../docs/07-impact-modules-and-triggers.md#8-outputs-catalogue-and-phasing)). **P2:** dynamic per-cycle risk and isolation by 2027-01-15. **G2 (estimate):** ≥60% of reported closures on state roads in Jan–Apr 2027 fall on segments rated high at leads 1–3 |
| **M4 Landslides** ([07 §4.4](../../docs/07-impact-modules-and-triggers.md#44-m4-landslides-movimientos-en-masa)) | IMP-06 `landslide_hazard_parish` (`road_km_high`, `people_high`) | Daily LHASA 2.1.1 hazard with WN3 p50 and p90 forcing. Tenant-side TRIGRS at 10–30 m on corridors, including the five priority corridors (licence **to confirm**) | **P2:** G1 by 2027-01-15; G2 at ROC AUC ≥0.70 on the Jan–May 2026 season. **P3:** TRIGRS corridor template |
| Trigger **TR-07** ([07 §6.4](../../docs/07-impact-modules-and-triggers.md#64-example-triggers)) | LHASA class *alta* on ≥3 km of a corridor **and** 30-day rain > P90 (placeholders); lead 1–3 days | Machinery and Bailey-bridge pre-positioning (LT-12, LT-27). The owner in the plan is "MIT / prefecture" | P2. TU-2 needs M4 at G2 and POD ≥0.5 with FAR ≤0.7; otherwise TU-1 ([14 §5.2](../../docs/14-verification-and-validation.md#52-indicator-acceptance-criteria-proposed-to-agree-with-inamhi-and-each-trigger-owner)). A trigger never activates anything by itself |
| M1, M2, M3 as inputs | River status, the tide and rain calendar, SFINCS scenarios | Flood hazard on coastal segments and bridges | M1 and M2 in P1; M3 in P2 |
| Parish exceedance (national) | `parish_exceedance` | Rain probabilities along any corridor | P1. Sierra rain products carry *confianza baja* by default ([14 §5.3](../../docs/14-verification-and-validation.md#53-confidence-labels)) |

The mechanism is overtopping, scour and landslides blocking the Andes–coast corridors ([01 §7.1](../../docs/01-context-el-nino-ecuador.md#71-sector-summary)). The plan has no Sierra landslide event inventory with full coverage; the M4 validation uses the NASA catalogue plus SNGR `COE2` and `EVENTOS_X_LLUVIAS` events.

## 4. Proposed AOIs

T2 allows many AOIs with daily pipelines ([02 §3.2](../../docs/02-users-requirements-ux.md#32-what-each-tier-can-do)). Only corridors and places named in the plan are listed; everything else comes from MIT.

| AOI group | Content | Source | Phase |
|---|---|---|---|
| MIT-1 *Red vial estatal* | The state road network. In Phase 1 it is the Ecuador subset of OSM, GRIP4 and MS Roads (`osm_roads_ecu`); it is replaced by MIT's own network once MIT loads it in its tenant or A8 delivers it | [07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure); `mit_roads_bridges` in [05 §2.8](../../docs/05-data-catalog.md#28-exposure) | P1 |
| MIT-2 *Corredores prioritarios* (5) | The five priority corridors. **The plan does not name them.** It attributes them to MIT/World Bank in 01 §5.3 and to SNGR in 07 §4.4, so their names, geometry and owner are **to obtain from MIT** | 01 §5.3; 07 §4.4 | P1 (AOIs); P2 (TR-07) |
| MIT-3 *Tramos costeros expuestos a inundación* | The flood-exposed state roads in Manabí (740 km), Guayas (594 km) and Los Ríos (222 km), part of 1,870 km | 01 §7.1 | P1 (these provinces are in the MVP geography) |
| MIT-4 *Tramos expuestos a deslizamientos* | 1,243 km of landslide-exposed state roads (provincial split not reported), including the Andes–coast corridors. Sierra provinces the plan prioritises for landslides: Chimborazo and Loja (P2), and Azuay and Cañar (P1 energy, with landslides) | [01 §6.2](../../docs/01-context-el-nino-ecuador.md#62-by-province); SNGR inventory through A2 | P2 (M4) |
| MIT-5 *Estructuras* | The 94 exposed transport structures (Santa Elena 28, Guayas 23, Manabí 23; the rest unreported); bridges from OSM `bridge=yes` | A2 (SNGR); `osm_bq` | P1 static; P2 bridge flag |
| MIT-6 *Puentes Bailey y maquinaria* | Stock and depot locations for the 8 Bailey bridges and 73 machines. This is MIT's own data, kept **only in MIT's tenant** (sensitivity **to confirm**) | 01 §5.3 | P1 (tenant table) |
| MIT-7 *Vías estatales hacia Otavalo* | The state roads serving the Otavalo pilot, which also link the two pilots (segments **to confirm**) | [otavalo.md](./otavalo.md#4-proposed-aois) | P1 |

## 5. GCP project set-up

| Item | Proposal | Source |
|---|---|---|
| Tier | **T2 Standard** now. **T3 Heavy** when MIT wants tenant-side models: TRIGRS corridor runs, RA2CE on its own network, LISFLOOD-FP at bridges, hourly pipelines. Suggested review after M4 reaches G1 (2027-01-15) | [02 §3.2](../../docs/02-users-requirements-ux.md#32-what-each-tier-can-do) |
| Project id | `mit-ectwin-prod` (pattern `<org>-ectwin-prod`). Optionally a second tenant, `mit-ectwin-capacitacion`, for training, since a ministry may run `prod` and `capacitacion` tenants | [04 §3.1](../../docs/04-identity-tenancy-byo-gcp.md#31-definitions) |
| Ownership | Created **inside MIT's own GCP organisation**, never under a personal account | [04 §3.2](../../docs/04-identity-tenancy-byo-gcp.md#32-organisational-vs-personal-tenants) |
| Owners | **At least 2 institutional Owners with TOTP** on `mit.gob.ec` accounts, for example the head of the planning or risk directorate and an IT officer (**to confirm**). Use a **role-based account** such as `gde-datos@mit.gob.ec` for the WeatherNext request, because approval is per Google account | [04 §9](../../docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead) |
| Billing route | MIT's own billing account: an existing GCP contract **(to confirm)** or **R-A**, a local reseller through a SERCOP procedure (weeks to months, **to confirm**). Avoid paying Google LLC directly by bank transfer (withholding risk). Public entity through a reseller: ×1.15–1.265 on list price | [09 §7.2–7.3](../../docs/09-cost-model.md#72-procurement-routes), [13 §7.1](../../docs/13-governance-legal-risk.md#71-how-public-tenants-can-pay-for-their-gcp-project) |
| Fallback if no billing by 2026-11-06 | A temporary sponsored project with a T2 profile in the sponsor folder, if the sponsor agrees. Line C7 funds only 5 × US$14 (T1 profile) in Phase 1, so this is **to confirm with the sponsor**. Otherwise MIT starts at T0, using Commons products | [12 §5.2](../../docs/12-roadmap-team-budget.md#52-cloud-lines) |
| Budget and guardrails, T2 | Budget US$80/month (alerts 50/90/100%). `QueryUsagePerDay` 1 TiB. `QueryUsagePerUserPerDay` 500 GiB. `maximumBytesBilled` 50 GiB. Per-run cap 20 GiB. Earth Engine 5 EECU-h/day. Cloud Run parallelism 10. Confirmation above US$1 | [04 §8.2](../../docs/04-identity-tenancy-byo-gcp.md#82-defaults-per-tier-estimates-tune-in-pilot) |
| Budget and guardrails, T3 (later) | Budget US$1,000 (the Owner may raise it to US$1,300 in peak months). 2 TiB/day. 1 TiB per user. Per-run cap 100 GiB. Earth Engine 25 EECU-h/day. Parallelism 50. Batch ≤8 Spot VMs for 6 h. Confirmation above US$5. Flags `--enable-vertex --enable-batch` | [04 §8.2](../../docs/04-identity-tenancy-byo-gcp.md#82-defaults-per-tier-estimates-tune-in-pilot), [10 §6.4](../../docs/10-setup-and-deployment.md#64-run-the-bootstrap) |
| Expected cost | T2 anchor ≈US$20–60/month: US$19.65 with noncommercial Earth Engine, **US$55.65–59.87 with commercial Earth Engine** (likely for operational use), before 15% IVA and ISD 2.5% (to confirm with SRI). T3 ≈US$540–800, peak ≈US$1,070–1,210 | [09 §4.5–4.6](../../docs/09-cost-model.md#45-tenant-t2-standard-province-or-ministry-50-users-daily-analytics) |
| WeatherNext | File the request **the day the project exists** (≈5–7 business days); subscribe to `weathernext_3` and `weathernext_2` in `US` | TP-07; [10 §6.8](../../docs/10-setup-and-deployment.md#68-weathernext-approval-and-analytics-hub-subscriptions-t2-and-above) |
| Connection path | **Path A** in Cloud Shell ([TUTORIAL.es.md](../../infra/tenant-bootstrap/TUTORIAL.es.md)). If MIT's organisation enforces `iam.allowedPolicyMemberDomains`, the script exits with code 3. Then use **path C1**: the wizard's Spanish exception note, applied by MIT's organisation administrator to this project only ([04 §4.4](../../docs/04-identity-tenancy-byo-gcp.md#44-path-c1--secure-by-default-organisations-and-the-admin-exception-note)). **Path C2** (Workload Identity Federation, no exception) arrives in Phase 2: IT-M11 by 2027-01-31 is "validated with one ministry test organisation", and MIT is a candidate **(to confirm)**. Path D (self-deployed) arrives in Phase 3 | [04 §4.1](../../docs/04-identity-tenancy-byo-gcp.md#41-overview-and-trade-offs), FR-007 |
| Single sign-on | SAML/OIDC for ministries (FR-003) is Phase 2 and optional at T2. Phase 1 uses Google or email-and-password sign-in with TOTP | [04 §2.4](../../docs/04-identity-tenancy-byo-gcp.md#24-tier-2-samloidc-for-ministries-phase-2-fr-003) |

```bash
# MIT organisation (10 §6.2); ids and org are to confirm with MIT's IT unit
TP=mit-ectwin-prod; TORG="<TENANT_ORG_ID>"; TBA="<TENANT_BILLING_ACCOUNT>"
gcloud projects create $TP --organization=$TORG --labels=ectwin-tenant=true
gcloud billing projects link $TP --billing-account=$TBA

# Tenant administrator in Cloud Shell, with the connection code from the web app (04 §4.2)
scripts/bootstrap-tenant.sh --project $TP --dry-run
scripts/bootstrap-tenant.sh --project $TP --tier T2 --budget-usd 80 --connection-code c-<CODE>
echo "exit code: $?"   # 3 = complete with actions: budget or org policy (domain-restricted sharing -> path C1 note)
scripts/verify-tenant.sh --project $TP
```

## 6. Onboarding steps and dates

The steps follow the Phase 0–1 calendar ([12 §2.1–2.2](../../docs/12-roadmap-team-budget.md#2-phase-plans)) and the adoption playbook ([12 §7.3](../../docs/12-roadmap-team-budget.md#73-adoption-playbook-for-a-new-tenant)). Dates marked "proposed" are this brief's suggestion.

| # | Step | Date | Who | Done when |
|---|---|---|---|---|
| 1 | Kick-off (D0): legal name (V10), directorate, focal point and backup, 2 Owners, IT administrator, billing route; check whether a GCP organisation exists and whether it enforces domain-restricted sharing (TP-05) | By 2026-10-09 (proposed) | PT, MIT | Route chosen |
| 2 | MIT analysts in the W3 interviews (12–16 Oct) to write the missing MIT persona | 12–16 Oct | UX | Interview notes |
| 3 | **Letter of intent signed** (draft in §10) **and A8 letter sent**, since the A8 letter target is the same date | **By 2026-10-16** | Minister or delegate; PT | P0-06; A8 "letter sent" |
| 4 | Project created with billing; WeatherNext request filed the same day with the role-based account | By 2026-10-23 (proposed); latest trigger 2026-11-06 | MIT IT, PT | TP-01, TP-02, TP-07 |
| 5 | If domain-restricted sharing applies: generate the exception note (IT-M5, 2026-10-23) and send it to MIT's organisation administrator | 23–30 Oct (proposed) | PL, MIT org admin | Exception applied, or path decision recorded |
| 6 | **Onboarding clinic**: bootstrap (path A), `verify-tenant.sh`, *Conectar*; Earth Engine registration (commercial) with a 5 EECU-h/day cap | W2–W3, 26 Oct – 6 Nov | MIT TA, PL, FAC | Preflight green |
| 7 | Second Owner invited; tenant register recorded | Same week | MIT | TA-04 |
| 8 | Interim terms of use and privacy notice accepted (B1a) | By 2026-11-06 (G1a) | MIT Owner, DPO | Record |
| 9 | Commons subscription (M1.2); WeatherNext linked datasets once approved; AOI groups MIT-1 to MIT-7; first runs | From 2026-11-06 | MIT TA | TA-03; VT-11 |
| 10 | Training wave 1: C2 for administrators, C1 for analysts | 9–13 Nov | TR, FAC | F1 |
| 11 | IT-M8 (3 pilot tenants green, ≥1 T2); processor contract signed (B1b) | 2026-11-13 | PL, DPO | TA-01 to TA-05 |
| 12 | Static road-segment exposure (IMP-15) available to MIT | 2026-11-20 | IM, DL | Layer in `ectwin_commons` |
| 13 | G1b; go-live; freeze 26 Nov – 1 Dec | 24 / 27 Nov | SC | — |
| 14 | A8 annex agreed / A8 signed | 2026-12-01 / 2027-02-15 | PT | K3 |
| 15 | M4 at G1 and dynamic M9; TR-07 thresholds drafted with MIT as owner; sector training C5, C7, C8 | 2027-01-15; Jan–Feb 2027 | IM, TR | Trigger definition v0 |
| 16 | Path C2 test with MIT as the ministry test organisation (if agreed); tier review T2 → T3 | By 2027-01-31; after 2027-01-15 | PL; PT, MIT | IT-M11; decision recorded |

## 7. Data exchange (MIT ↔ agreement A8)

Agreement **A8 MIT (ex-MTOP)** covers "road network, bridges and closures", for the roads and bridges module. It is a *convenio* at priority P2, with targets of letter 2026-10-16, annex 2026-12-01 and signature 2027-02-15 ([05 §6.1](../../docs/05-data-catalog.md#61-agreements-needed)). The catalogue entry `mit_roads_bridges` is in the `agreement` class, pushed to Commons, Phase 2. That class means internal inputs only, derived outputs only if the agreement allows, and never raw data ([05 §5.1](../../docs/05-data-catalog.md#51-licence-classes)).

| Flow | Content | Before A8 is signed | After A8 |
|---|---|---|---|
| MIT → MIT's own tenant | Network, closures, Bailey-bridge stock, depots, corridor geometry | **Allowed now.** MIT's data stays in `mit-ectwin-prod` and is joined to Commons hazard layers by MIT's own jobs; the operator has no access to tenant content (FR-064) | Unchanged |
| MIT → Commons | State road network and bridges (replacing OSM and MS Roads for state roads); closure reports for M9 validation | Not ingested | Pushed under the data annex (format, cadence, ≥30 days' notice of changes, the "platform issues no alerts" clause and reciprocity) ([05 §6.2](../../docs/05-data-catalog.md#62-draft-mou-checklist-technical-and-data-annex)) |
| Commons → MIT | `road_segment_risk`, `isolation_parish`, `landslide_hazard_parish`, `facility_exposure`; verification scores; OGC/ArcGIS-compatible layers (FR-023, Phase 2); archived copies; training | Available through the Commons listing | Plus products built on MIT's network, as the licence allows |
| SNGR → Commons (A2) | The inventory of 3,113 km of roads and 94 structures | A2 targets signature by 2026-11-06 | — |
| ECU 911 (A9) | Road status (link only; scraping method **to confirm**) | Link | Feed, if A9 is signed (2027-02-28) |

**Suggestion:** send the A8 technical annex with the letter of intent so that MIT's network can reach the dynamic M9 release (2027-01-15) rather than waiting for the 2027-02-15 signature. **Licences:** outputs built on OSM or MS Roads are share-alike (ODbL), so exports carry the G-06 obligations ([05 §5.3](../../docs/05-data-catalog.md#53-gating-rules)).

## 8. Success criteria

| # | Criterion | Target | By | Source |
|---|---|---|---|---|
| M1 | Letter of intent signed; A8 letter sent | Both | 2026-10-16 | P0-06; 05 §6.1 |
| M2 | Project with billing and 2 Owners with TOTP; WeatherNext request filed | Done | 2026-10-30 (proposed); trigger 2026-11-06 | TP-01, TP-02, TP-07 |
| M3 | Domain-restricted sharing handled, if present: exception applied through the C1 note, or path decision recorded (evidence for AC-09) | Done | Before IT-M8 | FR-007; [10 §12](../../docs/10-setup-and-deployment.md#12-open-questions) |
| M4 | Tenant acceptance: `verify-tenant.sh --strict` exits 0 with Earth Engine registered; PF-12 green; WeatherNext linked datasets readable once approved (VT-11) | All green | 2026-11-13 (IT-M8) | [10 §6.14](../../docs/10-setup-and-deployment.md#614-tenant-acceptance) |
| M5 | Pilot pipeline success | ≥98% over 7 days | Before G1b | ST-30 |
| M6 | Cost | Within the T2 anchor (≈US$20–60 before IVA); budget US$80 not exceeded | 7 days before G1b; monthly | [12 §9](../../docs/12-roadmap-team-budget.md#9-pilot-gono-go-checklist) G1 |
| M7 | Analysts completed C1 and administrators C2 | 100% of pilot users | 13 Nov | F1 |
| M8 | Official vs platform distinction; confusion incidents | ≥95%; 0 | G1a / G1b; ongoing | K7, K8 |
| M9 | Static IMP-15 layer used in MIT's LT-12 planning (e.g. a pre-positioning annex for the 5 corridors) | Used and feedback logged | 2026-11-27 | LT-12 |
| M10 | A8 annex agreed; A8 signed | Both | 2026-12-01; 2027-02-15 | 05 §6.1, K3 |
| M11 | M9 G2: share of reported closures on state roads (Jan–Apr 2027) that fall on segments rated high at leads 1–3 | ≥60% | G2, 2027-04-30 | [07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure) |
| M12 | M4 G2 and TR-07 eligibility | ROC AUC ≥0.70; TR-07 at TU-1 or better with MIT as owner | Phase 2 | [07 §4.4](../../docs/07-impact-modules-and-triggers.md#44-m4-landslides-movimientos-en-masa), 14 §5.2 |
| M13 | Tier review T2 → T3 | Decision recorded | After 2027-01-15 | This brief |

## 9. Risks and mitigations

| Risk | Plan link | Mitigation |
|---|---|---|
| **Data agreement timing:** A8 is signed only on 2027-02-15; the MTOP geoportal is dead and there is no open download | [05 §6.1](../../docs/05-data-catalog.md#61-agreements-needed); PRG-04 | Phase 1 runs on OSM, GRIP4 and MS Roads; MIT loads its own data into its tenant now; the annex goes with the letter of intent; escalate through the SC if the annex slips past 2026-12-01 |
| **Domain-restricted sharing** on MIT's organisation. Organisations created on or after 2024-05-03 enforce `iam.allowedPolicyMemberDomains` by default; this applies to MIT's organisation if it exists **(to confirm)** | [04 §4.4](../../docs/04-identity-tenancy-byo-gcp.md#44-path-c1--secure-by-default-organisations-and-the-admin-exception-note) | Check at kick-off (TP-05). **C1:** project-only exception note (the organisation's change process may take days). **C2:** WIF without an exception from Phase 2 (IT-M11, 2027-01-31). **D:** self-deployed copy in Phase 3 |
| **Procurement or billing** not in place | R14 / PRG-09; [13 §7.1](../../docs/13-governance-legal-risk.md#71-how-public-tenants-can-pay-for-their-gcp-project) | Existing contract or R-A reseller; never a direct bank transfer to Google LLC; sponsored T2-profile fallback (sponsor agreement) or T0 until billing exists |
| **Institutional change:** name (V10), reorganisation or new focal points | R27; CTX-13 | Confirm the legal name before signing. Apply the R27 mitigations in [13 §11.2](../../docs/13-governance-legal-risk.md#112-register): tripartite *convenios* and the transfer clause (clause 13 of the *convenio* template). Keep ≥2 Owners and a named focal point with a backup |
| **Scope expectations:** Phase 1 has static exposure for the six coastal provinces only; landslides and dynamic risk come in Phase 2; Sierra rain has *confianza baja* | [07 §8](../../docs/07-impact-modules-and-triggers.md#8-outputs-catalogue-and-phasing); 14 §5.3 | State this at kick-off; show TU levels on TR-07; never present segment levels as closure orders |
| **Sensitive operational data** (machinery and Bailey-bridge positions) | 05 §6.2 item 11 | Keep them in MIT's tenant only; A8 confidentiality clause **(to confirm whether critical-infrastructure clauses apply)** |
| **WeatherNext** approval is per account and the terms can change | R03; [04 §9](../../docs/04-identity-tenancy-byo-gcp.md#9-third-party-access-per-tenant-and-what-the-commons-provides-instead) | Role-based account; Commons products do not depend on MIT's own approval |
| **Earth Engine commercial cost** | [13 §4.1](../../docs/13-governance-legal-risk.md#41-tenant-licence-profile) | The 5 EECU-h/day cap bounds it at ≈US$60/month ([04 §8.2](../../docs/04-identity-tenancy-byo-gcp.md#82-defaults-per-tier-estimates-tune-in-pilot)) |
| **Freeze and election window** (26 Nov – 1 Dec) | [12 §1](../../docs/12-roadmap-team-budget.md#1-urgency-and-phase-overview) | Finish onboarding changes by the 25 Nov release; hypercare at posture N1 |

**Open items to confirm:** the legal name (V10) and signatory; the GCP organisation, Workspace and domain-restricted sharing; the billing route; the names and geometry of the 5 priority corridors; the A8 annex contents and confidentiality; the TRIGRS licence; and the state roads serving Otavalo.

## 10. Borrador: carta de invitación e intención de participación

> *Borrador para revisión (PT y DPO). Reemplace los campos entre corchetes y confirme el nombre legal del ministerio.*

[Ciudad], [fecha]

Señor/a [NOMBRE]
Ministro/a de Infraestructura y Transporte
Ministerio de Infraestructura y Transporte (MIT)

De nuestra consideración:

El programa *Gemelo Digital Ecuador – El Niño* (GDE-Niño) invita al MIT a participar como institución piloto durante la temporada 2026-2027.

GDE-Niño es una herramienta de **apoyo a la decisión**. Estima la exposición de tramos viales, puentes y parroquias a inundaciones y deslizamientos, siempre debajo de las alertas oficiales. **GDE-Niño no emite alertas.** Las alertas oficiales las declara la Secretaría Nacional de Gestión de Riesgos (SNGR), con base en la información de INAMHI, INOCAR y el CN-ERFEN.

La participación incluye:

1. Un proyecto de Google Cloud en la organización del MIT (nivel T2 Standard, costo estimado de US$20–60 al mes antes de impuestos, con presupuesto de control de US$80), a cargo de al menos dos propietarios con cuentas institucionales.
2. Referentes técnicos de [DIRECCIÓN] para la preubicación de maquinaria y puentes Bailey y los corredores prioritarios.
3. Capacitación virtual entre el 9 y el 13 de noviembre de 2026.
4. Un convenio de intercambio de datos sobre red vial, puentes y cierres. Los datos del MIT permanecen en su propio proyecto; su uso en productos nacionales se regirá por ese convenio.

El MIT recibirá capas de exposición vial y, desde 2027, amenaza diaria de deslizamientos, además de acompañamiento técnico. Esta carta expresa una intención y no genera obligaciones financieras adicionales. Agradeceremos su respuesta hasta el **16 de octubre de 2026**.

Atentamente,

[NOMBRE], [CARGO]
GDE-Niño – [institución responsable / patrocinador]

**Intención de participación.** El MIT manifiesta su intención de participar como institución piloto de GDE-Niño y designa como propietarios del proyecto a [NOMBRE 1, cargo, correo institucional] y [NOMBRE 2, cargo, correo institucional], y como punto focal del convenio de datos a [NOMBRE, cargo].

[Firma] · [Nombre] · [Cargo] · [Fecha]
