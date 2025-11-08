# Production Dockerfile for Liam
# Multi-stage build for optimal image size

# ==============================================================================
# Stage 1: Dependencies
# ==============================================================================
FROM node:20-alpine AS deps

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@10

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY frontend/package.json ./frontend/
COPY frontend/apps/app/package.json ./frontend/apps/app/
COPY frontend/apps/docs/package.json ./frontend/apps/docs/
COPY frontend/apps/mcp-server/package.json ./frontend/apps/mcp-server/
COPY frontend/internal-packages/*/package.json ./frontend/internal-packages/

# Install dependencies
RUN pnpm install --frozen-lockfile --prefer-offline

# ==============================================================================
# Stage 2: Builder
# ==============================================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@10

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/frontend/node_modules ./frontend/node_modules

# Copy source code
COPY . .

# Build application
RUN pnpm build --filter @liam-hq/app

# ==============================================================================
# Stage 3: Runner (Production)
# ==============================================================================
FROM node:20-alpine AS runner

WORKDIR /app

# Install pnpm and curl for health checks
RUN npm install -g pnpm@10 && \
    apk add --no-cache curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy necessary files
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./
COPY --from=builder --chown=nodejs:nodejs /app/pnpm-lock.yaml ./
COPY --from=builder --chown=nodejs:nodejs /app/pnpm-workspace.yaml ./
COPY --from=builder --chown=nodejs:nodejs /app/frontend ./frontend

# Install production dependencies only
RUN pnpm install --prod --frozen-lockfile

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3001
ENV HOSTNAME="0.0.0.0"

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/api/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

# Start application
CMD ["pnpm", "start", "--filter", "@liam-hq/app"]

# ==============================================================================
# Build Instructions
# ==============================================================================
# 
# Build the image:
#   docker build -t liam:latest .
# 
# Run the container:
#   docker run -d \
#     --name liam \
#     -p 3001:3001 \
#     -e POSTGRES_URL="postgresql://..." \
#     -e OPENAI_API_KEY="..." \
#     -e NEXT_PUBLIC_SUPABASE_URL="..." \
#     -e NEXT_PUBLIC_SUPABASE_ANON_KEY="..." \
#     liam:latest
# 
# Check health:
#   docker inspect --format='{{.State.Health.Status}}' liam
# 
# View logs:
#   docker logs -f liam
# 
# Stop container:
#   docker stop liam
# 
# Remove container:
#   docker rm liam

