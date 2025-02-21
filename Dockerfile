ARG PYTHON_VERSION=3.12
ARG PYTHON_BASE_OS=alpine
ARG UV_BASE_OS=alpine

# Build stage
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-${UV_BASE_OS} AS uv

# Install the project into /app
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev --no-editable

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

# Final stage (alpine)
FROM python:${PYTHON_VERSION}-${PYTHON_BASE_OS} AS alpine

LABEL org.opencontainers.image.source=https://github.com/sparfenyuk/mcp-proxy
LABEL org.opencontainers.image.description="Connect to MCP servers that run on SSE transport, or expose stdio servers as an SSE server using the MCP Proxy server."
LABEL org.opencontainers.image.licenses=MIT

COPY --from=uv --chown=app:app /app/.venv /app/.venv

# Make uvx available for use
ENV UV_PYTHON_PREFERENCE=system
COPY --from=ghcr.io/astral-sh/uv:python3.12-alpine /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# Make npx available for use
RUN apk add --update --no-cache npm

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT ["mcp-proxy"]

# Final stage (debian)
FROM python:${PYTHON_VERSION}-${PYTHON_BASE_OS} AS debian

LABEL org.opencontainers.image.source=https://github.com/sparfenyuk/mcp-proxy
LABEL org.opencontainers.image.description="Connect to MCP servers that run on SSE transport, or expose stdio servers as an SSE server using the MCP Proxy server."
LABEL org.opencontainers.image.licenses=MIT

COPY --from=uv --chown=app:app /app/.venv /app/.venv

# Make uvx available for use
ENV UV_PYTHON_PREFERENCE=system
COPY --from=ghcr.io/astral-sh/uv:python3.12-alpine /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# Make npx available for use
RUN apt-get update && apt-get install -y npm && rm -rf /var/lib/apt/lists/*

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT ["mcp-proxy"]
