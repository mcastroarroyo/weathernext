---
name: verify-deployment
description: Run read-only checks on a GDE-Niño deployment (Cloud Run service responds, legal notice present, public/private status, BigQuery tables). Use after deploying or refreshing, or when the user asks whether the twin is working.
---

# Verify a deployment

```bash
.agents/skills/verify-deployment/scripts/verify.sh --project <PROJECT_ID> --region <REGION> --service <SERVICE>
```

The script changes nothing. Report each `PASS` / `FAIL` / `INFO` line to the user as it is. A `FAIL` on the legal notice means the page was built from a template without it: stop and tell the user before anyone uses the page.
