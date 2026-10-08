---
name: teardown-gde-nino
description: Remove a GDE-Niño deployment from the user's Google Cloud project (Cloud Run service and, only if asked, the BigQuery tables). Use when the user asks to delete, remove, uninstall or tear down GDE-Niño.
---

# Tear down a deployment

Deleting is irreversible. Never delete anything without the user's explicit confirmation of the exact resources.

1. List what exists and show it to the user:

```bash
gcloud run services list --project <PROJECT_ID> --filter='metadata.labels.app=ectwin'
bq --project_id=<PROJECT_ID> ls ectwin_commons
```

2. Ask which of these to delete. The default is the Cloud Run service only; BigQuery data stays unless the user names the tables.
3. After a clear "yes" for each item:

```bash
gcloud run services delete <SERVICE> --region <REGION> --project <PROJECT_ID>
bq --project_id=<PROJECT_ID> rm -t ectwin_commons.area_exceedance     # only if confirmed
bq --project_id=<PROJECT_ID> rm -t ectwin_commons.river_forecast      # only if confirmed
```

4. Do not delete the dataset, enabled APIs, the Artifact Registry repository `cloud-run-source-deploy`, or anything not labelled `app=ectwin`; mention them so the user can decide.
