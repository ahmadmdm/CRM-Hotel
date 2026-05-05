FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY pyproject.toml README.md ./
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir .[dev]

COPY . .

CMD ["celery", "-A", "app.infrastructure.queue.celery_app.celery_app", "worker", "--beat", "--loglevel=info"]
