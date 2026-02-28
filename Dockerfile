# Stage 1: Build
FROM swift:6.0-jammy AS builder

WORKDIR /app
COPY Package.swift .
COPY VillageSimulation/ VillageSimulation/
COPY VillageServer/ VillageServer/

# Resolve dependencies
RUN swift package resolve

# Build only the server target (release mode)
RUN swift build --product VillageServer -c release

# Stage 2: Runtime
FROM swift:6.0-jammy-slim

WORKDIR /app

# Copy built binary
COPY --from=builder /app/.build/release/VillageServer /app/VillageServer

# Copy public directory for web viewer
COPY VillageServer/public/ /app/public/

# Create data directory
RUN mkdir -p /data

ENV DATA_DIR=/data
ENV PORT=8420

EXPOSE 8420

CMD ["/app/VillageServer"]
