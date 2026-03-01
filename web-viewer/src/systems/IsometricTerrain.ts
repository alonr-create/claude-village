/**
 * Isometric tile-based terrain for FarmVille-style rendering.
 * Uses procedural Perlin noise (same seed as v4) to determine tile types,
 * but renders as an isometric diamond tilemap.
 */
import Phaser from 'phaser';
import { createNoise2D } from 'simplex-noise';
import { WORLD_SIZE, ISO_TILE_W, ISO_TILE_H } from '../config/constants';
import { cartToIso, isoDepth } from './IsometricUtils';
import { minPathDist } from '../config/pathNetwork';

// Tile type indices (match tileset layout — 8 columns, row-major)
export enum TileType {
  GRASS_1 = 0,
  GRASS_2 = 1,
  GRASS_3 = 2,
  GRASS_4 = 3,
  DIRT_1 = 4,
  DIRT_2 = 5,
  DIRT_3 = 6,
  DIRT_4 = 7,
  PLOWED_1 = 8,
  PLOWED_2 = 9,
  WATER_1 = 10,
  WATER_2 = 11,
  SAND_1 = 12,
  SAND_2 = 13,
  FLOWER_1 = 14,
  FLOWER_2 = 15,
}

// Map grid size — covers the visible farm area
const MAP_COLS = 80;
const MAP_ROWS = 80;

// How much world space each tile covers
const TILE_WORLD = 100; // one tile = 100x100 world units

export class IsometricTerrain {
  private tileData: number[][] = [];
  private sprites: Phaser.GameObjects.Image[] = [];
  private elevNoise: (x: number, y: number) => number;
  private moistNoise: (x: number, y: number) => number;

  constructor(private scene: Phaser.Scene) {
    // Same seed as v4 for geographic consistency
    this.elevNoise = createNoise2D(this.makeRng(42));
    this.moistNoise = createNoise2D(this.makeRng(1042));

    this.generateTileData();
    this.renderTiles();
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

  /** Generate the 2D tile type grid based on terrain noise */
  private generateTileData() {
    const rng = this.makeRng(999);
    this.tileData = [];

    const halfCols = MAP_COLS / 2;
    const halfRows = MAP_ROWS / 2;

    for (let row = 0; row < MAP_ROWS; row++) {
      const tileRow: number[] = [];
      for (let col = 0; col < MAP_COLS; col++) {
        // World position of this tile center
        const wx = (col - halfCols) * TILE_WORLD;
        const wy = (row - halfRows) * TILE_WORLD;

        const elev = this.fbm(this.elevNoise, wx * 0.00028, wy * 0.00028, 4) + 0.42;
        const moist = this.fbm(this.moistNoise, wx * 0.00035 + 50, wy * 0.00035 + 50, 3);
        const roadDist = minPathDist(wx, wy);
        const dist = Math.sqrt(wx * wx + wy * wy);

        let tile: TileType;

        // Roads / paths
        if (roadDist < 100) {
          const r = rng();
          tile = r < 0.5 ? TileType.DIRT_1 : r < 0.75 ? TileType.DIRT_2 : TileType.DIRT_3;
        }
        // Water (deep or lakes)
        else if (elev < -0.1) {
          tile = rng() < 0.5 ? TileType.WATER_1 : TileType.WATER_2;
        }
        // Sand / shoreline
        else if (elev < 0.02) {
          tile = rng() < 0.5 ? TileType.SAND_1 : TileType.SAND_2;
        }
        // Village center — plowed fields / flowers
        else if (dist < 600) {
          const r = rng();
          if (r < 0.3) tile = TileType.FLOWER_1;
          else if (r < 0.5) tile = TileType.FLOWER_2;
          else if (r < 0.7) tile = TileType.PLOWED_1;
          else tile = rng() < 0.5 ? TileType.GRASS_1 : TileType.GRASS_2;
        }
        // Flower meadows (high moisture)
        else if (moist > 0.3 && elev > 0.05 && elev < 0.35) {
          tile = rng() < 0.5 ? TileType.FLOWER_1 : TileType.FLOWER_2;
        }
        // Plowed farm fields (near roads, mid-distance)
        else if (roadDist < 250 && dist < 2000 && elev > 0.05 && elev < 0.35) {
          const r = rng();
          tile = r < 0.4 ? TileType.PLOWED_1 : r < 0.6 ? TileType.PLOWED_2 : TileType.GRASS_3;
        }
        // General grassland
        else {
          const r = rng();
          if (r < 0.35) tile = TileType.GRASS_1;
          else if (r < 0.60) tile = TileType.GRASS_2;
          else if (r < 0.80) tile = TileType.GRASS_3;
          else tile = TileType.GRASS_4;
        }

        tileRow.push(tile);
      }
      this.tileData.push(tileRow);
    }
  }

  /** Render all tiles as isometric diamond sprites */
  private renderTiles() {
    const halfCols = MAP_COLS / 2;
    const halfRows = MAP_ROWS / 2;
    const hasTileset = this.scene.textures.exists('farm-tileset');

    for (let row = 0; row < MAP_ROWS; row++) {
      for (let col = 0; col < MAP_COLS; col++) {
        // World position of tile
        const wx = (col - halfCols) * TILE_WORLD;
        const wy = (row - halfRows) * TILE_WORLD;

        // Convert to isometric screen position
        const iso = cartToIso(wx, wy);

        if (hasTileset) {
          const tileIdx = this.tileData[row][col];
          const img = this.scene.add.image(iso.x, iso.y, 'farm-tileset', tileIdx);
          img.setDisplaySize(ISO_TILE_W, ISO_TILE_H);
          img.setDepth(0);
          img.setOrigin(0.5, 0.5);
          this.sprites.push(img);
        } else {
          // Fallback: colored diamonds when tileset not available
          const g = this.scene.add.graphics();
          g.setDepth(0);
          const tile = this.tileData[row][col];
          const color = this.getFallbackColor(tile);
          g.fillStyle(color, 1);
          // Draw isometric diamond
          g.beginPath();
          g.moveTo(iso.x, iso.y - ISO_TILE_H / 2);           // top
          g.lineTo(iso.x + ISO_TILE_W / 2, iso.y);             // right
          g.lineTo(iso.x, iso.y + ISO_TILE_H / 2);             // bottom
          g.lineTo(iso.x - ISO_TILE_W / 2, iso.y);             // left
          g.closePath();
          g.fillPath();
          // Subtle grid line
          g.lineStyle(0.5, 0x000000, 0.08);
          g.strokePath();
        }
      }
    }

    // Map border (isometric diamond outline)
    const border = this.scene.add.graphics();
    border.setDepth(1);
    border.lineStyle(3, 0x8B7355, 0.4); // brown fence color
    const corners = [
      cartToIso(-halfCols * TILE_WORLD, -halfRows * TILE_WORLD),
      cartToIso(halfCols * TILE_WORLD, -halfRows * TILE_WORLD),
      cartToIso(halfCols * TILE_WORLD, halfRows * TILE_WORLD),
      cartToIso(-halfCols * TILE_WORLD, halfRows * TILE_WORLD),
    ];
    border.beginPath();
    border.moveTo(corners[0].x, corners[0].y);
    for (let i = 1; i < corners.length; i++) {
      border.lineTo(corners[i].x, corners[i].y);
    }
    border.closePath();
    border.strokePath();
  }

  /** Fallback colors when tileset PNG is not loaded */
  private getFallbackColor(tile: TileType): number {
    switch (tile) {
      case TileType.GRASS_1: return 0x7CCD7C;
      case TileType.GRASS_2: return 0x6BB86B;
      case TileType.GRASS_3: return 0x5CA85C;
      case TileType.GRASS_4: return 0x8DD88D;
      case TileType.DIRT_1: return 0xC4A882;
      case TileType.DIRT_2: return 0xB89B72;
      case TileType.DIRT_3: return 0xD4B892;
      case TileType.DIRT_4: return 0xAA8E66;
      case TileType.PLOWED_1: return 0x8B6914;
      case TileType.PLOWED_2: return 0x7A5C10;
      case TileType.WATER_1: return 0x4A90D9;
      case TileType.WATER_2: return 0x5BA0E0;
      case TileType.SAND_1: return 0xE8D5A0;
      case TileType.SAND_2: return 0xDCC890;
      case TileType.FLOWER_1: return 0x8BC88B;
      case TileType.FLOWER_2: return 0x9DD89D;
      default: return 0x7CCD7C;
    }
  }

  /** Check if a world position is water */
  isWater(wx: number, wy: number): boolean {
    const halfCols = MAP_COLS / 2;
    const halfRows = MAP_ROWS / 2;
    const col = Math.floor(wx / TILE_WORLD + halfCols);
    const row = Math.floor(wy / TILE_WORLD + halfRows);
    if (row < 0 || row >= MAP_ROWS || col < 0 || col >= MAP_COLS) return false;
    const tile = this.tileData[row][col];
    return tile === TileType.WATER_1 || tile === TileType.WATER_2;
  }

  /** Get tile type at a world position */
  getTileAt(wx: number, wy: number): TileType {
    const halfCols = MAP_COLS / 2;
    const halfRows = MAP_ROWS / 2;
    const col = Math.floor(wx / TILE_WORLD + halfCols);
    const row = Math.floor(wy / TILE_WORLD + halfRows);
    if (row < 0 || row >= MAP_ROWS || col < 0 || col >= MAP_COLS) return TileType.GRASS_1;
    return this.tileData[row][col];
  }

  destroy() {
    for (const s of this.sprites) s.destroy();
    this.sprites = [];
  }
}
