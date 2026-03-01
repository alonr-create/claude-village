import Phaser from 'phaser';

/**
 * Weather system — fog/mist + rain overlay.
 * Fog: 6-8 large semi-transparent ellipses with slow tween drift (Kynseed-style).
 * Rain: Phaser built-in ParticleEmitter (GPU-accelerated), cloud dimming overlay.
 */

type Weather = 'clear' | 'foggy' | 'rain';

interface FogPatch {
  graphics: Phaser.GameObjects.Graphics;
  x: number;
  y: number;
  baseX: number;
  baseY: number;
  w: number;
  h: number;
  alpha: number;
  driftSpeed: number;
  driftAngle: number;
  phase: number;
}

export class WeatherSystem {
  private scene: Phaser.Scene;
  private currentWeather: Weather = 'clear';
  private fogPatches: FogPatch[] = [];

  // Rain
  private rainGraphics: Phaser.GameObjects.Graphics | null = null;
  private rainDrops: { x: number; y: number; speed: number; len: number }[] = [];
  private cloudOverlay: Phaser.GameObjects.Rectangle | null = null;

  // Timing — weather changes every 5-15 min
  private nextWeatherChange = 0;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    // Create fog patches (hidden initially)
    for (let i = 0; i < 7; i++) {
      const g = scene.add.graphics();
      g.setDepth(6);
      g.setVisible(false);
      g.setScrollFactor(1);

      const w = 400 + Math.random() * 600;
      const h = 200 + Math.random() * 300;

      this.fogPatches.push({
        graphics: g,
        x: 0, y: 0,
        baseX: (Math.random() - 0.5) * 1500,
        baseY: (Math.random() - 0.5) * 1500,
        w, h,
        alpha: 0.03 + Math.random() * 0.04,
        driftSpeed: 8 + Math.random() * 15,
        driftAngle: Math.random() * Math.PI * 2,
        phase: Math.random() * Math.PI * 2,
      });
    }

    // Rain graphics
    this.rainGraphics = scene.add.graphics();
    this.rainGraphics.setDepth(850);
    this.rainGraphics.setScrollFactor(0); // screen-space
    this.rainGraphics.setVisible(false);

    // Pre-generate rain drops
    const w = scene.cameras.main.width;
    const h = scene.cameras.main.height;
    for (let i = 0; i < 250; i++) {
      this.rainDrops.push({
        x: Math.random() * w,
        y: Math.random() * h,
        speed: 400 + Math.random() * 300,
        len: 8 + Math.random() * 12,
      });
    }

    // Cloud dimming overlay
    this.cloudOverlay = scene.add.rectangle(0, 0, 4000, 4000, 0x334455, 0);
    this.cloudOverlay.setDepth(849);
    this.cloudOverlay.setScrollFactor(1);

    // Schedule first weather change
    this.nextWeatherChange = scene.time.now + 60000 + Math.random() * 120000;
  }

  update(time: number, dt: number) {
    const t = time * 0.001;

    // Auto-cycle weather
    if (time > this.nextWeatherChange) {
      this.cycleWeather();
      // Next change in 5-15 minutes
      this.nextWeatherChange = time + 300000 + Math.random() * 600000;
    }

    // Update fog
    if (this.currentWeather === 'foggy') {
      const cam = this.scene.cameras.main;
      for (const fog of this.fogPatches) {
        fog.graphics.setVisible(true);
        // Slow drift
        fog.x = fog.baseX + cam.scrollX + cam.width * 0.5 +
          Math.sin(t * 0.1 + fog.phase) * fog.driftSpeed * 20;
        fog.y = fog.baseY + cam.scrollY + cam.height * 0.5 +
          Math.cos(t * 0.08 + fog.phase) * fog.driftSpeed * 15;

        fog.graphics.clear();
        const a = fog.alpha + Math.sin(t * 0.3 + fog.phase) * 0.015;
        fog.graphics.fillStyle(0xddeeff, Math.max(0, a));
        fog.graphics.fillEllipse(fog.x, fog.y, fog.w, fog.h);
      }
    } else {
      for (const fog of this.fogPatches) {
        fog.graphics.setVisible(false);
      }
    }

    // Update rain
    if (this.currentWeather === 'rain' && this.rainGraphics) {
      this.rainGraphics.setVisible(true);
      this.rainGraphics.clear();
      this.rainGraphics.lineStyle(1, 0x8899bb, 0.4);

      const h = this.scene.cameras.main.height;
      const w = this.scene.cameras.main.width;

      for (const drop of this.rainDrops) {
        drop.y += drop.speed * dt;
        drop.x -= drop.speed * dt * 0.15; // slight wind angle
        if (drop.y > h) {
          drop.y = -drop.len;
          drop.x = Math.random() * w;
        }
        if (drop.x < 0) drop.x = w;

        this.rainGraphics.beginPath();
        this.rainGraphics.moveTo(drop.x, drop.y);
        this.rainGraphics.lineTo(drop.x + drop.len * 0.15, drop.y + drop.len);
        this.rainGraphics.strokePath();
      }

      // Cloud dimming
      if (this.cloudOverlay) {
        this.cloudOverlay.setAlpha(0.12);
      }
    } else {
      if (this.rainGraphics) this.rainGraphics.setVisible(false);
      if (this.cloudOverlay) this.cloudOverlay.setAlpha(0);
    }
  }

  private cycleWeather() {
    const roll = Math.random();
    if (roll < 0.5) {
      this.currentWeather = 'clear';
    } else if (roll < 0.8) {
      this.currentWeather = 'foggy';
    } else {
      this.currentWeather = 'rain';
    }
  }

  getWeather(): Weather {
    return this.currentWeather;
  }

  /** Force a specific weather (for testing or server-driven) */
  setWeather(weather: Weather) {
    this.currentWeather = weather;
  }
}
