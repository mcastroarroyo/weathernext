# Daily GDE-Niño run (Cloud Run Job): ECMWF ENS + GEOGloWS + Flood Hub -> BigQuery -> CHIRPS verification -> pages -> Cloud Storage
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libexpat1 && rm -rf /var/lib/apt/lists/*   # rasterio wheels need it
COPY pipeline/requirements.txt pipeline/
RUN pip install --no-cache-dir -r pipeline/requirements.txt google-cloud-storage
COPY . .
ENV PYTHONUNBUFFERED=1
CMD ["python", "daily.py"]
