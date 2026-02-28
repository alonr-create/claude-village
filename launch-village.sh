#!/bin/bash
# Claude Village — Auto-launch on login
# Opens the village web viewer in Chrome app mode (no address bar)

sleep 5  # wait for network

VILLAGE_URL="https://easygoing-vitality-production-2c44.up.railway.app"

open -a "Google Chrome" --args \
  --app="$VILLAGE_URL" \
  --window-size=500,400 \
  --window-position=1100,25
