# ─── Stage 1: Dependencies ────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy only package files to leverage Docker layer caching
COPY package.json package-lock.json* ./

# Install production dependencies only
RUN npm ci --only=production && \
    # Remove npm cache to reduce image size
    npm cache clean --force


# ─── Stage 2: Builder / Test ──────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./

# Install all deps (including devDependencies for testing/linting)
RUN npm ci

COPY src/ ./src/
COPY tests/ ./tests/
COPY .eslintrc.json ./

# Lint the code — CI will fail here if there are lint errors
RUN npm run lint

# Run tests — CI will fail here if tests don't pass
RUN npm test


# ─── Stage 3: Production Image ────────────────────────────────────────────────
FROM node:20-alpine AS production

# Security: add a non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy production node_modules from deps stage
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy application source
COPY --chown=appuser:appgroup src/ ./src/
COPY --chown=appuser:appgroup package.json ./

# Security: use non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Health check for container runtime
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Metadata labels
LABEL org.opencontainers.image.title="devops-takehome" \
      org.opencontainers.image.description="TWIN Senior Platform Engineer Take-Home App" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.licenses="MIT"

# Start the server
CMD ["node", "src/server.js"]
