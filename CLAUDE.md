# CLAUDE.md — Claude Village

## Project
Claude Village — animated AI village simulator with autonomous agents.
macOS native app (SpriteKit + SwiftUI) + headless server (SwiftNIO HTTP+WS) + web viewer.

## Stack
- Swift 6 + SpriteKit + SwiftUI + SwiftNIO
- SPM (3 targets): VillageSimulation (library), ClaudeVillage (macOS app), VillageServer (headless server)
- `#if os(macOS)` conditional compilation — Linux Docker builds skip macOS app target

## Build & Run
```bash
swift build --product ClaudeVillage    # macOS app
swift build --product VillageServer    # headless server
cp .build/debug/ClaudeVillage ClaudeVillage.app/Contents/MacOS/ClaudeVillage
open ClaudeVillage.app                 # launch app
.build/debug/VillageServer             # server on port 8420
```

## Architecture
```
Sources/
├── VillageSimulation/           # Pure Swift library (Linux-compatible)
│   ├── SimulationLoop.swift     # Core: agents, needs, moods, buildings, food, conversations
│   ├── SimulationSnapshot.swift # Serializable state for API/WS
│   └── Types.swift              # Shared types
├── ClaudeVillage/               # macOS app (SpriteKit scenes, SwiftUI chrome)
│   ├── AI/ App/ Data/ Nodes/ Scene/ UI/ Util/
│   └── Resources/               # voices/, logos/, AppIcon.icns
└── VillageServer/               # Headless HTTP+WS server
    ├── VillageServerApp.swift   # SwiftNIO routes + WebSocket
    ├── TTSCache.swift           # ElevenLabs MP3 caching
    └── public/                  # Web viewer (HTML/CSS/JS + Canvas)
```

## API Endpoints
- `GET /api/snapshot` — current village state
- `GET /api/requests` — pending agent requests
- `POST /api/food` — drop food at coordinates
- `POST /api/requests/:id/approve` — approve agent request
- `POST /api/requests/:id/deny` — deny agent request
- `POST /api/presence` — update user presence
- `POST /api/connect` — connect user session
- `WS /ws` — real-time WebSocket updates

## Deploy
- Railway URL: https://easygoing-vitality-production-2c44.up.railway.app
- Railway project: `0c5173f6-7e96-49a4-a684-39953391e81d`
- GitHub: `alonr-create/claude-village`
- Docker: Dockerfile builds VillageServer for Linux
- Auto-deploy on push to main

## Known Issues / Patterns
- `didMove(to:)` called twice — guard with `didSetup` flag
- `SKCropNode` — child position must be `.zero`
- Mouse drag vs click — separate mouseDown/mouseDragged/mouseUp with `isDragging` flag
- `main.swift` incompatible with `@main` — rename to avoid top-level code
- TTS: `speechHash` computed server-side (fnv1a), sent in snapshot, client uses directly
- OffscreenCanvas caching for static elements in web viewer — massive perf gain

## Features
- Autonomous agents (needs/moods/goals/decisions)
- Building system (11 structure types)
- Turkish food system
- Agent conversations (AI-generated)
- Request system (approve/deny via web)
- Day/night cycle, speech bubbles
- ElevenLabs TTS (104 MP3 files: George/Jessica/Brian/Bella, eleven_v3)
- Presence system (Eyal auto-manages when Alon away 30s+)
- Auto-launch on login via LaunchAgent `com.alon.claude-village`

## Colors
Web viewer uses CSS variables — dark theme with earthy/village tones.

## Rules
- Swift 6 with `.v5` language mode
- Never commit voice MP3 files to git (use .gitignore)
- Resources go in `ClaudeVillage/Resources/`
- 6 logo variants in `Resources/logos/`
