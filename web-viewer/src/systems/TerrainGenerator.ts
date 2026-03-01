import { createNoise2D } from 'simplex-noise';
import { PATH_SEGMENTS, minPathDist } from '../config/pathNetwork';

interface RGB { r: number; g: number; b: number }

// Warm, golden color palette — matching the loading screen aesthetic
const C = {
  waterDeep:    { r: 42,  g: 82,  b: 115 },
  waterMed:     { r: 65,  g: 128, b: 155 },
  waterShallow: { r: 110, g: 172, b: 185 },
  // Lake colors — slightly bluer, more inviting than edge-water
  lakeDeep:     { r: 35,  g: 75,  b: 130 },
  lakeMed:      { r: 55,  g: 115, b: 165 },
  lakeShallow:  { r: 95,  g: 160, b: 190 },
  lakeSand:     { r: 210, g: 195, b: 155 },
  sand:         { r: 228, g: 205, b: 155 },
  grassLight:   { r: 168, g: 172, b: 65  },  // sun-baked golden meadow
  grassMed:     { r: 142, g: 148, b: 52  },  // warm olive-gold grass
  grassDark:    { r: 112, g: 122, b: 45  },  // warm olive dark grass
  forest:       { r: 68,  g: 95,  b: 42  },  // warm olive forest
  forestDark:   { r: 52,  g: 75,  b: 35  },  // warm deep forest
  dirt:         { r: 178, g: 148, b: 100 },  // golden brown paths
  dirtDark:     { r: 150, g: 118, b: 80  },  // darker golden path
  rocky:        { r: 142, g: 130, b: 108 },  // warm gray rocks
  // Mountain colors
  mtnRock:      { r: 125, g: 115, b: 100 },  // mountain rock base
  mtnRockDark:  { r: 95,  g: 88,  b: 78  },  // dark cliff face
  mtnSnow:      { r: 240, g: 245, b: 250 },  // snow cap
  mtnSnowShadow:{ r: 200, g: 215, b: 235 },  // snow in shadow
  village:      { r: 210, g: 190, b: 140 },  // warm golden village center
  flowerPink:   { r: 195, g: 120, b: 130 },  // warm pink
  flowerYellow: { r: 218, g: 200, b: 80  },  // warm golden yellow
  flowerPurple: { r: 148, g: 108, b: 165 },  // warm lavender
};

// House positions removed — now using PATH_SEGMENTS from pathNetwork.ts

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function lerp3(a: RGB, b: RGB, t: number): RGB {
  return {
    r: a.r + (b.r - a.r) * t,
    g: a.g + (b.g - a.g) * t,
    b: a.b + (b.b - a.b) * t,
  };
}

function clamp(v: number): number {
  return Math.max(0, Math.min(255, Math.round(v)));
}

// Predefined lake centers — carefully placed BETWEEN paths, never on them
// Path segments run: E-W main road (y≈0), N-S main road (x≈0),
// branches to houses at ±3200, cross-connections at y≈±1500/±2000
const LAKE_CENTERS = [
  // Between W3→W4 road and N3→N4, safe gap
  { x: -700,  y: -1100, radius: 250, depth: 0.55 },  // small forest pond
  // Between E2 and upper cross-connection, east side
  { x:  1700, y: -900,  radius: 300, depth: 0.6  },  // eastern lake
  // Southwest between W2 road and lower cross
  { x: -1800, y:  900,  radius: 350, depth: 0.65 },  // western lake
  // Southeast between E2/E3 and lower cross
  { x:  1600, y:  1000, radius: 280, depth: 0.5  },  // southeast pond
  // North between N2→N3 and upper cross, offset west
  { x: -500,  y: -2100, radius: 220, depth: 0.5  },  // northern tarn
  // South large — between S2→S3 and lower cross, east side
  { x:  500,  y:  1800, radius: 300, depth: 0.6  },  // southern lake
  // Far NE — between upper cross and NE house branch
  { x:  2600, y: -800,  radius: 200, depth: 0.45 },  // mountain pond NE
];

// Mountain peaks — in far areas between/beyond houses
const MOUNTAIN_PEAKS = [
  // NE beyond NE house
  { x:  2800, y: -2800, radius: 600, height: 1.1 },  // northeast mountains
  // NW beyond NW house
  { x: -2800, y: -2700, radius: 500, height: 0.9 },  // northwest peak
  // SW beyond SW house
  { x: -2600, y:  2700, radius: 550, height: 1.0 },  // southwest range
  // SE beyond SE house
  { x:  2700, y:  2600, radius: 450, height: 0.85 },  // southeast peak
  // Far north
  { x:  600,  y: -3200, radius: 400, height: 0.7 },  // northern hills
  // Far south
  { x: -500,  y:  3100, radius: 400, height: 0.75 },  // southern hills
];

export class TerrainGenerator {
  private elevNoise: (x: number, y: number) => number;
  private moistNoise: (x: number, y: number) => number;
  private detailNoise: (x: number, y: number) => number;
  private fineNoise: (x: number, y: number) => number;
  private lakeNoise: (x: number, y: number) => number;
  private mtnNoise: (x: number, y: number) => number;

  constructor(seed: number = 42) {
    this.elevNoise = createNoise2D(this.makeRng(seed));
    this.moistNoise = createNoise2D(this.makeRng(seed + 1000));
    this.detailNoise = createNoise2D(this.makeRng(seed + 2000));
    this.fineNoise = createNoise2D(this.makeRng(seed + 3000));
    this.lakeNoise = createNoise2D(this.makeRng(seed + 4000));
    this.mtnNoise = createNoise2D(this.makeRng(seed + 5000));
  }

  private makeRng(seed: number): () => number {
    let s = seed;
    return () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
  }

  private fbm(fn: (x: number, y: number) => number, x: number, y: number, octaves: number): number {
    let val = 0, amp = 1, freq = 1, max = 0;
    for (let i = 0; i < octaves; i++) {
      val += fn(x * freq, y * freq) * amp;
      max += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return val / max;
  }

  /** Lake depth at a world position — returns 0 if not in a lake, positive = deeper */
  getLakeDepth(wx: number, wy: number): number {
    let maxDepth = 0;
    for (const lake of LAKE_CENTERS) {
      const dx = wx - lake.x;
      const dy = wy - lake.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < lake.radius) {
        // Smooth falloff from center to edge
        const t = 1 - dist / lake.radius;
        const smooth = t * t * (3 - 2 * t); // smoothstep curve
        // Add noise for organic shoreline shape
        const noise = this.lakeNoise(wx * 0.003, wy * 0.003) * 0.25;
        const depth = (smooth + noise) * lake.depth;
        maxDepth = Math.max(maxDepth, depth);
      }
    }
    return maxDepth;
  }

  /** Mountain height at a world position — returns 0 if not on a mountain, positive = higher */
  getMountainHeight(wx: number, wy: number): number {
    let maxHeight = 0;
    for (const peak of MOUNTAIN_PEAKS) {
      const dx = wx - peak.x;
      const dy = wy - peak.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < peak.radius) {
        const t = 1 - dist / peak.radius;
        const smooth = t * t; // quadratic falloff — steeper peaks
        // Multi-octave ridgeline noise for jagged mountain shape
        const ridge = Math.abs(this.mtnNoise(wx * 0.0015, wy * 0.0015)) * 0.35;
        const detail = this.mtnNoise(wx * 0.004, wy * 0.004) * 0.15;
        const height = (smooth + ridge + detail) * peak.height;
        maxHeight = Math.max(maxHeight, height);
      }
    }
    return maxHeight;
  }

  /** True if position is inside a lake (respects roads — no lake on paths) */
  isLake(wx: number, wy: number): boolean {
    if (minPathDist(wx, wy) < 150) return false; // roads always win over lakes
    return this.getLakeDepth(wx, wy) > 0.08;
  }

  /** True if position is on a mountain (above tree line) */
  isMountain(wx: number, wy: number): boolean {
    return this.getMountainHeight(wx, wy) > 0.35;
  }

  /**
   * Get the terrain color at a world position.
   * Returns smooth, organic colors with no grid artifacts.
   */
  getColor(wx: number, wy: number): RGB {
    const dist = Math.sqrt(wx * wx + wy * wy);
    const roadDist = minPathDist(wx, wy);

    // Very low-frequency noise → large organic biome shapes
    // +0.42 bias so most of the map is land, water only at far edges/corners
    const rawElev = this.fbm(this.elevNoise, wx * 0.00028, wy * 0.00028, 4) + 0.42;
    // Roads and nearby areas force land — no water on or near paths
    const elev = (roadDist < 300) ? Math.max(rawElev, 0.05) : rawElev;
    const moist = this.fbm(this.moistNoise, wx * 0.00035 + 50, wy * 0.00035 + 50, 3);
    // Medium noise for intra-biome variation
    const det = this.detailNoise(wx * 0.0012, wy * 0.0012);
    // Fine noise for micro-variation (breaks up flat areas)
    const fine = this.fineNoise(wx * 0.005, wy * 0.005);
    const vfine = this.fineNoise(wx * 0.018 + 200, wy * 0.018 + 200);
    // Ultra-fine noise for grass "grain" texture visible at close zoom
    const grain = this.detailNoise(wx * 0.04 + 300, wy * 0.04 + 300);
    // Dappling — large light/shadow patches (sun through trees)
    const dapple = this.elevNoise(wx * 0.002 + 500, wy * 0.002 + 500);

    // ===== LAKES — override terrain in lake zones (roads always win) =====
    const lakeDepth = this.getLakeDepth(wx, wy);
    if (lakeDepth > 0.08 && roadDist > 150) {
      let color: RGB;
      if (lakeDepth > 0.45) {
        color = { ...C.lakeDeep };
        color.b = clamp(color.b + fine * 8);
      } else if (lakeDepth > 0.25) {
        color = lerp3(C.lakeMed, C.lakeDeep, smoothstep(0.25, 0.45, lakeDepth));
        color.b = clamp(color.b + fine * 6);
      } else if (lakeDepth > 0.15) {
        color = lerp3(C.lakeShallow, C.lakeMed, smoothstep(0.15, 0.25, lakeDepth));
      } else {
        // Shore transition — sand/grass to shallow water
        color = lerp3(C.lakeSand, C.lakeShallow, smoothstep(0.08, 0.15, lakeDepth));
      }
      // Subtle shimmer
      const shimmer = vfine * 6;
      return {
        r: clamp(color.r + shimmer * 0.3),
        g: clamp(color.g + shimmer * 0.5),
        b: clamp(color.b + shimmer),
      };
    }

    // ===== MOUNTAINS — override terrain on mountain peaks =====
    const mtnHeight = this.getMountainHeight(wx, wy);
    if (mtnHeight > 0.15) {
      let color: RGB;
      const mtnDetail = this.mtnNoise(wx * 0.006, wy * 0.006);
      if (mtnHeight > 0.85) {
        // Snow cap — bright white with blue shadow variation
        const shadowT = smoothstep(-0.2, 0.3, mtnDetail);
        color = lerp3(C.mtnSnowShadow, C.mtnSnow, shadowT);
      } else if (mtnHeight > 0.55) {
        // Upper rock + patchy snow
        const snowT = smoothstep(0.55, 0.85, mtnHeight);
        const rockBase = lerp3(C.mtnRockDark, C.mtnRock, mtnDetail * 0.5 + 0.5);
        const snowPatch = mtnDetail > 0.1 ? C.mtnSnow : C.mtnSnowShadow;
        color = lerp3(rockBase, snowPatch, snowT);
      } else if (mtnHeight > 0.35) {
        // Rocky mountain — dark exposed rock
        const rockT = smoothstep(-0.3, 0.3, mtnDetail);
        color = lerp3(C.mtnRockDark, C.mtnRock, rockT);
      } else {
        // Mountain base — transition from grass/forest to rock
        const baseT = smoothstep(0.15, 0.35, mtnHeight);
        const grassBase = moist > 0 ? C.grassDark : C.grassMed;
        color = lerp3(grassBase, C.mtnRock, baseT);
      }
      // Rock grain texture
      const rockGrain = grain * 4 + fine * 3;
      return {
        r: clamp(color.r + rockGrain),
        g: clamp(color.g + rockGrain * 0.8),
        b: clamp(color.b + rockGrain * 0.6),
      };
    }

    let color: RGB;

    // ===== BIOME BY ELEVATION — smooth gradients =====
    if (elev < -0.42) {
      color = { ...C.waterDeep };
      // Subtle wave shimmer
      color.b = clamp(color.b + fine * 10);
    } else if (elev < -0.32) {
      color = lerp3(C.waterDeep, C.waterMed, smoothstep(-0.42, -0.32, elev));
    } else if (elev < -0.22) {
      color = lerp3(C.waterMed, C.waterShallow, smoothstep(-0.32, -0.22, elev));
    } else if (elev < -0.12) {
      color = lerp3(C.waterShallow, C.sand, smoothstep(-0.22, -0.12, elev));
    } else if (elev < -0.02) {
      color = lerp3(C.sand, C.grassLight, smoothstep(-0.12, -0.02, elev));
    } else if (elev < 0.35) {
      // ===== GRASS ZONE — majority of the map =====
      // Moisture controls shade (darker = more moisture)
      const grassBase = moist > 0.25
        ? lerp3(C.grassMed, C.grassDark, smoothstep(0.25, 0.5, moist))
        : moist > -0.1
          ? lerp3(C.grassLight, C.grassMed, smoothstep(-0.1, 0.25, moist))
          : C.grassLight;
      color = { ...grassBase };

      // Subtle flower tinting in high-moisture areas
      if (moist > 0.45 && det > 0.3) {
        const flowerColor = det > 0.5 ? C.flowerPink : C.flowerPurple;
        color = lerp3(color, flowerColor, 0.18 * smoothstep(0.3, 0.6, det));
      } else if (moist > 0.3 && det > 0.45) {
        color = lerp3(color, C.flowerYellow, 0.15);
      }
    } else if (elev < 0.50) {
      // Transition to forest or rocky
      const t = smoothstep(0.35, 0.50, elev);
      const grassBase = moist > 0 ? C.grassDark : C.grassMed;
      const topBiome = moist > 0 ? C.forest : C.rocky;
      color = lerp3(grassBase, topBiome, t);
    } else {
      // High elevation — deep forest or rocky peaks
      if (moist > 0) {
        color = lerp3(C.forest, C.forestDark, smoothstep(0.5, 0.7, elev));
      } else {
        color = { ...C.rocky };
      }
    }

    // ===== VILLAGE CENTER (smooth circular blend — large warm golden area) =====
    if (dist < 800) {
      const t = smoothstep(800, 100, dist);
      color = lerp3(color, C.village, t * 0.88);
    }

    // ===== ROADS (wide defined paths with soft edges) =====
    if (roadDist < 160) {
      // Sharper inner road, softer outer transition
      const innerT = smoothstep(80, 12, roadDist);    // strong inner path
      const outerT = smoothstep(160, 65, roadDist);   // soft edge blend
      const t = Math.max(innerT * 0.90, outerT * 0.45);
      const roadColor = lerp3(C.dirt, C.dirtDark, grain * 0.5 + 0.5);
      color = lerp3(color, roadColor, t);
    }

    // ===== TEXTURE & VARIATION =====
    const isGrass = elev > -0.02 && elev < 0.35;
    const isWater = elev < -0.22;

    // Dappled light/shadow across terrain (large soft patches)
    const dappleEffect = dapple * 4;

    // Fine grain texture (visible at close zoom)
    const grainEffect = grain * 3;

    // Per-biome micro detail
    const micro = fine * 6 + vfine * 4 + dappleEffect + grainEffect;

    // Extra green variation in grass for natural "meadow" look
    const grassExtra = isGrass ? (fine * 6 + grain * 4) : 0;

    // Water gets blue shimmer instead of general micro
    const waterShimmer = isWater ? vfine * 8 : 0;

    // Golden warmth boost — shifts all land toward warm golden tone
    const warmR = isGrass ? 15 + fine * 6 : (elev > -0.12 ? 8 : 0);
    const warmB = isGrass ? -14 - fine * 4 : (elev > -0.12 ? -5 : 0);

    return {
      r: clamp(color.r + micro + warmR),
      g: clamp(color.g + micro + grassExtra),
      b: clamp(color.b + micro * 0.5 + waterShimmer + warmB),
    };
  }

  /** Raw elevation at world position (with +0.42 land bias). Water < -0.12, sand < -0.02, grass 0-0.35, forest > 0.35 */
  getElevation(wx: number, wy: number): number {
    return this.fbm(this.elevNoise, wx * 0.00028, wy * 0.00028, 4) + 0.42;
  }

  /** Effective elevation — includes lake depressions and mountain peaks */
  getEffectiveElevation(wx: number, wy: number): number {
    const base = this.getElevation(wx, wy);
    const lake = this.getLakeDepth(wx, wy);
    if (lake > 0.08) return -lake; // lakes go below zero
    const mtn = this.getMountainHeight(wx, wy);
    if (mtn > 0.15) return base + mtn; // mountains add height
    return base;
  }

  /** Raw moisture at world position. Higher = wetter */
  getMoisture(wx: number, wy: number): number {
    return this.fbm(this.moistNoise, wx * 0.00035 + 50, wy * 0.00035 + 50, 3);
  }

  /** True if position is water, sand, or near-shore — includes lakes */
  isWater(wx: number, wy: number): boolean {
    if (this.isLake(wx, wy)) return true;
    return this.getElevation(wx, wy) < 0.0;
  }

  /** Distance to nearest road segment in the path network */
  getRoadDist(wx: number, wy: number): number {
    return minPathDist(wx, wy);
  }
}
