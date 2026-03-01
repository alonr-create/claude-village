# Stage 0: Build web viewer (Phaser.js)
FROM node:20-slim AS web-builder
WORKDIR /app/web-viewer
COPY web-viewer/package.json web-viewer/package-lock.json ./
RUN npm ci
COPY web-viewer/ ./
# Copy source pixel art assets into Vite's public/ dir (gitignored but needed for build)
RUN cp -r assets/ public/assets/
RUN npm run build

# Stage 1: Build Swift server
FROM swift:6.0-jammy AS builder

WORKDIR /app

# Copy Package manifest
COPY Package.swift Package.resolved ./

# Copy source directories needed for server build
COPY VillageSimulation/ VillageSimulation/
COPY VillageServer/ VillageServer/

# Copy web-built files into public/ (overwrite index.html, add assets/)
COPY --from=web-builder /app/VillageServer/public/index.html VillageServer/public/index.html
COPY --from=web-builder /app/VillageServer/public/assets/ VillageServer/public/assets/

# Resolve dependencies
RUN swift package resolve

# Build only the server target (release mode)
RUN swift build --product VillageServer -c release

# Stage 2: Runtime
FROM swift:6.0-jammy-slim

WORKDIR /app

# Copy built binary
COPY --from=builder /app/.build/release/VillageServer /app/VillageServer

# Copy public directory for web viewer (includes icons, audio, and Vite build)
COPY --from=builder /app/VillageServer/public/ /app/public/

# Create data directory
RUN mkdir -p /data

ENV DATA_DIR=/data
ENV PORT=8420

EXPOSE 8420

CMD ["/app/VillageServer"]
