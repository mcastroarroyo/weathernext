"""Daily run (Cloud Run Job): pipeline -> BigQuery -> verification -> pages and GIS exports -> Cloud Storage.

The web service reads the published files from gs://$TWIN_BUCKET/twin/ (cached a few minutes), so no rebuild or redeploy is needed.
Env: GCP_PROJECT_ID, TWIN_BUCKET, FLOOD_API_KEY (from Secret Manager; optional).
"""
import json, mimetypes, os, pathlib, subprocess, sys
from google.cloud import storage

HERE = pathlib.Path(__file__).parent
PROJECT, BUCKET, PREFIX = os.environ['GCP_PROJECT_ID'], os.environ['TWIN_BUCKET'], 'twin/'
OUT = HERE / 'pipeline' / 'out'
mimetypes.add_type('application/geo+json', '.geojson')


def run(*args):
    print('$', ' '.join(args), flush=True)
    subprocess.run([sys.executable, *args], cwd=HERE, check=True)


def main():
    bucket = storage.Client(project=PROJECT).bucket(BUCKET)
    # previous forecast: fallback for river gauges if the GEOGloWS API is down
    old = sorted(bucket.list_blobs(prefix=PREFIX + 'archive/'), key=lambda b: b.name)
    OUT.mkdir(parents=True, exist_ok=True)
    if old: old[-1].download_to_filename(OUT / 'prev_forecast.json')
    run('pipeline/pipeline.py', '--crop', '--bq', PROJECT)

    # verification: runs already verified for all 15 days are reused from yesterday's file
    prev = OUT / 'prev_verification.json'
    blob = bucket.blob(PREFIX + 'verification.json')
    if blob.exists(): blob.download_to_filename(prev)
    run('pipeline/verify.py', '--project', PROJECT, '--reuse', str(prev))
    run('build_page.py')

    # publish: data first, pages last, then remove exports that no longer exist
    files = {f'data/{p.name}': p for p in (HERE / 'deploy' / 'data').iterdir() if p.is_file()}
    files |= {f'verificacion/data/{p.name}': p for p in (HERE / 'deploy' / 'verificacion' / 'data').glob('*.json')}
    files['verification.json'] = OUT / 'verification.json'
    init = json.loads((OUT / 'forecast.json').read_text())['init']
    files[f'archive/forecast-{init[:13].replace("T", "_")}Z.json'] = OUT / 'forecast.json'
    files['verificacion.html'] = HERE / 'deploy' / 'verificacion.html'
    files['index.html'] = HERE / 'deploy' / 'index.html'
    for name, path in files.items():
        b = bucket.blob(PREFIX + name); b.cache_control = 'no-cache'
        b.upload_from_filename(path, content_type=mimetypes.guess_type(name)[0] or 'application/octet-stream')
    for b in bucket.list_blobs(prefix=PREFIX + 'data/'):
        if b.name[len(PREFIX):] not in files: b.delete()
    print(f'published {len(files)} files to gs://{BUCKET}/{PREFIX} (forecast {init})')


if __name__ == '__main__':
    main()
