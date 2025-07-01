# Dockerfile setup inspired by
# https://dev.to/farcellier/package-a-poetry-project-in-a-docker-container-for-production-3b4m

# NOTE: In order to be useful, the `$XDG_CACHE_HOME/tenzir-platform` directory
# (usually `~/.cache/tenzir-platform`) needs to be mapped to an external volume,
# to be able to persist the login information between runs.

FROM python:3.11-slim AS builder

RUN pip install poetry
RUN mkdir -p /app
COPY . /app

WORKDIR /app
RUN poetry config virtualenvs.in-project true --local
RUN poetry install --without dev

FROM python:3.11-slim AS base

COPY --from=builder /app /app

WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
ENTRYPOINT ["tenzir-platform"]
