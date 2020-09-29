FROM python:3.8.5-slim-buster
RUN pip install poetry
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    python3-dev \
    gcc \
    python3-psycopg2 \
    tzdata \
    gettext \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG POETRY_HTTP_BASIC_OLIST_USERNAME
ARG POETRY_HTTP_BASIC_OLIST_PASSWORD
ENV PYTHONUNBUFFERED 1
ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app
COPY pyproject.toml poetry.lock /app/
RUN poetry config virtualenvs.create false && poetry install --no-dev

ADD . /app/

EXPOSE 8000

ENTRYPOINT ["gunicorn","--bind","0.0.0.0:8000","-c","gunicorn_config.py","--chdir","roi","roi.wsgi:application","--graceful-timeout","30"]
