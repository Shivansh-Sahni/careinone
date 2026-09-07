FROM python:3.13-slim
WORKDIR /app
COPY backend/requirements.lock /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && useradd --create-home --uid 10001 care
COPY backend/app.py backend/schema.py backend/providers.py backend/__init__.py /app/backend/
USER 10001
EXPOSE 8000
CMD ["uvicorn", "backend.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log", "--limit-concurrency", "16", "--timeout-keep-alive", "5"]
