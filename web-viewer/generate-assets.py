#!/usr/bin/env python3
"""Generate pixel art assets for Claude Village v4.0 using Gemini AI"""

import json, os, sys, time, base64

# Get API key from MCP settings
settings_path = os.path.expanduser("~/.claude/settings.json")
with open(settings_path) as f:
    settings = json.load(f)
API_KEY = settings["mcpServers"]["nanobanana"]["env"]["GEMINI_API_KEY"]

from google import genai
from google.genai import types

client = genai.Client(api_key=API_KEY)
MODEL = "gemini-3.1-flash-image-preview"  # NB2 image generation model

ASSETS_DIR = os.path.dirname(os.path.abspath(__file__)) + "/assets"
os.makedirs(ASSETS_DIR + "/sprites", exist_ok=True)
os.makedirs(ASSETS_DIR + "/tilesets", exist_ok=True)
os.makedirs(ASSETS_DIR + "/ui", exist_ok=True)

def generate_and_save(prompt: str, output_path: str, retries: int = 3):
    """Generate image with Gemini and save to file"""
    for attempt in range(retries):
        try:
            print(f"  Generating: {os.path.basename(output_path)} (attempt {attempt+1})...")
            response = client.models.generate_content(
                model=MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE", "TEXT"]
                )
            )
            # Extract image from response
            for part in response.candidates[0].content.parts:
                if part.inline_data and part.inline_data.mime_type.startswith("image/"):
                    img_data = part.inline_data.data
                    with open(output_path, "wb") as f:
                        f.write(img_data)
                    size_kb = len(img_data) / 1024
                    print(f"  ✓ Saved {os.path.basename(output_path)} ({size_kb:.0f}KB)")
                    return True
            print(f"  ✗ No image in response")
        except Exception as e:
            print(f"  ✗ Error: {e}")
            if attempt < retries - 1:
                time.sleep(4)
    return False

# ===== ASSET GENERATION =====

print("\n=== Claude Village v4.0 — Pixel Art Asset Generation ===\n")

# 1. VILLAGE GROUND (top-down view)
print("[1/5] Village Ground Background")
generate_and_save(
    """Create a pixel art top-down view of a village ground/terrain for a game.
    Style: 16-bit retro pixel art, top-down orthographic view.
    Size: Square image, detailed.
    Content:
    - Green grass covering most of the area with slight color variations
    - A cross-shaped dirt path going through the center (horizontal + vertical)
    - Two diagonal paths crossing at the center
    - A circular stone fountain at the very center with blue water
    - 12 trees scattered around the edges (dark green circle canopies on brown trunks)
    - Small flower patches and grass tufts for decoration
    Color palette: Forest greens (#2a4a2a, #3a5a3a, #1e4619), brown paths (#a0825a),
    blue water (#3c8cc8), stone gray (#646464).
    The image should tile nicely and feel like a cozy village clearing.
    NO text, NO labels, NO UI elements. Just the terrain.
    Transparent background is NOT needed - use green grass as background.""",
    ASSETS_DIR + "/tilesets/village-ground.png"
)
time.sleep(4)

# 2. CRAB SPRITE SHEET
print("\n[2/5] Crab Sprite Sheet")
generate_and_save(
    """Create a pixel art sprite sheet of a cute cartoon crab character for a 2D game.
    Style: 16-bit pixel art, side view, cute/chibi style.
    Layout: 4 columns x 4 rows grid, each cell is exactly the same size.

    Row 1 (Idle animation, 4 frames): The crab standing still with gentle body bobbing.
    Small oval body, 6 thin legs (3 per side), 2 claws, 2 eye stalks with round eyes.

    Row 2 (Walk animation, 4 frames): The crab walking to the right.
    Legs moving in alternating patterns, body bouncing slightly.

    Row 3 (Eat animation, 4 frames): The crab eating - claws moving toward mouth area.

    Row 4 (Sleep animation, 2 frames + 2 empty): Eyes closed, small Zzz above head.
    Last 2 cells should be empty/transparent.

    The crab should be GRAY/WHITE colored (neutral) so it can be tinted different colors in-game.
    Each frame should have a transparent background.
    Consistent size and position across all frames.
    The crab should be small and cute, roughly 40x40 pixels within each cell.
    NO text, NO labels.""",
    ASSETS_DIR + "/sprites/crab-sheet.png"
)
time.sleep(4)

# 3. HOUSES (6 different colored houses)
print("\n[3/5] House Sprites")
generate_and_save(
    """Create a pixel art sprite sheet of 6 different small village houses in a single image.
    Style: 16-bit pixel art, 3/4 view (slightly from above), cozy village style.
    Layout: 3 columns x 2 rows, each house in its own cell.

    Each house should have: walls, a triangular roof, a door, 2 small windows, and a chimney.
    The houses differ ONLY in their roof and wall colors:

    Row 1:
    1. Gold roof (#D4AF37) + dark purple walls (#1C0B2E) — compass icon above
    2. Blue roof (#1A6FC4) + dark blue walls (#0d2248) — palm tree icon above
    3. Purple roof (#8B5CF6) + dark walls (#0A0E1A) — computer icon above

    Row 2:
    4. Red roof (#DD3333) + dark red walls (#4a0e0e) — megaphone icon above
    5. Green roof (#10B981) + gray walls (#2a2a2a) — sunrise icon above
    6. Amber roof (#F59E0B) + brown walls (#3a2a1a) — gamepad icon above

    Each house should be roughly the same size (about 80x80 pixels within its cell).
    Transparent background for each cell.
    Cute, cozy village style with warm lighting feel.
    NO text, NO labels.""",
    ASSETS_DIR + "/sprites/houses-sheet.png"
)
time.sleep(4)

# 4. FOOD SPRITES (11 Turkish foods)
print("\n[4/5] Turkish Food Sprites")
generate_and_save(
    """Create a pixel art sprite sheet of 11 Turkish food items for a game.
    Style: 16-bit pixel art, front/top view, appetizing and colorful.
    Layout: 4 columns x 3 rows (last cell empty).

    Each food item should be roughly 32x32 pixels within its cell:
    Row 1: Döner kebab (meat on vertical spit), Iskender (meat on bread with sauce),
            Manti (small dumplings), Lahmacun (thin flatbread with meat)
    Row 2: Shish kebab (meat on skewer), Kofta (meatballs),
            Pide (boat-shaped bread), Pilaf (rice on plate)
    Row 3: Baklava (layered pastry), Çay/Tea (traditional Turkish tea glass),
            Turkish coffee (small cup with foam), (empty cell)

    Each food should look delicious and recognizable at small size.
    Warm, appetizing colors. Transparent background.
    NO text, NO labels.""",
    ASSETS_DIR + "/sprites/food-sheet.png"
)
time.sleep(4)

# 5. UI PANEL BACKGROUND
print("\n[5/5] UI Panel Background")
generate_and_save(
    """Create a pixel art UI panel background for a game interface.
    Style: Dark, semi-transparent, fantasy/RPG game UI style.
    Content: A single rectangular panel with:
    - Dark background (#141e14) with slight transparency
    - Subtle border with a thin golden/warm line
    - Rounded corners
    - Slight inner glow or gradient
    - Glass/frosted effect feel

    Size: roughly 300x200 pixels.
    This will be used as a nine-slice panel background.
    Dark forest green theme matching a village game.
    NO text, NO labels, NO icons.""",
    ASSETS_DIR + "/ui/panel-bg.png"
)

print("\n=== Asset generation complete! ===")
print(f"Assets saved to: {ASSETS_DIR}/")

# List generated files
for root, dirs, files in os.walk(ASSETS_DIR):
    for f in sorted(files):
        path = os.path.join(root, f)
        size = os.path.getsize(path)
        rel = os.path.relpath(path, ASSETS_DIR)
        print(f"  {rel}: {size/1024:.0f}KB")
