# NOTE: In order to be useful, the `$XDG_CACHE_HOME/tenzir-platform` directory
# (usually `~/.cache/tenzir-platform`) needs to be mapped to an external volume,
# to be able to persist the login information between runs.

FROM python:3.11-slim AS builder

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN mkdir -p /app
COPY . /app

WORKDIR /app
RUN uv sync --frozen --no-dev --no-group types

FROM python:3.11-slim AS base

COPY --from=builder /app /app

WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
ENTRYPOINT ["tenzir-platform"]
