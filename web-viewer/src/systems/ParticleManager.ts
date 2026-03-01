import Phaser from 'phaser';

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  color: number;
  size: number;
  gravity: number;
  fadeOut: boolean;
  scaleDown: boolean;
  graphics: Phaser.GameObjects.Graphics;
  active: boolean;
}

export interface EmitConfig {
  x: number;
  y: number;
  count: number;
  color: number;
  alpha?: number;
  sizeMin: number;
  sizeMax: number;
  speedMin: number;
  speedMax: number;
  lifeMin: number;
  lifeMax: number;
  gravity?: number;
  fadeOut?: boolean;
  scaleDown?: boolean;
  depth?: number;
  angleMin?: number;
  angleMax?: number;
}

const POOL_SIZE = 200;

export class ParticleManager {
  private pool: Particle[] = [];
  private scene: Phaser.Scene;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    // Pre-allocate pool
    for (let i = 0; i < POOL_SIZE; i++) {
      const g = scene.add.graphics();
      g.setVisible(false);
      g.setDepth(950);
      this.pool.push({
        x: 0, y: 0, vx: 0, vy: 0,
        life: 0, maxLife: 0, color: 0, size: 0,
        gravity: 0, fadeOut: true, scaleDown: false,
        graphics: g, active: false,
      });
    }
  }

  emit(config: EmitConfig) {
    const angleMin = config.angleMin ?? 0;
    const angleMax = config.angleMax ?? Math.PI * 2;

    for (let i = 0; i < config.count; i++) {
      const p = this.getFromPool();
      if (!p) return; // pool exhausted

      const angle = angleMin + Math.random() * (angleMax - angleMin);
      const speed = config.speedMin + Math.random() * (config.speedMax - config.speedMin);
      const life = config.lifeMin + Math.random() * (config.lifeMax - config.lifeMin);
      const size = config.sizeMin + Math.random() * (config.sizeMax - config.sizeMin);

      p.x = config.x;
      p.y = config.y;
      p.vx = Math.cos(angle) * speed;
      p.vy = Math.sin(angle) * speed;
      p.life = life;
      p.maxLife = life;
      p.color = config.color;
      p.size = size;
      p.gravity = config.gravity ?? 0;
      p.fadeOut = config.fadeOut ?? true;
      p.scaleDown = config.scaleDown ?? false;
      p.active = true;

      p.graphics.clear();
      p.graphics.fillStyle(config.color, config.alpha ?? 1);
      p.graphics.fillCircle(0, 0, size);
      p.graphics.setPosition(config.x, config.y);
      p.graphics.setDepth(config.depth ?? 950);
      p.graphics.setAlpha(1);
      p.graphics.setScale(1);
      p.graphics.setVisible(true);
    }
  }

  /** Convenience: burst of dust particles */
  dustBurst(x: number, y: number, count = 3) {
    this.emit({
      x, y, count,
      color: 0x8B7355,
      alpha: 0.5,
      sizeMin: 1, sizeMax: 3,
      speedMin: 10, speedMax: 30,
      lifeMin: 0.3, lifeMax: 0.6,
      gravity: 20,
      fadeOut: true,
      angleMin: -Math.PI, angleMax: 0, // upward
    });
  }

  /** Convenience: sparkle burst */
  sparkleBurst(x: number, y: number, count = 5) {
    this.emit({
      x, y, count,
      color: 0xffd700,
      sizeMin: 1, sizeMax: 3,
      speedMin: 20, speedMax: 60,
      lifeMin: 0.4, lifeMax: 0.8,
      fadeOut: true,
      scaleDown: true,
    });
  }

  /** Convenience: food particles */
  foodBurst(x: number, y: number) {
    this.emit({
      x, y, count: 8,
      color: 0xd4af37,
      sizeMin: 2, sizeMax: 4,
      speedMin: 40, speedMax: 80,
      lifeMin: 0.5, lifeMax: 0.8,
      fadeOut: true,
    });
  }

  /** Convenience: heart particles */
  hearts(x: number, y: number) {
    this.emit({
      x, y, count: 2,
      color: 0xff6b6b,
      sizeMin: 2, sizeMax: 3,
      speedMin: 10, speedMax: 25,
      lifeMin: 0.6, lifeMax: 1.0,
      gravity: -30, // float up
      fadeOut: true,
      angleMin: -Math.PI * 0.75, angleMax: -Math.PI * 0.25,
    });
  }

  /** Convenience: construction particles */
  constructionDust(x: number, y: number) {
    this.emit({
      x, y, count: 4,
      color: 0x999999,
      alpha: 0.4,
      sizeMin: 2, sizeMax: 5,
      speedMin: 15, speedMax: 40,
      lifeMin: 0.4, lifeMax: 0.8,
      gravity: 15,
      fadeOut: true,
    });
  }

  /** Convenience: Z particles for sleeping */
  sleepZ(x: number, y: number) {
    this.emit({
      x, y, count: 1,
      color: 0x60a5fa,
      alpha: 0.6,
      sizeMin: 2, sizeMax: 3,
      speedMin: 5, speedMax: 12,
      lifeMin: 1.0, lifeMax: 1.5,
      gravity: -20,
      fadeOut: true,
      angleMin: -Math.PI * 0.7, angleMax: -Math.PI * 0.3,
    });
  }

  /** Ambient floating particles — pollen, golden dust, falling leaves */
  emitAmbient(x: number, y: number, period: string) {
    if (period === 'day' || period === 'morning') {
      // Floating pollen — gentle upward drift
      this.emit({
        x, y, count: 1,
        color: 0xf8f0c0,
        alpha: 0.25,
        sizeMin: 1, sizeMax: 2,
        speedMin: 2, speedMax: 8,
        lifeMin: 3, lifeMax: 5,
        gravity: -2,
        fadeOut: true,
        depth: 7,
      });
    } else if (period === 'evening') {
      // Warm golden dust motes
      this.emit({
        x, y, count: 1,
        color: 0xffd080,
        alpha: 0.3,
        sizeMin: 1, sizeMax: 3,
        speedMin: 3, speedMax: 10,
        lifeMin: 2, lifeMax: 4,
        gravity: -3,
        fadeOut: true,
        depth: 7,
      });
    }
    // Occasional falling leaf (1 in 5 chance)
    if (Math.random() < 0.2) {
      this.emit({
        x: x + (Math.random() - 0.5) * 200,
        y: y - 100,
        count: 1,
        color: period === 'evening' ? 0xc08040 : 0x60a040,
        alpha: 0.4,
        sizeMin: 2, sizeMax: 3,
        speedMin: 5, speedMax: 15,
        lifeMin: 2, lifeMax: 4,
        gravity: 15,
        fadeOut: true,
        depth: 7,
        angleMin: Math.PI * 0.1, angleMax: Math.PI * 0.4,
      });
    }
  }

  /** Convenience: smoke from chimney */
  chimneySmoke(x: number, y: number) {
    this.emit({
      x, y, count: 1,
      color: 0x888888,
      alpha: 0.2,
      sizeMin: 2, sizeMax: 4,
      speedMin: 3, speedMax: 8,
      lifeMin: 1.5, lifeMax: 2.5,
      gravity: -12,
      fadeOut: true,
      scaleDown: false,
      angleMin: -Math.PI * 0.7, angleMax: -Math.PI * 0.3,
    });
  }

  update(dt: number) {
    for (const p of this.pool) {
      if (!p.active) continue;

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
      p.life -= dt;

      if (p.life <= 0) {
        p.active = false;
        p.graphics.setVisible(false);
        continue;
      }

      const ratio = p.life / p.maxLife;
      p.graphics.setPosition(p.x, p.y);
      if (p.fadeOut) p.graphics.setAlpha(ratio);
      if (p.scaleDown) p.graphics.setScale(ratio);
    }
  }

  private getFromPool(): Particle | null {
    for (const p of this.pool) {
      if (!p.active) return p;
    }
    return null;
  }
}
