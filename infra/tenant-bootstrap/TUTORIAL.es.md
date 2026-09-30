# Conectar su proyecto de Google Cloud a GDE-Niño (Gemelo Digital Ecuador – El Niño)

## 1. Qué hace este tutorial y qué crea en su proyecto

<walkthrough-tutorial-duration duration="30"></walkthrough-tutorial-duration>

Este tutorial prepara un proyecto de Google Cloud **de su institución** (la unidad de riesgos de un GAD, un ministerio, una exportadora) como espacio de trabajo de GDE-Niño, por la ruta de conexión A. Toma ≈8–12 min, más ≈3 min para registrar Earth Engine (estimaciones).

Las sesiones, áreas de interés, ejecuciones de modelos y reportes se guardan en **su** proyecto (Firestore, BigQuery y Cloud Storage) y se facturan a su cuenta. La plataforma solo guarda un registro mínimo: el identificador del espacio (tenant id), el proyecto, la cuenta de servicio, el rol de cada miembro y la aceptación de los términos.

| Recurso | Nombre | Ubicación |
|---|---|---|
| Cuenta de servicio, sin claves | `ectwin-runner@PROYECTO.iam.gserviceaccount.com` | — |
| BigQuery | `ectwin`, `ectwin_scratch` (tablas temporales de 7 días) | `US` |
| Bucket | `gs://PROYECTO-ectwin` | `us-central1` |
| Firestore | `(default)` nativo; las sesiones caducan a los 30 días | `southamerica-west1` |
| Pub/Sub | `ectwin-budget-alerts` (+ `ectwin-budget-alerts-guard`), `ectwin-notify` | — |
| Presupuesto | `ectwin-PROYECTO`: avisos al 50/90/100 % y al 100 % pronosticado | Cuenta de facturación |
| Secret Manager | `typesafe-api-key`, `floodforecasting-api-key` (vacíos) | — |
| APIs | 19 básicas (+ Vertex AI, Batch y Compute en T3) | — |

**La plataforma recibe un único permiso**: `roles/iam.serviceAccountTokenCreator` sobre la cuenta `ectwin-runner` (no sobre el proyecto), para `ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com`. Con él obtiene tokens de ≤15 min limitados a los permisos de `ectwin-runner`. No puede cambiar IAM, crear claves, borrar recursos ni leer otros datasets o buckets. Cada llamada queda en los registros de auditoría de su proyecto.

**Costo mensual esperado** (estimaciones de `docs/09-cost-model.md`, sin el 15 % de IVA ni el ISD):

| Nivel | Perfil | Costo esperado | Presupuesto (US$) |
|---|---|---|---|
| T1 Ligero | GAD cantonal, ≈20 usuarios | ≈US$0–14 | 20 |
| T2 Estándar | Provincia o ministerio, ≈50 usuarios | ≈US$20–60 | 80 |
| T3 Intensivo | Agencia nacional o aseguradora | ≈US$540–800 (≈US$1070–1210 en un mes pico) | 1000 (hasta 1300 en meses pico) |
| T4 Patrocinado | Proyecto en la carpeta de un patrocinador | Como T1/T2 | Lo fija el patrocinador (20 por defecto) |

Sin datos, los recursos cuestan ≈US$0. **El presupuesto solo envía avisos. No detiene el gasto.**

«Producto informativo de apoyo a la decisión; no constituye alerta oficial. Las alertas oficiales las declara la Secretaría Nacional de Gestión de Riesgos (SNGR) con base en la información de INAMHI, INOCAR y el CN-ERFEN. Consulte gestionderiesgos.gob.ec y alertasecuador.gob.ec.»

## 2. Requisitos

- **Un proyecto de la organización, no uno personal**, para que sobreviva a los cambios de personal. Si no lo tiene, créelo en su organización o solicite en la app un proyecto patrocinado (T4).
- **Facturación habilitada.** El sandbox de BigQuery no sirve.
- **Rol Propietario (Owner)** del proyecto, o el conjunto mínimo de `docs/04-identity-tenancy-byo-gcp.md` §5.3.3. El script comprueba los permisos antes de cambiar nada.
- **Para el presupuesto**: Owner o Editor del proyecto, o *Billing Account Costs Manager*. Sin ese permiso, el resto se crea igual y el script termina con código 3.
- **Políticas de organización** que permitan `US`, `us-central1` y `southamerica-west1` (`constraints/gcp.resourceLocations`).
- **Uso compartido restringido por dominio** (`iam.allowedPolicyMemberDomains`, activo por defecto en organizaciones creadas desde el 2024-05-03). Bloquea el permiso para `ectwin-broker`. Hay dos rutas:
  - **C1**: su administrador aprueba una excepción solo para ese principal y solo en este proyecto. La plantilla en español está en `infra/tenant-bootstrap/README.md` §9, y la app también genera la nota.
  - **C2**: federación de identidades (fase 2).

  Puede continuar de todos modos: el script crea todo lo demás, termina con código 3 y usted lo repite tras la excepción.

## 3. Seleccione el proyecto y defina las variables

<walkthrough-project-setup></walkthrough-project-setup>

Si abrió el tutorial con *Abrir en Cloud Shell*, la terminal ya está en el repositorio. Si no, clónelo: `git clone <REPO_URL> weathernext && cd weathernext`. La URL pública está **por confirmar**.

```bash
PROJECT_ID="id-de-su-proyecto"            # p. ej. gad-portoviejo-ectwin
TIER="T1"                                  # T1, T2, T3 o T4
BUDGET_USD=20                              # T1 20 · T2 80 · T3 1000
FIRESTORE_LOCATION="southamerica-west1"    # o southamerica-east1; NO se puede cambiar después
gcloud config set project "$PROJECT_ID"
BA="$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingAccountName)')"
BILLING_ACCOUNT="${BA##*/}"
REPO="$(git rev-parse --show-toplevel)" && cd "$REPO"
```

Compruebe los requisitos:

```bash
gcloud projects describe "$PROJECT_ID" --format='value(lifecycleState,parent.type)'
gcloud billing projects describe "$PROJECT_ID" --format='value(billingEnabled)'
echo "Cuenta de facturación: $BILLING_ACCOUNT"
```

Debe ver `ACTIVE` junto a `organization` o `folder`, y luego `True`. Una ubicación `us-*` para Firestore exige una revisión LOPDP. Si Cloud Shell se reinicia, repita el primer bloque.

## 4. Obtenga el código de conexión en la app

En la app, abra *Proyecto y costos → Conectar proyecto* y elija tipo de organización, uso (comercial o no comercial), sector, nivel, perfil de región y la ruta **A (Cloud Shell)**. La app muestra **una sola vez** un código de conexión: `c-` más 26 caracteres, válido 24 h.

```bash
CONNECTION_CODE="PEGUE_AQUI_SU_CODIGO"
[[ "$CONNECTION_CODE" =~ ^[a-z0-9_-]{8,63}$ ]] && echo "Formato válido" || echo "Revise el código"
```

El bootstrap guarda el código como etiqueta `ectwin-connection` en el dataset `ectwin`. Al conectar, la plataforma lee la etiqueta y la compara con el código que le entregó, lo que demuestra que usted controla el proyecto. Si el código vence, pida otro y repita el paso 5: el bootstrap es idempotente.

## 5. Ejecute el bootstrap: opción A (Terraform) u opción B (script)

Elija **una** opción. Ambas crean lo mismo, se pueden repetir sin riesgo y nunca borran datos.

**Opción A: Terraform** (recomendada para equipos de TI; requiere Terraform 1.6 o posterior)

```bash
cd "$REPO/infra/tenant-bootstrap" && terraform version
cat > terraform.tfvars <<EOF
project_id         = "$PROJECT_ID"
billing_account    = "$BILLING_ACCOUNT"
tier               = "$TIER"
monthly_budget_usd = $BUDGET_USD
firestore_location = "$FIRESTORE_LOCATION"
connection_code    = "$CONNECTION_CODE"
EOF
```

Solo para T3:

```bash
printf 'enable_vertex = true\nenable_batch  = true\n' >> terraform.tfvars
```

```bash
terraform init
terraform plan -out=bootstrap.tfplan    # T1 con valores por defecto: 46 recursos por crear
terraform apply bootstrap.tfplan
terraform output -raw connection_payload; echo
terraform output next_steps
cd "$REPO"
```

- `terraform.tfvars` contiene su cuenta de facturación: no lo suba a ningún repositorio. Todas las opciones están en `examples/terraform.tfvars.example`.
- Se recomienda guardar el estado en un bucket aparte con versiones (README §6.1, paso 3), nunca en `gs://PROYECTO-ectwin`.
- Si aparece `SERVICE_DISABLED` justo después de habilitar las APIs, espere 60 s y repita `plan` y `apply`.

**Opción B: script** (lo más rápido para una sola persona). La vista previa no cambia nada y ejecuta las comprobaciones previas:

```bash
cd "$REPO"
scripts/bootstrap-tenant.sh --project "$PROJECT_ID" --dry-run
```

```bash
scripts/bootstrap-tenant.sh --project "$PROJECT_ID" --connection-code "$CONNECTION_CODE" \
  --tier "$TIER" --budget-usd "$BUDGET_USD" --firestore-location "$FIRESTORE_LOCATION"
echo "Código de salida: $?"
```

- En T3, añada `--enable-vertex --enable-batch`, y `--enable-managed-pipelines` si la plataforma debe desplegar sus trabajos.
- A la pregunta `Continuar? [y/N]`, responda `s`.
- El registro queda en `$HOME/ectwin-bootstrap-<proyecto>-<UTC>.log`.

| Código | Significado |
|---|---|
| 0 | Completo |
| 1 | Error sin cambios irreversibles: lea la línea `ERROR`, corrija la causa y repita |
| 2 | Error de uso: bandera o valor inválido |
| 3 | Completo con `ACTION NEEDED`: presupuesto no creado, permiso a la plataforma bloqueado por una política de organización o Firestore en modo Datastore |

## 6. Verifique el resultado

```bash
cd "$REPO"
scripts/verify-tenant.sh --project "$PROJECT_ID" --firestore-location "$FIRESTORE_LOCATION"
```

En T3, añada las mismas banderas del paso 5 (por ejemplo, `--enable-vertex --enable-batch`). La verificación solo lee. Cada línea muestra `[PASS]`, `[WARN]`, `[FAIL]` o `[INFO]` con una comprobación VT-01…VT-19. En un proyecto T1 nuevo el resumen típico es `Summary: 18 PASS, 1 WARN, 0 FAIL, 7 INFO`.

| Línea | Qué significa |
|---|---|
| `[INFO] VT-09 connection code label present on ectwin` | El código quedó guardado |
| `[INFO] VT-11 … not subscribed yet` | Normal hasta el paso 7 |
| `[WARN] VT-18 Earth Engine NOT registered` | Normal hasta el paso 7 |
| `[INFO] VT-19 domain-restricted sharing: …` | Informativo (paso 2) |
| `[FAIL] VT-08 broker binding missing` | La plataforma no podrá conectarse: revise el paso 2 o repita el paso 5 |
| `[FAIL]` o `[WARN] VT-16` | Falta el presupuesto o no se puede leer (paso 10) |
| `[WARN] VT-06 … extra` | `ectwin-runner` tiene roles de más: quítelos, porque la plataforma los hereda |

Códigos de salida: 0 sin ningún FAIL, 1 con al menos uno, 2 por error de uso. Para adjuntar el resultado a un ticket, use el comando siguiente. Con `--strict`, un WARN también devuelve 1, así que VT-18 lo hará hasta que registre Earth Engine.

```bash
scripts/verify-tenant.sh --project "$PROJECT_ID" --firestore-location "$FIRESTORE_LOCATION" --json --strict > verify.json
```

## 7. Pasos posteriores: Earth Engine, WeatherNext, Analytics Hub y claves

Nada de esto impide usar los productos nacionales (Commons). Registre Earth Engine y envíe el formulario de WeatherNext ahora, pero **no espere las aprobaciones**: haga el paso 8 antes de que venza el código (24 h).

**a) Earth Engine.** Paso de ≈3 min en el navegador, a cargo de un Owner o Editor:

```bash
echo "https://code.earthengine.google.com/register?project=$PROJECT_ID"
```

| Su caso | Registro |
|---|---|
| GAD, ministerio o COE con uso **operativo** | **Comercial**, plan Limited (solo uso: US$0,40 por EECU-hora las primeras 10 000 h). Según `docs/13` LP-07, el uso operativo gubernamental es comercial; confírmelo en cada caso |
| Universidad o grupo de investigación | No comercial: Contributor (1000 EECU-h/mes) o Partner (100 000, por solicitud) |
| Empresa (aseguradora, exportadora) | Comercial |

Después fije un tope diario en *IAM & Admin → Quotas & System Limits*, en `earthengine.googleapis.com/daily_eecu_usage_time`: 1 (T1), 5 (T2) o 25 (T3) EECU-h por día. La consola puede mostrar la unidad en segundos (por confirmar).

**b) WeatherNext** (T2 o superior; T1 no lo necesita). Quien se vaya a suscribir llena el *WeatherNext Data Request form* con una cuenta institucional de función y menciona este proyecto. El acceso es por cuenta de Google y tarda ≈5–7 días hábiles. Formulario (**por confirmar**): `https://docs.google.com/forms/d/e/1FAIpQLSeCf1JY8G78UDWzbm0ly9kJxfSjUIJT5WyMR_HiNqCm-IHIBg/viewform`. Contacto: `weathernext@google.com`. Registre el estado en el seguimiento de accesos de la app.

**c) Analytics Hub.** Suscríbase siempre en la ubicación `US` y con estos nombres exactos:

| Dataset vinculado | Disponible | Quién se suscribe |
|---|---|---|
| `ectwin_commons` | Desde el 2026-11-06 | Todos |
| `weathernext_3`, `weathernext_2` | Tras la aprobación de WeatherNext | La cuenta aprobada |

Los perfiles no comerciales pueden añadir `ectwin_commons_nc`. Con el script, suscríbase a Commons repitiendo las banderas del paso 5:

```bash
scripts/bootstrap-tenant.sh --project "$PROJECT_ID" --tier "$TIER" --budget-usd "$BUDGET_USD" \
  --firestore-location "$FIRESTORE_LOCATION" --subscribe-commons
```

Para WeatherNext (y para Commons si usa Terraform), use la consola: *BigQuery → Sharing (Analytics Hub)* → listado → *Subscribe*, con su proyecto y el nombre de la tabla. Luego dé acceso de lectura a `ectwin-runner`.

**Con Terraform**, liste solo los datasets que ya existan. Si la línea ya está en el archivo, edítela en vez de duplicarla.

```bash
cd "$REPO/infra/tenant-bootstrap"
echo 'linked_dataset_ids = ["ectwin_commons", "weathernext_3", "weathernext_2"]' >> terraform.tfvars
terraform apply && cd "$REPO"
```

**Con el script**, edite la lista de acceso de cada dataset:

```bash
bq show --format=prettyjson "$PROJECT_ID:weathernext_3" > /tmp/ds.json
nano /tmp/ds.json   # añada a "access": {"role":"READER","userByEmail":"ectwin-runner@<PROYECTO>.iam.gserviceaccount.com"}
bq update --source /tmp/ds.json "$PROJECT_ID:weathernext_3"
```

Después, VT-11 mostrará `present (linked=true, US); runner can read`.

**d) Claves propias** (opcional). Solo si usa su propia clave de TypeSafe o tiene acceso propio a la Flood Forecasting API. En ese segundo caso, ejecute el bootstrap con `--enable-flood-api` (o `enable_flood_forecasting_api = true`) y guarde la clave en `floodforecasting-api-key`. `ectwin-runner` puede leer ambos secretos, y por tanto también la plataforma cuando actúa en su nombre. Nunca pegue claves en un chat ni en un ticket.

```bash
read -rs KEY && printf %s "$KEY" | gcloud secrets versions add typesafe-api-key --data-file=- --project="$PROJECT_ID"
```

**e) Tope de BigQuery** (recomendado). En *IAM & Admin → Quotas & System Limits*, fije *Query usage per day* en 1 TiB (T1, T2, T4) o 2 TiB (T3).

## 8. Vuelva a la app y finalice la conexión

1. En *Proyecto y costos → Conectar proyecto*, pulse **Ya ejecuté el script** (*Conectar*). Si quiere, pegue el resumen de conexión, que no es secreto: la salida `connection_payload` o el JSON que imprimió el script.
2. La plataforma obtiene un token de ≤15 min para `ectwin-runner`, lee la etiqueta `ectwin-connection` y ejecuta las comprobaciones previas PF-01…PF-15. Cada una sale en verde, ámbar o rojo, con la solución en español. Si Earth Engine no está registrado, verá ámbar en T1 y rojo desde T2 (paso 7a). WeatherNext pendiente aparece en ámbar.
3. El espacio queda activo y usted queda como *Propietario/a*. Invite a una segunda persona como Propietario/a: las instituciones necesitan al menos dos. Las comprobaciones se repiten cada día a las 05:00 (hora de Ecuador).

## 9. Desconectar, revocar y exportar

**Desconectar** (lo recomendado): en *Proyecto y costos → Desconectar*. La app ofrece primero *Exportar todo*, le guía para quitar el permiso y borra el registro central en menos de 24 h.

**Quitar solo el permiso de la plataforma.** Sus pipelines siguen funcionando y, como máximo, sigue vigente un token ya emitido (≤15 min):

```bash
scripts/bootstrap-tenant.sh --project "$PROJECT_ID" --revoke-broker
```

El comando equivalente con gcloud es el siguiente. Con Terraform, agregue `platform_broker_sa = ""` a `terraform.tfvars` y ejecute `terraform apply`.

```bash
gcloud iam service-accounts remove-iam-policy-binding "ectwin-runner@$PROJECT_ID.iam.gserviceaccount.com" \
  --member="serviceAccount:ectwin-broker@ectwin-platform-prod.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" --project="$PROJECT_ID"
```

Compruebe el resultado: VT-08 debe mostrar `no broker binding (path D or revoked)`.

```bash
scripts/verify-tenant.sh --project "$PROJECT_ID" --no-broker
```

**Pausar todo**, incluidos sus propios pipelines (para revertirlo, use `enable`):

```bash
gcloud iam service-accounts disable "ectwin-runner@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID"
```

**Exportar.** Sus datos ya están en su proyecto. *Exportar todo* escribe en `gs://PROYECTO-ectwin/exports/<id>/` los datos de Firestore, las tablas de `ectwin` en Parquet, las áreas en GeoPackage y GeoJSON, los reportes, `LICENSES.txt` y un manifiesto con SHA-256. La plataforma nunca borra sus recursos. Antes de eliminar algo, conserve `ectwin.audit_events` y `ectwin.decision_log` según su política de retención.

## 10. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| Código 3 con «domain-restricted sharing blocked the broker grant», o error de política en `broker_token_creator` (Terraform) | Uso compartido restringido por dominio | C1: envíe la nota de excepción (README §9) y repita el paso 5. Alternativa: C2 (fase 2) |
| Código 3 con «budget NOT created» | Sin permisos de presupuesto | Pida a finanzas *Billing Account Costs Manager*, o cree el presupuesto en *Billing → Budgets & alerts* (este proyecto; 50/90/100 %; tema `ectwin-budget-alerts`). Luego repita el paso 6 |
| Código 1 con «billing is not enabled» | Proyecto sin facturación | Vincule una cuenta o solicite un proyecto T4 |
| Código 1 con «missing permissions on …» | Usted no es Owner | Pida a un Owner que lo ejecute |
| `SERVICE_DISABLED` o «has not been used in project» | Las APIs aún se están propagando | Espere 60 s y repita el paso 5 |
| Código 1 con «dataset … exists in …, expected US» | Un dataset anterior está en otra ubicación | Los datasets no se mueven. Si está vacío, bórrelo y repita. Si no, exporte, borre, repita y recargue |
| Error de `constraints/gcp.resourceLocations` | La organización restringe ubicaciones | Pida que se permitan `US`, `us-central1` y `southamerica-west1` |
| `ALREADY_EXISTS` en Firestore (Terraform), o código 3 «(default) is DATASTORE_MODE» | Ya existe una base `(default)` | Si es nativa: `create_firestore_database = false`. Si es Datastore y está vacía, cámbiela en la consola; si no, use un proyecto nuevo |
| Código 1 «could not enable APIs» que menciona `floodforecasting` | Acceso por lista de espera | Repita sin `--enable-flood-api` |
| Código 1 «--connection-code must be 8-63 chars of [a-z0-9_-]», o PF-02 en rojo | Código mal copiado, vencido (más de 24 h) o de otro intento | Pida un código nuevo y repita el paso 5 con él |
| 403 o `Access Denied` en `weathernext_3` | Sin aprobación, otra cuenta o el runner no tiene lectura | Suscríbase con la cuenta aprobada y complete el paso 7c |

Si el problema persiste, consulte `infra/tenant-bootstrap/README.md` §10 y adjunte `verify.json` a su solicitud de soporte.

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Su proyecto está listo para GDE-Niño. Complete el paso 8 en la app y cree su primera área de interés.
