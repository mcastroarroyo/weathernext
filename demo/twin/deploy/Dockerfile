FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py index.html verificacion.html ./
COPY data/ ./data/
COPY verificacion/ ./verificacion/
ENV PYTHONUNBUFFERED=1
CMD exec gunicorn --bind :$PORT --workers 2 --threads 8 --timeout 60 app:app
