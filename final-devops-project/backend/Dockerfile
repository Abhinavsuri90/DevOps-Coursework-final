# SpendWise API image. Build context: backend/
#   docker build -t spendwise-backend backend
FROM python:3.13-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv
COPY requirements.txt .
# Install dependencies, then remove pip (not needed at runtime; it bundles its own
# copies of urllib3/msgpack/setuptools that image scanners flag), and add a non-root user.
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip \
 && adduser -D -u 10001 spendwise

COPY alembic.ini entrypoint.sh ./
COPY alembic ./alembic
COPY app ./app

USER 10001
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
ENTRYPOINT ["./entrypoint.sh"]
