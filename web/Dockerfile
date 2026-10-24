FROM node:22-slim AS documents
WORKDIR /build/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --omit=dev --omit=optional --ignore-scripts --no-audit --no-fund
COPY web/scripts/vendor.mjs ./scripts/vendor.mjs
RUN node scripts/vendor.mjs

FROM python:3.13-slim
WORKDIR /app
COPY backend/requirements.lock /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt && useradd --create-home --uid 10001 care
COPY backend/__init__.py backend/schema.py backend/providers.py backend/verify_gateway.py backend/app.py /app/backend/
COPY backend/public/privacy.html backend/public/support.html /app/backend/public/
COPY web/__init__.py web/server.py web/combined.py /app/web/
COPY --from=documents /build/web/public/vendor /app/web/public/vendor
COPY --from=documents /build/web/public/vendor-notices.txt /app/web/public/vendor-notices.txt
COPY --from=documents /build/web/public/vendor-manifest.json /app/web/public/vendor-manifest.json
COPY web/public/index.html web/public/app.js web/public/core.js web/public/storage.js web/public/imports.js web/public/recorder.js web/public/insights.js web/public/style.css web/public/icon.svg /app/web/public/
USER 10001
EXPOSE 10000
CMD ["sh", "-c", "exec uvicorn web.combined:create_app --factory --host 0.0.0.0 --port ${PORT:-10000} --no-access-log --limit-concurrency 32 --timeout-keep-alive 5"]
