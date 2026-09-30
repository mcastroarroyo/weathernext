# Pilot tenants: roster and status

This folder holds the briefs for the Phase 1 pilot tenants of *Gemelo Digital Ecuador – El Niño* (GDE-Niño). The plan asks for 3–5 pilot tenants with signed letters of intent by **2026-10-16** (P0-06 in [12 §2.1](../../docs/12-roadmap-team-budget.md#21-phase-0--mobilise-2026-09-29--2026-10-16)). On 2026-09-30 the programme nominated the first two: **"Municipio de Otavalo, MIT.gob.ec — those 2 for now."**

**Status (2026-09-30): 2 of 3–5 nominated.** Otavalo (T4 with a T1 profile, or T1 on its own project) and MIT (T2). A coastal GAD and a commercial private tenant are still open (see the [gap note](#gap-what-these-two-pilots-do-not-cover)).

Every fact here comes from documents 01–14 or the research briefs. Anything else is marked **(to confirm)**. GDE-Niño is decision support: it issues no alerts, and only SNGR declares alerts ([13 §1](../../docs/13-governance-legal-risk.md#1-alert-authority-and-product-positioning)).

## Roster

| Pilot | Organisation type | Proposed tier | Alternative | Billing route | Suggested project id | Default budget | Brief |
|---|---|---|---|---|---|---|---|
| **GAD Municipal de Otavalo** (Imbabura, Sierra) | Cantonal GAD (`org_type=gad`) | **T4 Sponsored, T1 profile** | T1 on its own organisation-owned project, if the GAD can buy GCP in time | R-B: a project in the sponsor's `ectwin-sponsored` folder on the sponsor's T4 billing account. The alternative is R-A (local reseller) or R-C (*convenio*) with the GAD's own billing account | `gad-otavalo-ectwin-prod` | US$20/month, set by the sponsor (T4 default) | [otavalo.md](./otavalo.md) |
| **MIT**, Ministerio de Infraestructura y Transporte (ex-MTOP) | Ministry (`org_type=ministerio`) | **T2 Standard** | Grow to **T3 Heavy** for tenant-side landslide and road modelling (Phase 2–3) | Ministry billing account: an existing GCP contract **(to confirm)** or R-A (local reseller through a SERCOP procedure) | `mit-ectwin-prod` | US$80/month (T2); US$1,000 if T3 | [mit.md](./mit.md) |

Tier budgets come from [04 §8.2](../../docs/04-identity-tenancy-byo-gcp.md#82-defaults-per-tier-estimates-tune-in-pilot). Cost anchors before 15% IVA come from [09 §4](../../docs/09-cost-model.md#4-monthly-estimates): T1 ≈US$0–14, T2 ≈US$20–60 and T3 ≈US$540–800 (peak ≈US$1,070–1,210). Billing routes R-A to R-E are defined in [09 §7.2](../../docs/09-cost-model.md#72-procurement-routes) and [13 §7.1](../../docs/13-governance-legal-risk.md#71-how-public-tenants-can-pay-for-their-gcp-project). Project ids follow `<org>-ectwin-prod`. They are suggestions only: each organisation chooses its own id ([10 §6.2](../../docs/10-setup-and-deployment.md#62-create-the-project-if-needed)).

### Why these tiers

**Otavalo: T4 with a T1 profile.**

- **Persona fit.** The plan's persona for a mid-size cantonal GAD is P04. Its tier is "T4 sponsored project with T1 capabilities; the canton's daily PDF is the core product" ([02 §2.3](../../docs/02-users-requirements-ux.md#23-persona-cards)). [01 §8.2](../../docs/01-context-el-nino-ecuador.md#82-actors-roles-and-what-the-twin-exchanges-with-them) lists GADs as "T1/T4 tenants; org-owned projects".
- **Procurement timing.** A local reseller (R-A) needs a SERCOP procedure of weeks to months (to confirm). A T4 project is ready days after the sponsor agrees (R-B), and the target is ≤2 business days from request to project (FR-010).
- **Budget.** Budget line C7 already funds 5 T4 projects at US$14 each in Phase 1 ([12 §5.2](../../docs/12-roadmap-team-budget.md#52-cloud-lines)).
- **Scope of T1.** A T1 profile gives the canton PDF with the GAD's branding, saved views, 1–3 daily AOIs and subscriptions. It needs no WeatherNext approval of its own (TP-07 in [10 §6.1](../../docs/10-setup-and-deployment.md#61-before-you-start-tenant-administrator)).
- **When to choose T1 instead.** If the GAD already has, or can get, a billing account before 2026-11-06, the same T1 profile on its own project avoids a later billing move. That date is the Phase 1 trigger to move a GAD to T4 ([12 §2.2](../../docs/12-roadmap-team-budget.md#22-phase-1--mvp-monitoreo-y-exposición-2026-10-19--2026-11-27), Phase 1 risks). A T4 project can graduate to the GAD's own billing later ([04 §10.1](../../docs/04-identity-tenancy-byo-gcp.md#101-scenarios)).

**MIT: T2 Standard, with the option to grow to T3.**

- **Persona fit.** [01 §8.2](../../docs/01-context-el-nino-ecuador.md#82-actors-roles-and-what-the-twin-exchanges-with-them) already lists MIT as a "T2 tenant". MIT's sector analysts sit in training audience AUD-5 ([12 §7.1](../../docs/12-roadmap-team-budget.md#71-audiences-and-targets)).
- **What T2 adds.** Daily analytics on many AOIs, Earth Engine, its own WeatherNext linked datasets, trigger dashboards and uploads of its own asset inventory (FR-077) ([02 §3.2](../../docs/02-users-requirements-ux.md#32-what-each-tier-can-do)).
- **When T3 is needed.** Custom models, 2D runs and hourly pipelines are T3 only. That covers TRIGRS corridor runs at 10–30 m ([07 §4.4](../../docs/07-impact-modules-and-triggers.md#44-m4-landslides-movimientos-en-masa)), RA2CE isolation on MIT's own network ([07 §4.9](../../docs/07-impact-modules-and-triggers.md#49-m9-transport-and-critical-infrastructure)) and LISFLOOD-FP reach runs at bridges. The step to T3 fits Phase 2–3, after M4 reaches G1 (2027-01-15), and would be decided then.

## What each pilot tests in the plan

| Plan element | Otavalo | MIT |
|---|---|---|
| **Access path** | T4 end to end: the sponsor folder, labels `ectwin-sponsor` and `ectwin-dpa`, sponsor billing, and the "first pilot bootstrap (sponsored T4)" in W2, 26–30 Oct ([12 §2.2](../../docs/12-roadmap-team-budget.md#22-phase-1--mvp-monitoreo-y-exposición-2026-10-19--2026-11-27)) | A self-paid public T2 tenant. It also tests domain-restricted sharing and the path C1 exception note (FR-007, IT-M5, AC-09), and could be the ministry test organisation for path C2 WIF (IT-M11, 2027-01-31) **(to confirm)** |
| **Hazard pathway** | The **Andean/Sierra pathway** outside the MVP geography. Imbabura is priority P3, "limited direct signal" ([01 §6.2](../../docs/01-context-el-nino-ecuador.md#62-by-province)). The El Niño rainfall direction there is not asserted and must be confirmed with INAMHI | The **national road network**: coastal flood-exposed roads (1,870 km) and landslide-exposed roads (1,243 km, which include the Andes–coast corridors) ([01 §7.1](../../docs/01-context-el-nino-ecuador.md#71-sector-summary)) |
| **Modules** | M4 landslides on access roads; national parish exceedance for intense rain and *quebradas* (no dedicated Andean product exists; see the brief); M8 drought-lite for water supply (to confirm); M9 access roads | M9 transport and critical infrastructure (IMP-15), M4 landslides (IMP-06); M1/M2 as inputs to segment hazard |
| **Decisions (lead-time rows in [01 §9.2](../../docs/01-context-el-nino-ecuador.md#92-lead-time-matrix))** | LT-11 drainage and channel maintenance; LT-16 COE canton pack; LT-19 COE activation (the official decision rests with SNGR and the COE); LT-26 landslide response | LT-12 machinery and Bailey-bridge pre-positioning on 5 priority corridors; LT-27 road closures |
| **Users** | Kichwa-speaking users: the requirements for Kichwa audio and SMS, which are Phase 3 and need native review (FR-076). Low connectivity and power cuts | Sector analysts (AUD-5); a GIS and planning team (to confirm) |
| **Governance** | **Local elections on 29 Nov 2026:** does an institutional workspace survive the change of authorities (CTX-12, FR-016)? | Data agreement **A8** (road network, bridges, closures) ([05 §6.1](../../docs/05-data-catalog.md#61-agreements-needed)) |
| **Risk register** | R14 (procurement); R23 (equity: lower quality or access in the Andes and for Kichwa speakers); R27 and PRG-10 (change of GAD authorities after 29 Nov) ([13 §11.2](../../docs/13-governance-legal-risk.md#112-register)) | R14 (procurement); R27 (ministry renaming or reorganisation stalls agreements) |

The two pilots also meet on the ground. State roads that serve Otavalo (which segments are state roads is **to confirm** with MIT) test whether MIT's corridor view and a GAD's local view give the same answer.

## Gap: what these two pilots do not cover

The two nominations satisfy two of P0-06's three composition rules: ≥1 T4 GAD (Otavalo) and ≥1 T2 public tenant (MIT). They do **not** satisfy the count or the third rule.

| Plan criterion | Source | Covered by Otavalo + MIT? | Consequence if nothing is added |
|---|---|---|---|
| 3–5 pilots with signed letters of intent by 2026-10-16 | P0-06, [12 §2.1](../../docs/12-roadmap-team-budget.md#21-phase-0--mobilise-2026-09-29--2026-10-16) | **No**: 2 of 3 minimum | G0 item (f), "≥3 pilot letters of intent are signed", fails on 2026-10-16. Under 12 §2.1, a failed G0 does not stop Phase 1, but the SC then switches to the minimum variant and records the scope cuts |
| ≥1 commercial private tenant (e.g. a CNA shrimp cluster or an AgroProtege insurer) | P0-06; Phase 1 objective 2 in 12 §2.2; [12 §6.3](../../docs/12-roadmap-team-budget.md#63-partnership-instruments) | **No** | **Checklist item B5 blocks both G1a (2026-11-06) and G1b (2026-11-24):** "the commercial-profile pilot tenant sees no NC layer (FR-073 test)". With no commercial pilot tenant, B5 cannot be evidenced as written. One red B item means no-go ([12 §9](../../docs/12-roadmap-team-budget.md#9-pilot-gono-go-checklist)). J5 and J10 also go unexercised by a real user |
| 3 pilot tenants connected (≥1 T4, ≥1 T2) by 2026-11-13 | IT-M8, [04 §14](../../docs/04-identity-tenancy-byo-gcp.md#14-delivery-plan-and-acceptance-criteria) | **Partly**: T4 and T2 are covered, but only 2 tenants | IT-M8 misses its count. ST-30 ("3 pilot tenants, 7 days, ≥98%") cannot turn green, and the go-live gate needs ST-00 to ST-30 green or explicitly waived by the SC at G1b ([10 §7](../../docs/10-setup-and-deployment.md#7-smoke-tests-and-acceptance-checks)) |
| A **coastal GAD**. P0-06 names no region, but the Phase 1 design centres on the coast | CTX-08 MVP geography; Phase 1 exit in [07 §8](../../docs/07-impact-modules-and-triggers.md#8-outputs-catalogue-and-phasing); J1 (GAD Portoviejo); P03/P04; tabletop with the Guayas and Manabí COEs; training wave 2 in Guayaquil and Portoviejo | **No**. MIT covers coastal roads but is not a GAD | Phase 1 products (IMP-01 risk index v1, IMP-02 rivers, IMP-03 tide and rain calendar, IMP-15–18 exposure) are live only for the six coastal P1 provinces. No pilot GAD would use them on its own AOIs during the Dec–Apr coastal rainy season. The OPS-M4 event drill "with a pilot COE" (2026-11-20) and wave 2 would have no coastal pilot tenant |

**What is not covered, in short:** the commercial licence profile and its gating (FR-073, B5); self-paid private onboarding with card or IVA-creditable billing ([09 §7.3](../../docs/09-cost-model.md#73-effective-cost-table)); a GAD inside the MVP flood geography; the coastal flood products at GAD level (M1, M2 tide and rain, later M3 SFINCS); and the aquaculture and agriculture cards (M5, M6).

### Candidates to add later (suggestions only; the PT and the SC decide)

All three candidates are drawn from the plan documents. The dates they must meet are P0-06 (letter by 2026-10-16) and IT-M8 (connected by 2026-11-13).

1. **A coastal GAD: GAD Portoviejo (Manabí), on T4 with a T1 profile.** It is the plan's worked example: journey J1, persona P04, the M3 Portoviejo/Chone SFINCS library and training wave 2 in Portoviejo. It is also named in agreement A13. An alternative is **Guayaquil / Segura EP** on T2 (self-paid metropolitan GAD). Segura EP is persona P03, M2 is "Guayaquil first", decision row LT-25 applies, and its layers are already public on ArcGIS Online. Esmeraldas and Machala are further P04 options.
2. **A commercial private tenant on the aquaculture side: a CNA shrimp cluster (El Oro)**, on T1 moving to T2 with a commercial profile. It exercises journey J5, the Phase 1 M6 basic shrimp card and the B5 licence-gating test. P0-06 cites it as its own example.
3. **A commercial private tenant on the finance side: an AgroProtege insurer.** The docs name Hispana de Seguros y Reaseguros and Equisuiza. It would start on T2 with a commercial profile (portfolio upload, FR-077, J10), with T3 later. P0-06 also cites it. A banana exporter through Acorbanec (P10 variant) is an alternative.

Adding candidates 1 and 2 (or 1 and 3) would give 4 pilots. That meets the P0-06 count and composition, G0 (f), IT-M8 and ST-30, and lets B5 be evidenced in a real tenant.

## Files

- [otavalo.md](./otavalo.md): the GAD Municipal de Otavalo brief, with a draft Spanish letter.
- [mit.md](./mit.md): the MIT brief, with a draft Spanish letter.

PT (partnerships lead) owns all pilot outreach. PL and FAC support onboarding, and TR runs training ([12 §4.1](../../docs/12-roadmap-team-budget.md#41-role-catalogue)). Each pilot's own tenant administrator (TA, persona P13) runs the bootstrap.
