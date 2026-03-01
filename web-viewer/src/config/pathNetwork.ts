/**
 * Village path network — Stardew Valley-style organic curves.
 * Roads gently meander 50-150 units off the ideal line for a hand-built feel.
 * Shared by TerrainGenerator (road rendering) and VillageScene (decoration exclusion).
 */

export interface PathSegment {
  ax: number; ay: number;
  bx: number; by: number;
}

// House positions (used by TerrainGenerator and VillageScene)
export const HOUSE_POSITIONS = [
  { x: -3200, y: -1800 }, // NW — דקל לפרישה
  { x: -3200, y: 1800 },  // SW — מצפן לעושר
  { x: 3200, y: -1800 },  // NE — עליזה המפרסמת
  { x: 3200, y: 1800 },   // SE — Alon.dev
  { x: 0, y: -3200 },     // N  — אפליקציות ומשחקים
  { x: 0, y: 2800 },      // S  — הודעת בוקר
];

// All road segments — organic curves (58 segments)
export const PATH_SEGMENTS: PathSegment[] = [
  // === VILLAGE RING (irregular octagon, ~350 radius) ===
  { ax: -350, ay: -20, bx: -250, by: -270 },   // RW → RNW
  { ax: -250, ay: -270, bx: 20, by: -340 },     // RNW → RN
  { ax: 20, ay: -340, bx: 280, by: -250 },      // RN → RNE
  { ax: 280, ay: -250, bx: 350, by: 30 },       // RNE → RE
  { ax: 350, ay: 30, bx: 240, by: 310 },        // RE → RSE
  { ax: 240, ay: 310, bx: -30, by: 340 },       // RSE → RS
  { ax: -30, ay: 340, bx: -270, by: 260 },      // RS → RSW
  { ax: -270, ay: 260, bx: -350, by: -20 },     // RSW → RW

  // === MAIN E-W ROAD — west half (gentle S-curve) ===
  { ax: -4000, ay: 50, bx: -3200, by: -30 },    // Far west → W1 junction
  { ax: -3200, ay: -30, bx: -2200, by: 80 },    // W1 → W2
  { ax: -2200, ay: 80, bx: -1400, by: -50 },    // W2 → W3
  { ax: -1400, ay: -50, bx: -600, by: 70 },     // W3 → W4
  { ax: -600, ay: 70, bx: -350, by: -20 },      // W4 → RW (enter ring)

  // === MAIN E-W ROAD — east half ===
  { ax: 350, ay: 30, bx: 600, by: -60 },        // RE → E1 (exit ring)
  { ax: 600, ay: -60, bx: 1400, by: 50 },       // E1 → E2
  { ax: 1400, ay: 50, bx: 2200, by: -80 },      // E2 → E3
  { ax: 2200, ay: -80, bx: 3200, by: 30 },      // E3 → E4 junction
  { ax: 3200, ay: 30, bx: 4000, by: -50 },      // E4 → Far east

  // === MAIN N-S ROAD — north half (winding) ===
  { ax: 50, ay: -3800, bx: -30, by: -3200 },    // Far north → N1 (near N house)
  { ax: -30, ay: -3200, bx: 70, by: -2400 },    // N1 → N2
  { ax: 70, ay: -2400, bx: -50, by: -1600 },    // N2 → N3
  { ax: -50, ay: -1600, bx: 40, by: -800 },     // N3 → N4
  { ax: 40, ay: -800, bx: 20, by: -340 },       // N4 → RN (enter ring)

  // === MAIN N-S ROAD — south half ===
  { ax: -30, ay: 340, bx: -40, by: 800 },       // RS → S1 (exit ring)
  { ax: -40, ay: 800, bx: 50, by: 1600 },       // S1 → S2
  { ax: 50, ay: 1600, bx: -50, by: 2200 },      // S2 → S3
  { ax: -50, ay: 2200, bx: 30, by: 2800 },      // S3 → S4 (near S house)
  { ax: 30, ay: 2800, bx: -20, by: 3400 },      // S4 → Far south

  // === BRANCH ROADS TO HOUSES ===
  // NW branch: W1 junction → NW house
  { ax: -3200, ay: -30, bx: -3260, by: -600 },
  { ax: -3260, ay: -600, bx: -3140, by: -1200 },
  { ax: -3140, ay: -1200, bx: -3200, by: -1800 },

  // SW branch: W1 junction → SW house
  { ax: -3200, ay: -30, bx: -3140, by: 600 },
  { ax: -3140, ay: 600, bx: -3260, by: 1200 },
  { ax: -3260, ay: 1200, bx: -3200, by: 1800 },

  // NE branch: E4 junction → NE house
  { ax: 3200, ay: 30, bx: 3260, by: -600 },
  { ax: 3260, ay: -600, bx: 3140, by: -1200 },
  { ax: 3140, ay: -1200, bx: 3200, by: -1800 },

  // SE branch: E4 junction → SE house
  { ax: 3200, ay: 30, bx: 3140, by: 600 },
  { ax: 3140, ay: 600, bx: 3260, by: 1200 },
  { ax: 3260, ay: 1200, bx: 3200, by: 1800 },

  // N house connector
  { ax: -30, ay: -3200, bx: 0, by: -3200 },

  // S house connector
  { ax: 30, ay: 2800, bx: 0, by: 2800 },

  // === CROSS-CONNECTIONS (countryside paths) ===
  // Upper cross: NW area ↔ N-S road ↔ NE area
  { ax: -3140, ay: -1200, bx: -2100, by: -1500 },
  { ax: -2100, ay: -1500, bx: -1000, by: -2000 },
  { ax: -1000, ay: -2000, bx: 70, by: -2400 },
  { ax: 70, ay: -2400, bx: 1000, by: -2000 },
  { ax: 1000, ay: -2000, bx: 2100, by: -1500 },
  { ax: 2100, ay: -1500, bx: 3140, by: -1200 },

  // Lower cross: SW area ↔ N-S road ↔ SE area
  { ax: -3260, ay: 1200, bx: -2100, by: 1500 },
  { ax: -2100, ay: 1500, bx: -1000, by: 2000 },
  { ax: -1000, ay: 2000, bx: -50, by: 2200 },
  { ax: -50, ay: 2200, bx: 1000, by: 2000 },
  { ax: 1000, ay: 2000, bx: 2100, by: 1500 },
  { ax: 2100, ay: 1500, bx: 3260, by: 1200 },

  // === DEAD-END CHARM PATHS ===
  { ax: -250, ay: -270, bx: -450, by: -480 },   // Garden (off RNW)
  { ax: -2200, ay: 80, bx: -2350, by: 280 },    // Old well (off W2)
  { ax: 70, ay: -2400, bx: 280, by: -2550 },    // Lookout (off N2)
  { ax: 240, ay: 310, bx: 430, by: 490 },       // Bench (off RSE)
];

// Waypoint nodes (all junction points) — used for pathfinding
export const PATH_WAYPOINTS: { x: number; y: number }[] = [
  // Village ring (8)
  { x: -350, y: -20 },    // RW
  { x: -250, y: -270 },   // RNW
  { x: 20, y: -340 },     // RN
  { x: 280, y: -250 },    // RNE
  { x: 350, y: 30 },      // RE
  { x: 240, y: 310 },     // RSE
  { x: -30, y: 340 },     // RS
  { x: -270, y: 260 },    // RSW

  // E-W road (10)
  { x: -4000, y: 50 },    // W0 far west
  { x: -3200, y: -30 },   // W1 junction
  { x: -2200, y: 80 },    // W2
  { x: -1400, y: -50 },   // W3
  { x: -600, y: 70 },     // W4
  { x: 600, y: -60 },     // E1
  { x: 1400, y: 50 },     // E2
  { x: 2200, y: -80 },    // E3
  { x: 3200, y: 30 },     // E4 junction
  { x: 4000, y: -50 },    // E5 far east

  // N-S road (10)
  { x: 50, y: -3800 },    // N0 far north
  { x: -30, y: -3200 },   // N1
  { x: 70, y: -2400 },    // N2
  { x: -50, y: -1600 },   // N3
  { x: 40, y: -800 },     // N4
  { x: -40, y: 800 },     // S1
  { x: 50, y: 1600 },     // S2
  { x: -50, y: 2200 },    // S3
  { x: 30, y: 2800 },     // S4
  { x: -20, y: 3400 },    // S5 far south

  // Houses (6)
  { x: -3200, y: -1800 }, // NW house
  { x: -3200, y: 1800 },  // SW house
  { x: 3200, y: -1800 },  // NE house
  { x: 3200, y: 1800 },   // SE house
  { x: 0, y: -3200 },     // N house
  { x: 0, y: 2800 },      // S house

  // Branch waypoints (8)
  { x: -3260, y: -600 },  // BNW1
  { x: -3140, y: -1200 }, // BNW2
  { x: -3140, y: 600 },   // BSW1
  { x: -3260, y: 1200 },  // BSW2
  { x: 3260, y: -600 },   // BNE1
  { x: 3140, y: -1200 },  // BNE2
  { x: 3140, y: 600 },    // BSE1
  { x: 3260, y: 1200 },   // BSE2

  // Cross-connection waypoints (8)
  { x: -2100, y: -1500 }, // UC1
  { x: -1000, y: -2000 }, // UC2
  { x: 1000, y: -2000 },  // UC3
  { x: 2100, y: -1500 },  // UC4
  { x: -2100, y: 1500 },  // LC1
  { x: -1000, y: 2000 },  // LC2
  { x: 1000, y: 2000 },   // LC3
  { x: 2100, y: 1500 },   // LC4

  // Dead-end points (4)
  { x: -450, y: -480 },   // Garden
  { x: -2350, y: 280 },   // Old well
  { x: 280, y: -2550 },   // Lookout
  { x: 430, y: 490 },     // Bench
];

// --- Helper functions ---

/** Distance from point to line segment */
function ptSegDist(px: number, py: number, ax: number, ay: number, bx: number, by: number): number {
  const dx = bx - ax, dy = by - ay;
  const lenSq = dx * dx + dy * dy;
  if (lenSq === 0) return Math.hypot(px - ax, py - ay);
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

/** Nearest point on a line segment to a given point */
function nearestOnSeg(px: number, py: number, ax: number, ay: number, bx: number, by: number): { x: number; y: number } {
  const dx = bx - ax, dy = by - ay;
  const lenSq = dx * dx + dy * dy;
  if (lenSq === 0) return { x: ax, y: ay };
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq));
  return { x: ax + t * dx, y: ay + t * dy };
}

/** Minimum distance from a world point to any path segment */
export function minPathDist(wx: number, wy: number): number {
  let min = Infinity;
  for (const s of PATH_SEGMENTS) {
    const d = ptSegDist(wx, wy, s.ax, s.ay, s.bx, s.by);
    if (d < min) min = d;
  }
  return min;
}

/** Nearest point on any path segment to a given world point */
export function nearestPointOnPath(wx: number, wy: number): { x: number; y: number } {
  let minDist = Infinity;
  let nearest = { x: 0, y: 0 };
  for (const s of PATH_SEGMENTS) {
    const d = ptSegDist(wx, wy, s.ax, s.ay, s.bx, s.by);
    if (d < minDist) {
      minDist = d;
      nearest = nearestOnSeg(wx, wy, s.ax, s.ay, s.bx, s.by);
    }
  }
  return nearest;
}
