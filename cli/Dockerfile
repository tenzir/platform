# NOTE: In order to be useful, the `$XDG_CACHE_HOME/tenzir-platform` directory
# (usually `~/.cache/tenzir-platform`) needs to be mapped to an external volume,
# to be able to persist the login information between runs.

FROM python:3.13-slim AS builder

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN mkdir -p /app
COPY . /app

WORKDIR /app
# Compile to bytecode at build time. Besides speeding up startup, this keeps the
# CLI's output clean: docopt 0.6.2 uses unescaped regex literals, and since
# Python 3.12 those raise a visible SyntaxWarning rather than a hidden
# DeprecationWarning. Precompiling emits the warning here, during the build,
# instead of on every single invocation.
RUN uv sync --frozen --no-dev --no-group types --compile-bytecode

FROM python:3.13-slim AS base

COPY --from=builder /app /app

WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
ENTRYPOINT ["tenzir-platform"]
