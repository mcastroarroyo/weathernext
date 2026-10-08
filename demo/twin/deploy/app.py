"""GDE-Niño twin server: Google sign-in gate, access log in BigQuery and an admin page.

Env: OAUTH_CLIENT_ID (web client, External consent screen), SESSION_SECRET, ADMIN_EMAILS (comma list),
     EVENTS_TABLE (project.dataset.table for access events; optional),
     REPORTS_TABLE (security reports from /seguridad; defaults to security_reports next to EVENTS_TABLE),
     TWIN_BUCKET (optional: pages and data published daily by the Cloud Run Job under gs://TWIN_BUCKET/twin/; local files otherwise).
Public: /login, /auth, /healthz, /data/* (open GIS exports, CORS for ArcGIS), /seguridad and /.well-known/security.txt.
Everything else needs a session.
"""
import datetime as dt, html, json, mimetypes, os, re, secrets, threading, time, uuid
from flask import Flask, Response, abort, jsonify, redirect, request, session
from google.auth.transport import requests as greq
from google.oauth2 import id_token

ROOT = os.path.dirname(os.path.abspath(__file__))
CLIENT_ID = os.environ.get('OAUTH_CLIENT_ID', '')
ADMINS = {e.strip().lower() for e in os.environ.get('ADMIN_EMAILS', '').split(',') if e.strip()}
TABLE = os.environ.get('EVENTS_TABLE', '')
BUCKET = os.environ.get('TWIN_BUCKET', '')
REPORTS = os.environ.get('REPORTS_TABLE') or (TABLE.rsplit('.', 1)[0] + '.security_reports' if TABLE else '')
SECURITY_CONTACT = 'miguel@wursta.com'
mimetypes.add_type('application/geo+json', '.geojson')

app = Flask(__name__)
app.secret_key = os.environ.get('SESSION_SECRET') or os.urandom(32)
app.config.update(SESSION_COOKIE_SECURE=True, SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Lax',
                  PERMANENT_SESSION_LIFETIME=dt.timedelta(days=7))
_bq = None


def bq():
    global _bq
    if _bq is None and TABLE:
        from google.cloud import bigquery
        _bq = bigquery.Client()
    return _bq


# ---------------- published files (Cloud Storage, cached) ----------------
TTL = 300                                          # seconds: a new daily run shows up within 5 minutes
_files, _lock, _gcs = {}, threading.Lock(), None


def asset(rel):
    """Bytes of a published file: gs://TWIN_BUCKET/twin/<rel> when configured, else the copy baked into the image."""
    global _gcs
    if '..' in rel or rel.startswith('/'): return None
    hit = _files.get(rel)
    if hit and hit[0] > time.time(): return hit[1]
    data = None
    if BUCKET:
        try:
            if _gcs is None:
                from google.cloud import storage
                _gcs = storage.Client().bucket(BUCKET)
            data = _gcs.blob('twin/' + rel).download_as_bytes()
        except Exception as e:
            if hit: data = hit[1]                   # keep serving the last good copy
            elif 'NotFound' not in type(e).__name__: app.logger.warning('gcs %s: %s', rel, e)
    if data is None:
        path = os.path.join(ROOT, rel)
        if os.path.isfile(path): data = open(path, 'rb').read()
    if data is not None:
        with _lock: _files[rel] = (time.time() + TTL, data)
    return data


def send_asset(rel):
    data = asset(rel)
    if data is None: abort(404)
    return Response(data, mimetype=mimetypes.guess_type(rel)[0] or 'application/octet-stream')


# ---------------- access log ----------------
def client_info():
    ua = request.headers.get('User-Agent', '')
    device = 'móvil' if re.search(r'Mobile|Android|iPhone', ua) else 'tablet' if 'iPad' in ua else 'escritorio'
    browser = next((b for b, pat in (('Edge', 'Edg/'), ('Chrome', 'Chrome/'), ('Firefox', 'Firefox/'), ('Safari', 'Safari/')) if pat in ua), 'otro')
    ip = (request.headers.get('X-Forwarded-For', request.remote_addr or '').split(',')[0]).strip()
    return {'ip': ip, 'user_agent': ua[:400], 'device': device, 'browser': browser}


def log(event, page=None, detail=None, user=None):
    if not TABLE: return
    u = user or session
    row = {'ts': dt.datetime.now(dt.timezone.utc).isoformat(), 'event': event, 'email': u.get('email'), 'name': u.get('name'),
           'domain': (u.get('email') or '@').split('@')[-1] or None, 'sid': u.get('sid'), 'path': request.path, 'page': page,
           'referrer': (request.referrer or '')[:300] or None, 'detail': json.dumps(detail, ensure_ascii=False) if detail else None, **client_info()}
    try:
        errors = bq().insert_rows_json(TABLE, [row])
        if errors: app.logger.warning('access log insert errors: %s', errors)
    except Exception as e:                       # never block the user because logging failed
        app.logger.warning('access log failed: %s', e)


# ---------------- gate ----------------
PUBLIC = ('/login', '/auth', '/healthz', '/data/', '/favicon.ico', '/privacidad', '/terminos', '/seguridad', '/.well-known/security.txt', '/security.txt')


@app.before_request
def gate():
    if request.path.startswith(PUBLIC): return None
    if not session.get('email'):
        if request.path.startswith('/api/'): abort(401)
        return redirect('/login?next=' + request.full_path.rstrip('?'))


@app.after_request
def headers(resp):
    resp.headers.setdefault('X-Content-Type-Options', 'nosniff')
    resp.headers.setdefault('Referrer-Policy', 'strict-origin-when-cross-origin')
    if request.path.startswith('/data/'):
        resp.headers['Access-Control-Allow-Origin'] = '*'; resp.headers['Cache-Control'] = 'no-cache'
    elif resp.mimetype == 'text/html':
        resp.headers['Cache-Control'] = 'no-store'
    return resp


@app.get('/healthz')
def healthz(): return 'ok'


# ---------------- sign-in ----------------
LOGIN = '''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Iniciar sesión · Gemelo Digital Ecuador</title><meta name="robots" content="noindex">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..125,600..800&family=Source+Sans+3:wght@400;600&display=swap">
<style>
:root{--bg:#eef2f1;--card:#fff;--ink:#10201f;--muted:#566866;--line:#d3dcda;--accent:#0a6c87;--warm:#c2453a}
@media (prefers-color-scheme:dark){:root{--bg:#0d1514;--card:#142120;--ink:#e4eeec;--muted:#93a8a5;--line:#2a3b39;--accent:#4fb3cf;--warm:#ef7a6b}}
body{margin:0;min-height:100vh;display:grid;place-items:center;background:var(--bg);color:var(--ink);font:15px/1.5 "Source Sans 3",system-ui,sans-serif;padding:16px;box-sizing:border-box}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;max-width:440px;width:100%;padding:28px;display:grid;gap:14px}
h1{font:800 28px/1.1 Archivo,"Arial Narrow",sans-serif;font-stretch:85%;margin:0}h1 span{color:var(--accent)}
.label{font:600 11px/1.2 "Source Sans 3",sans-serif;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.note{font-size:12.5px;color:var(--muted)}.err{color:var(--warm);font-weight:600}
</style></head><body><main class="card">
<div class="label">Gemelo digital · decisión probabilística</div>
<h1>Gemelo Digital Ecuador <span>· El Niño 2026–27</span></h1>
<p>Inicie sesión con cualquier cuenta de Google para entrar.</p>__ERR__
<script src="https://accounts.google.com/gsi/client" async></script>
<div id="g_id_onload" data-client_id="__CLIENT__" data-login_uri="__LOGIN_URI__" data-ux_mode="redirect" data-auto_prompt="false" data-state="__NEXT__"></div>
<div class="g_id_signin" data-type="standard" data-size="large" data-theme="outline" data-text="signin_with" data-shape="rectangular" data-locale="es"></div>
<p class="note"><a href="/privacidad">Aviso de privacidad</a> · <a href="/terminos">Condiciones de uso</a> · <a href="/seguridad">Seguridad</a></p>
<p class="note">Registramos su correo, nombre, fecha y hora de acceso y su uso de la aplicación (páginas, tiempo de sesión, dispositivo y dirección IP) para control de acceso y seguridad. Herramienta experimental de apoyo a la decisión: no es información oficial y no reemplaza los avisos de la SNGR ni del INAMHI.</p>
</main></body></html>'''


@app.get('/login')
def login():
    nxt = request.args.get('next', '/')
    if not nxt.startswith('/') or nxt.startswith('//'): nxt = '/'
    err = '<p class="err">No se pudo verificar su cuenta. Intente de nuevo.</p>' if request.args.get('e') else ''
    page = LOGIN.replace('__CLIENT__', html.escape(CLIENT_ID)).replace('__LOGIN_URI__', html.escape(request.url_root.replace('http://', 'https://') + 'auth')) \
                .replace('__NEXT__', html.escape(nxt)).replace('__ERR__', err)
    return Response(page, mimetype='text/html')


DOC = """<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__T__ · Gemelo Digital Ecuador</title>
<style>body{margin:0;background:#eef2f1;color:#10201f;font:16px/1.6 system-ui,sans-serif;padding:16px}main{max-width:760px;margin:0 auto;background:#fff;border:1px solid #d3dcda;border-radius:10px;padding:28px}
h1{font-size:26px;margin:0 0 4px}h2{font-size:17px;margin:22px 0 6px}.note{color:#566866;font-size:13px}a{color:#0a6c87}
@media (prefers-color-scheme:dark){body{background:#0d1514;color:#e4eeec}main{background:#142120;border-color:#2a3b39}.note{color:#93a8a5}a{color:#4fb3cf}}</style></head>
<body><main><p class="note"><a href="/login">← Gemelo Digital Ecuador – El Niño</a> · Borrador pendiente de revisión jurídica · octubre 2026</p><h1>__T__</h1>__B__</main></body></html>"""

PRIV = """<p>Este aviso explica qué datos personales trata el <b>Gemelo Digital Ecuador – El Niño</b> (GDE-Niño), herramienta experimental de apoyo a la decisión operada por Wursta.</p>
<h2>Qué datos recogemos</h2><p>Al iniciar sesión con Google recibimos su <b>nombre, correo electrónico y foto de perfil</b> (alcances openid, email y profile). No accedemos a su correo, archivos ni contactos. Durante el uso registramos la fecha y hora de ingreso y salida, las páginas visitadas, el tiempo con la página activa, las descargas de datos, la dirección IP y el tipo de navegador y dispositivo.</p>
<h2>Para qué los usamos</h2><p>Para controlar el acceso, proteger el servicio, entender cómo se usa y mejorarlo. No vendemos ni compartimos sus datos con terceros con fines comerciales y no los usamos para publicidad.</p>
<h2>Dónde se guardan y por cuánto tiempo</h2><p>En Google Cloud (BigQuery, región de Estados Unidos), con acceso restringido al administrador del servicio. Se conservan mientras dure el piloto y como máximo 12 meses, salvo que la ley exija otro plazo. Si envía un reporte de seguridad, guardamos su contenido, el contacto que decida dejar y su dirección IP, solo para atenderlo.</p>
<h2>Encargados</h2><p>Google Cloud (infraestructura e inicio de sesión). El desarrollo y mantenimiento de la aplicación se realiza con asistencia de inteligencia artificial (Claude Code, de Anthropic), sin enviarle los registros de acceso.</p>
<h2>Sus derechos</h2><p>Puede solicitar acceso, rectificación, eliminación u oposición al tratamiento de sus datos, conforme a la Ley Orgánica de Protección de Datos Personales del Ecuador, escribiendo a <b>miguel@wursta.com</b>. También puede revocar el acceso desde su cuenta de Google en myaccount.google.com/permissions.</p>"""

TERMS = """<p><b>Herramienta experimental de apoyo a la decisión.</b> Los pronósticos, probabilidades, niveles de riesgo e indicadores se generan automáticamente con modelos y datos de terceros. No son alertas ni información oficial y no reemplazan los avisos de la Secretaría Nacional de Gestión de Riesgos (SNGR), del INAMHI ni de otras autoridades. Ante una emergencia, siga las instrucciones oficiales y llame al ECU 911.</p>
<h2>Sin garantía</h2><p>La información se ofrece «tal cual», puede contener errores, omisiones o retrasos y puede no reflejar las condiciones reales. No se garantiza su exactitud, integridad ni disponibilidad.</p>
<h2>Limitación de responsabilidad</h2><p>En la máxima medida permitida por la ley, Wursta, sus socios y proveedores de datos no son responsables por decisiones, acciones u omisiones basadas en esta herramienta. Toda decisión que afecte a personas, bienes o servicios públicos debe ser validada por personal técnico competente de la institución responsable.</p>
<h2>Desarrollo asistido por inteligencia artificial</h2><p>Esta aplicación fue construida y es mantenida con asistencia de inteligencia artificial (Claude Code, de Anthropic) en un entorno controlado de Google Cloud, bajo supervisión humana. Puede contener errores propios de herramientas automatizadas.</p>
<h2>Datos de terceros</h2><p>ECMWF Open Data y GEOGloWS (CC BY 4.0), Google Flood Hub (CC BY 4.0), límites INEC 2024 vía OCHA COD-AB (CC BY-IGO) y Red Vial Estatal del Ministerio de Infraestructura y Tecnología (MIT), usada con fines de demostración. Algunos indicadores son estimaciones de demostración y se identifican como tales.</p>
<h2>Uso aceptable</h2><p>No presente esta información como oficial ni la difunda como alerta; cite las fuentes y respete sus licencias. Contacto: miguel@wursta.com.</p>"""


@app.get('/privacidad')
def privacidad(): return Response(DOC.replace('__T__', 'Aviso de privacidad').replace('__B__', PRIV), mimetype='text/html')


@app.get('/terminos')
def terminos(): return Response(DOC.replace('__T__', 'Condiciones de uso').replace('__B__', TERMS), mimetype='text/html')


# ---------------- security: policy, reports, security.txt ----------------
SEC = """<p>Si encuentra una vulnerabilidad, un problema de privacidad o un error que pueda afectar a los usuarios o a los datos, repórtelo aquí. Respondemos en un plazo de <b>5 días hábiles</b> y le informamos cuando esté corregido.</p>
<h2>Cómo reportar</h2><p>Use el formulario o escriba a <b>__CONTACT__</b>. Incluya los pasos para reproducirlo y su posible impacto. No incluya datos personales de terceros.</p>
<h2>Investigación de buena fe</h2><p>Agradecemos la investigación responsable. Le pedimos no acceder ni modificar datos de otros usuarios, no degradar el servicio (sin pruebas de carga ni denegación de servicio), no usar ingeniería social y darnos un plazo razonable antes de publicar.</p>
<h2>Actualizaciones de seguridad</h2><p>Las dependencias se revisan automáticamente cada semana y el sitio se escanea de forma pasiva. Las correcciones se aplican sin interrumpir el servicio; los cambios relevantes se informan en esta página.</p>"""
FORM = """<h2>Formulario de reporte</h2><form method="post" action="/seguridad" style="display:grid;gap:10px">
<input type="hidden" name="t" value="__TOKEN__"><input name="website" tabindex="-1" autocomplete="off" style="position:absolute;left:-9999px" aria-hidden="true">
<label>Tipo<br><select name="kind" style="width:100%;padding:8px"><option value="vulnerabilidad">Vulnerabilidad de seguridad</option><option value="privacidad">Privacidad o datos personales</option><option value="datos">Error en los datos o pronósticos</option><option value="otro">Otro</option></select></label>
<label>Descripción (pasos, impacto)<br><textarea name="detail" required maxlength="5000" rows="7" style="width:100%;padding:8px;box-sizing:border-box"></textarea></label>
<label>Página o URL afectada (opcional)<br><input name="where" maxlength="300" style="width:100%;padding:8px;box-sizing:border-box"></label>
<label>Contacto para responderle (opcional)<br><input name="contact" type="email" maxlength="200" value="__EMAIL__" style="width:100%;padding:8px;box-sizing:border-box"></label>
<button style="padding:10px;font-weight:600;cursor:pointer">Enviar reporte</button></form>"""
_recent = {}


@app.get('/seguridad')
def seguridad():
    tok = secrets.token_urlsafe(16)
    body = SEC.replace('__CONTACT__', SECURITY_CONTACT) + FORM.replace('__TOKEN__', tok).replace('__EMAIL__', html.escape(session.get('email', '')))
    resp = Response(DOC.replace('__T__', 'Seguridad y reporte de vulnerabilidades').replace('__B__', body), mimetype='text/html')
    resp.set_cookie('sec_t', tok, secure=True, httponly=True, samesite='Strict', max_age=3600)
    return resp


@app.post('/seguridad')
def seguridad_report():
    f, ip = request.form, client_info()['ip']
    if f.get('website') or not f.get('t') or f.get('t') != request.cookies.get('sec_t'): abort(400)     # bot field or cross-site post
    now = time.time(); hits = [t for t in _recent.get(ip, []) if now - t < 3600]
    if len(hits) >= 5: return Response('Demasiados reportes desde esta dirección; intente más tarde.', 429)
    _recent[ip] = hits + [now]
    rid = uuid.uuid4().hex[:8].upper()
    row = {'ts': dt.datetime.now(dt.timezone.utc).isoformat(), 'report_id': rid, 'kind': (f.get('kind') or 'otro')[:20],
           'detail': (f.get('detail') or '')[:5000], 'location': (f.get('where') or '')[:300] or None, 'contact': (f.get('contact') or '')[:200] or None,
           'email': session.get('email'), 'ip': ip, 'user_agent': client_info()['user_agent'], 'status': 'nuevo'}
    if not row['detail'].strip(): abort(400)
    app.logger.warning('SECURITY_REPORT %s kind=%s', rid, row['kind'])          # Cloud Monitoring alert -> admin e-mail
    try:
        if REPORTS and bq(): bq().insert_rows_json(REPORTS, [row])
    except Exception as e:
        app.logger.error('security report %s not stored: %s', rid, e)
    log('security_report', page='seguridad', detail={'id': rid, 'kind': row['kind']}, user=session if session.get('email') else {})
    msg = f'<p><b>Gracias. Recibimos su reporte.</b> Código de seguimiento: <b>{rid}</b>. Le responderemos en un plazo de 5 días hábiles si dejó un contacto.</p><p><a href="/">Volver</a></p>'
    return Response(DOC.replace('__T__', 'Reporte recibido').replace('__B__', msg), mimetype='text/html')


@app.get('/.well-known/security.txt')
@app.get('/security.txt')
def security_txt():
    root = request.url_root.replace('http://', 'https://')
    exp = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=180)).strftime('%Y-%m-%dT00:00:00Z')
    return Response(f'Contact: mailto:{SECURITY_CONTACT}\nContact: {root}seguridad\nExpires: {exp}\nPreferred-Languages: es, en\n'
                    f'Policy: {root}seguridad\nCanonical: {root}.well-known/security.txt\n', mimetype='text/plain')


@app.post('/auth')
def auth():
    # Google Identity Services double-submit CSRF check
    if not request.form.get('g_csrf_token') or request.form.get('g_csrf_token') != request.cookies.get('g_csrf_token'):
        return redirect('/login?e=csrf')
    try:
        info = id_token.verify_oauth2_token(request.form.get('credential', ''), greq.Request(), CLIENT_ID)
    except Exception:
        log('login_failed', user={})
        return redirect('/login?e=token')
    if not info.get('email_verified'):
        return redirect('/login?e=unverified')
    session.clear(); session.permanent = True
    session.update(email=info['email'].lower(), name=info.get('name') or info['email'], picture=info.get('picture'),
                   sid=uuid.uuid4().hex, login_at=dt.datetime.now(dt.timezone.utc).isoformat())
    log('login', detail={'hd': info.get('hd')})
    nxt = request.form.get('state') or '/'
    return redirect(nxt if nxt.startswith('/') and not nxt.startswith('//') else '/')


@app.get('/logout')
def logout():
    log('logout'); session.clear()
    return redirect('/login')


# ---------------- pages ----------------
def userbar():
    admin = ' · <a href="/admin">Admin</a>' if session.get('email') in ADMINS else ''
    return ('<div id="userbar" style="position:fixed;right:12px;bottom:12px;z-index:50;background:var(--surface,#fff);border:1px solid var(--line,#ccc);'
            'border-radius:999px;padding:6px 12px;font:13px \'Source Sans 3\',system-ui,sans-serif;box-shadow:0 2px 10px rgb(0 0 0/.12)">'
            f'{html.escape(session.get("email", ""))} · <a href="/verificacion">Verificación</a> · <a href="/">Gemelo</a>{admin} · <a href="/logout">Salir</a></div>'
            '<script>(function(){const p=location.pathname;function ping(){if(document.visibilityState==="visible")fetch("/api/ping",{method:"POST",'
            'headers:{"Content-Type":"application/json"},body:JSON.stringify({page:p})}).catch(()=>{})}setInterval(ping,60000)})();</script>')


def serve_page(fname, page):
    log('page_view', page=page)
    body = (asset(fname) or b'').decode('utf-8').replace('</body>', userbar() + '</body>', 1)
    return Response(body, mimetype='text/html')


@app.get('/')
def twin(): return serve_page('index.html', 'gemelo')


@app.get('/verificacion')
def verificacion(): return serve_page('verificacion.html', 'verificacion')


@app.get('/verificacion/data/<path:f>')
def verif_data(f): return send_asset('verificacion/data/' + f)


@app.get('/data/<path:f>')
def gis_data(f):
    if not f.endswith(('manifest.json',)): log('download', page='datos-sig', detail={'file': f})
    return send_asset('data/' + f)


@app.post('/api/ping')
def ping():
    log('heartbeat', page=(request.get_json(silent=True) or {}).get('page'))
    return jsonify(ok=True)


# ---------------- admin ----------------
def q(sql):
    from google.cloud import bigquery
    return [dict(r) for r in bq().query(sql, job_config=bigquery.QueryJobConfig(maximum_bytes_billed=200_000_000)).result()]


def esc(v):
    if v is None: return '—'
    if isinstance(v, dt.datetime): return v.astimezone(dt.timezone(dt.timedelta(hours=-5))).strftime('%d %b %Y %H:%M')
    return html.escape(str(v))


@app.get('/admin')
def admin():
    if session.get('email') not in ADMINS:
        log('admin_denied'); abort(403)
    log('page_view', page='admin')
    T = f'`{TABLE}`'
    kp = q(f'''SELECT COUNT(DISTINCT email) users, COUNT(DISTINCT IF(event='login' AND ts > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY), email, NULL)) users_7d,
      COUNT(DISTINCT IF(ts > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE), email, NULL)) active_now,
      COUNTIF(event='login' AND DATE(ts, 'America/Guayaquil') = CURRENT_DATE('America/Guayaquil')) logins_today,
      COUNTIF(event='heartbeat') active_minutes, COUNTIF(event='download') downloads, COUNTIF(event='admin_denied') denied,
      COUNT(DISTINCT domain) domains FROM {T}''')[0]
    users = q(f'''WITH e AS (SELECT * FROM {T} WHERE email IS NOT NULL),
      s AS (SELECT email, sid, MIN(ts) s0, MAX(ts) s1 FROM e WHERE sid IS NOT NULL GROUP BY 1, 2),
      ls AS (SELECT email, ARRAY_AGG(TIMESTAMP_DIFF(s1, s0, MINUTE) ORDER BY s1 DESC LIMIT 1)[OFFSET(0)] last_session_min FROM s GROUP BY email),
      u AS (SELECT email, ANY_VALUE(name) name, ANY_VALUE(domain) domain, MIN(IF(event='login', ts, NULL)) first_login, MAX(IF(event='login', ts, NULL)) last_login,
        MAX(ts) last_seen, COUNT(DISTINCT IF(event='login', sid, NULL)) sessions, COUNTIF(event='heartbeat') active_min,
        COUNTIF(event='page_view' AND page='gemelo') v_twin, COUNTIF(event='page_view' AND page='verificacion') v_verif, COUNTIF(event='download') downloads,
        ARRAY_AGG(STRUCT(device, browser, ip) ORDER BY ts DESC LIMIT 1)[OFFSET(0)] last_client
        FROM e GROUP BY email)
      SELECT u.*, ls.last_session_min FROM u LEFT JOIN ls USING (email) ORDER BY last_seen DESC LIMIT 500''')
    daily = q(f'''SELECT DATE(ts, 'America/Guayaquil') d, COUNT(DISTINCT email) users, COUNTIF(event='login') logins FROM {T}
      WHERE ts > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) GROUP BY 1 ORDER BY 1''')
    doms = q(f'SELECT domain, COUNT(DISTINCT email) users FROM {T} WHERE domain IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10')
    recent = q(f'SELECT ts, event, email, page, device, browser, ip, detail FROM {T} WHERE event != "heartbeat" ORDER BY ts DESC LIMIT 60')
    try: reports = q(f'SELECT ts, report_id, kind, location, contact, email, ip, detail FROM `{REPORTS}` ORDER BY ts DESC LIMIT 20') if REPORTS else []
    except Exception: reports = []

    mx = max([r['users'] for r in daily] or [1])
    bars = ''.join(f'<div title="{esc(r["d"])}: {r["users"]} usuarios, {r["logins"]} ingresos" style="flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:3px">'
                   f'<span class="n">{r["users"]}</span><span style="width:70%;background:var(--accent);border-radius:3px 3px 0 0;height:{max(4, 120 * r["users"] / mx):.0f}px"></span>'
                   f'<span class="n">{r["d"].strftime("%d/%m")}</span></div>' for r in daily) or '<p class="note">Aún sin datos.</p>'
    kpis = [('Usuarios', kp['users'], 'desde el inicio'), ('Activos ahora', kp['active_now'], 'últimos 5 min'), ('Ingresos hoy', kp['logins_today'], 'hora de Ecuador'),
            ('Usuarios 7 días', kp['users_7d'], 'con ingreso'), ('Horas de uso', f'{kp["active_minutes"] / 60:.1f}', 'tiempo activo total'),
            ('Descargas SIG', kp['downloads'], 'archivos ArcGIS'), ('Organizaciones', kp['domains'], 'dominios de correo'), ('Accesos denegados', kp['denied'], 'intentos a /admin')]
    rows = ''.join(f'<tr><td><b>{esc(u["name"])}</b><br><span class="note">{esc(u["email"])}</span></td><td>{esc(u["domain"])}</td><td>{esc(u["first_login"])}</td>'
                   f'<td>{esc(u["last_login"])}</td><td>{esc(u["last_seen"])}</td><td class="r">{u["sessions"]}</td><td class="r">{u["active_min"]} min</td>'
                   f'<td class="r">{esc(u["last_session_min"])} min</td><td class="r">{u["v_twin"]} · {u["v_verif"]}</td><td class="r">{u["downloads"]}</td>'
                   f'<td>{esc((u["last_client"] or {}).get("device"))} · {esc((u["last_client"] or {}).get("browser"))}<br><span class="note">{esc((u["last_client"] or {}).get("ip"))}</span></td></tr>' for u in users)
    ev = ''.join(f'<tr><td>{esc(r["ts"])}</td><td>{esc(r["event"])}</td><td>{esc(r["email"])}</td><td>{esc(r["page"])}</td><td>{esc(r["device"])} · {esc(r["browser"])}</td><td>{esc(r["ip"])}</td><td class="note">{esc(r["detail"])}</td></tr>' for r in recent)
    dm = ''.join(f'<li><span>{esc(d["domain"])}</span><span class="num">{d["users"]}</span></li>' for d in doms)
    page = f'''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Admin · Gemelo Digital Ecuador</title>
<meta name="robots" content="noindex"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..125,600..800&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono&display=swap">
<style>:root{{--bg:#eef2f1;--surface:#fff;--s2:#f6f8f7;--ink:#10201f;--muted:#566866;--line:#d3dcda;--accent:#0a6c87}}
@media (prefers-color-scheme:dark){{:root{{--bg:#0d1514;--surface:#142120;--s2:#1a2928;--ink:#e4eeec;--muted:#93a8a5;--line:#2a3b39;--accent:#4fb3cf}}}}
body{{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 "Source Sans 3",system-ui,sans-serif;padding:16px}}.wrap{{max-width:1400px;margin:0 auto;display:grid;gap:12px}}
h1{{font:800 30px/1.1 Archivo,sans-serif;font-stretch:85%;margin:0}}h2{{font:700 18px Archivo,sans-serif;font-stretch:85%;margin:0 0 8px}}
.card{{background:var(--surface);border:1px solid var(--line);border-radius:8px;padding:14px;min-width:0}}.kpis{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:8px}}
.kpi{{background:var(--s2);border-radius:6px;padding:10px}}.kpi b{{display:block;font:700 26px Archivo,sans-serif;font-stretch:85%}}.label,.kpi span{{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}}
.note{{color:var(--muted);font-size:12px}}.scroll{{overflow-x:auto}}table{{border-collapse:collapse;width:100%;font-size:13px}}th{{text-align:left;font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);padding:6px;border-bottom:1px solid var(--line);white-space:nowrap}}
td{{padding:6px;border-bottom:1px solid var(--line);vertical-align:top}}.r{{text-align:right;font-family:"JetBrains Mono",monospace;font-variant-numeric:tabular-nums;white-space:nowrap}}
.n{{font:11px "JetBrains Mono",monospace;color:var(--muted)}}.two{{display:grid;grid-template-columns:2fr 1fr;gap:12px}}@media(max-width:900px){{.two{{grid-template-columns:1fr}}}}
ul{{list-style:none;margin:0;padding:0;display:grid;gap:4px}}li{{display:flex;justify-content:space-between}}a{{color:var(--accent)}}</style></head><body><div class="wrap">
<div style="display:flex;justify-content:space-between;align-items:end;flex-wrap:wrap;gap:8px"><div><div class="label">Gemelo Digital Ecuador · administración</div><h1>Accesos y uso</h1></div>
<div class="note">{esc(session.get("email"))} · <a href="/">Gemelo</a> · <a href="/verificacion">Verificación</a> · <a href="/logout">Salir</a></div></div>
<div class="card"><div class="kpis">{''.join(f'<div class="kpi"><span>{l}</span><b>{v}</b><span style="text-transform:none;letter-spacing:0">{s}</span></div>' for l, v, s in kpis)}</div></div>
<div class="two"><div class="card"><h2>Usuarios por día · 30 días</h2><div style="display:flex;gap:4px;align-items:flex-end;height:170px">{bars}</div></div>
<div class="card"><h2>Organizaciones</h2><ul>{dm or '<li class="note">Aún sin datos.</li>'}</ul></div></div>
<div class="card"><h2>Usuarios</h2><div class="scroll"><table><tr><th>Usuario</th><th>Dominio</th><th>Primer ingreso</th><th>Último ingreso</th><th>Última actividad</th><th>Sesiones</th><th>Tiempo activo</th><th>Última sesión</th><th>Vistas gemelo · verif.</th><th>Descargas</th><th>Dispositivo · IP</th></tr>{rows}</table></div>
<p class="note">Horas en hora de Ecuador (UTC−5). Tiempo activo = minutos con la página visible.</p></div>
<div class="card"><h2>Reportes de seguridad</h2>{'<div class="scroll"><table><tr><th>Fecha</th><th>Código</th><th>Tipo</th><th>Lugar</th><th>Contacto</th><th>IP</th><th>Descripción</th></tr>' + ''.join(f'<tr><td>{esc(r["ts"])}</td><td><b>{esc(r["report_id"])}</b></td><td>{esc(r["kind"])}</td><td>{esc(r["location"])}</td><td>{esc(r["contact"] or r["email"])}</td><td>{esc(r["ip"])}</td><td class="note" style="max-width:480px;white-space:pre-wrap">{esc(r["detail"])}</td></tr>' for r in reports) + '</table></div>' if reports else '<p class="note">Sin reportes. Formulario público en <a href="/seguridad">/seguridad</a>.</p>'}</div>
<div class="card"><h2>Actividad reciente</h2><div class="scroll"><table><tr><th>Fecha</th><th>Evento</th><th>Usuario</th><th>Página</th><th>Dispositivo</th><th>IP</th><th>Detalle</th></tr>{ev}</table></div></div>
</div></body></html>'''
    return Response(page, mimetype='text/html')


@app.errorhandler(403)
def forbidden(_): return Response('<p style="font:16px system-ui;padding:24px">Acceso restringido. <a href="/">Volver al gemelo</a></p>', 403, mimetype='text/html')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
