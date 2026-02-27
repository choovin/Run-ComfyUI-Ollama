# Convex Backend Self-Hosted Integration for Mission Control

**Date**: 2026-02-27
**Commit**: d7d6d2e, 73d17a4
**Tag**: v20260227-llamacpp-opencode-openclaw-r30-llamacpp-opencode-1.2.15-manager-v0.9.04

## Overview

Integrated self-hosted Convex backend to enable Mission Control to run independently without relying on external Convex cloud services.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Container                         │
│  ┌─────────────────┐    ┌────────────────────────────────┐  │
│  │  llama.cpp      │    │  OpenCode Manager (5003)       │  │
│  │  (8080)         │    │  OpenCode Server (5551)        │  │
│  └─────────────────┘    └────────────────────────────────┘  │
│  ┌─────────────────┐    ┌────────────────────────────────┐  │
│  │  OpenClaw       │    │  Convex Backend (3210)         │  │
│  │  Gateway (18789)│    │  Convex Dashboard (6791)       │  │
│  └─────────────────┘    └────────────────────────────────┘  │
│          │                       │                          │
│          │                       ▼                          │
│          │           ┌────────────────────────────────┐     │
│          └──────────►│  Mission Control (3000)        │     │
│                      │  (Vite frontend + Convex SDK)  │     │
│                      └────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Changes Made

### 1. Dockerfile

- Added `CONVEX_BACKEND_VERSION` build arg
- Added Convex backend binary installation from GitHub releases
- Binary downloaded as .zip and extracted to `/opt/convex-backend`
- Updated EXPOSE ports to include: `3210 3211 6791`

### 2. start.sh

- Added Convex configuration variables:
  - `CONVEX_BACKEND_PORT` (default: 3210)
  - `CONVEX_SITE_PORT` (default: 3211)
  - `CONVEX_DASHBOARD_PORT` (default: 6791)
  - `CONVEX_DATA_DIR` (default: /data/convex)
  - `CONVEX_INSTANCE_NAME` (default: mission-control)
- Added Convex backend startup with health check
- Added Mission Control startup with self-hosted Convex URL
- Schema initialization via `npx convex dev --once`

### 3. docker-compose.yml

- Added Convex port mappings (3210, 3211, 6791)
- Added Convex environment variables section

## Convex Backend Release Format

Convex backend uses a non-standard versioning format:
- **Tag format**: `precompiled-YYYY-MM-DD-hash`
- **Example**: `precompiled-2026-02-26-5fdc3b8`
- **Asset format**: `convex-local-backend-{arch}-unknown-linux-gnu.zip`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONVEX_BACKEND_PORT` | 3210 | Convex API port |
| `CONVEX_SITE_PORT` | 3211 | Convex HTTP actions port |
| `CONVEX_DASHBOARD_PORT` | 6791 | Convex dashboard port |
| `CONVEX_DATA_DIR` | /data/convex | SQLite data directory |
| `CONVEX_INSTANCE_NAME` | mission-control | Instance identifier |
| `CONVEX_SELF_HOSTED_URL` | http://127.0.0.1:3210 | URL for Mission Control |
| `CONVEX_SELF_HOSTED_ADMIN_KEY` | (generated) | Admin key for schema push |

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 3210 | Convex Backend | API endpoint |
| 3211 | Convex Site | HTTP actions |
| 6791 | Convex Dashboard | Web UI |

## Verification

```bash
# Check Convex backend health
curl http://localhost:3210/version

# Check Mission Control
curl http://localhost:3000

# Check Convex dashboard
curl http://localhost:6791
```

## Troubleshooting

### Binary Download 404 Error

If the Convex binary download fails with 404:
1. Check available releases: `curl -s https://api.github.com/repos/get-convex/convex-backend/releases | jq '.[].tag_name'`
2. Update `CONVEX_BACKEND_VERSION` in Dockerfile
3. Rebuild image

### Mission Control Startup Issues

- Check if Convex backend is running: `curl http://127.0.0.1:3210/version`
- Check Mission Control logs for Convex connection errors
- Verify `CONVEX_SELF_HOSTED_URL` matches the Convex backend port

## Related Files

- `Dockerfile` - Lines 9, 109-125
- `start.sh` - Lines 49-54, 349, 461-571
- `docker-compose.yml` - Lines 9-11, 45-50, 134-141