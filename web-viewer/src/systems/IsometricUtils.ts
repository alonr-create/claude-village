/**
 * Isometric (2.5D) coordinate utilities.
 * Standard 2:1 diamond projection — FarmVille style.
 *
 * The server sends Cartesian (wx, wy) world coordinates.
 * All visual rendering uses isometric (sx, sy) screen coordinates.
 */

// Isometric tile dimensions (pixels)
export const ISO_TILE_W = 128;
export const ISO_TILE_H = 64;

/** Cartesian world → isometric screen position */
export function cartToIso(wx: number, wy: number): { x: number; y: number } {
  return {
    x: (wx - wy),
    y: (wx + wy) * 0.5,
  };
}

/** Isometric screen → Cartesian world position */
export function isoToCart(sx: number, sy: number): { x: number; y: number } {
  return {
    x: sx * 0.5 + sy,
    y: sy - sx * 0.5,
  };
}

/**
 * Depth value for isometric objects.
 * In isometric view, objects closer to the viewer (higher wx + wy)
 * should appear in front. The layer parameter separates categories.
 */
export function isoDepth(wx: number, wy: number, layer: number = 0): number {
  return layer + (wx + wy) * 0.0001;
}

/** Convert world coordinates to tile grid position */
export function worldToTile(wx: number, wy: number): { col: number; row: number } {
  return {
    col: Math.floor(wx / ISO_TILE_W),
    row: Math.floor(wy / ISO_TILE_H),
  };
}

/**
 * Determine facing direction from velocity in world space.
 * Returns one of 4 isometric directions.
 */
export function velocityToDirection(vx: number, vy: number): 'se' | 'sw' | 'ne' | 'nw' {
  // In isometric:
  //   +wx direction (east in world) = SE on screen
  //   -wx direction (west in world) = NW on screen
  //   +wy direction (south in world) = SW on screen
  //   -wy direction (north in world) = NE on screen
  if (Math.abs(vx) > Math.abs(vy)) {
    return vx > 0 ? 'se' : 'nw';
  } else {
    return vy > 0 ? 'sw' : 'ne';
  }
}
