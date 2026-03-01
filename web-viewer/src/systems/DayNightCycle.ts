import Phaser from 'phaser';
import { DAY_COLORS } from '../config/constants';

interface Star {
  x: number;
  y: number;
  size: number;
  speed: number; // twinkle speed
  phase: number;
}

interface Firefly {
  x: number;
  y: number;
  vx: number;
  vy: number;
  phase: number;
  speed: number;
}

export class DayNightCycle {
  private overlay: Phaser.GameObjects.Rectangle;
  private currentPeriod = 'day';
  private targetAlpha = 0;
  private targetColor = 0x000000;

  // Camera post-FX
  private vignette: any = null;
  private bloom: any = null;

  // Stars (night only)
  private starsGraphics: Phaser.GameObjects.Graphics;
  private stars: Star[] = [];

  // Fireflies (night only)
  private firefliesGraphics: Phaser.GameObjects.Graphics;
  private fireflies: Firefly[] = [];

  constructor(private scene: Phaser.Scene) {
    // Overlay — much more subtle
    // Bigger overlay for isometric world (wider diamond)
    this.overlay = scene.add.rectangle(0, 0, 16000, 8000, 0x000000, 0);
    this.overlay.setDepth(900);
    this.overlay.setScrollFactor(1);

    // Stars layer (above ground, below everything else)
    this.starsGraphics = scene.add.graphics();
    this.starsGraphics.setDepth(1);
    this.starsGraphics.setScrollFactor(0); // Fixed to camera
    this.starsGraphics.setVisible(false);

    // Generate star positions
    const w = scene.cameras.main.width;
    const h = scene.cameras.main.height;
    for (let i = 0; i < 30; i++) {
      this.stars.push({
        x: Math.random() * w,
        y: Math.random() * h * 0.6, // Top 60% of screen
        size: 0.5 + Math.random() * 1.5,
        speed: 0.5 + Math.random() * 2,
        phase: Math.random() * Math.PI * 2,
      });
    }

    // Fireflies
    this.firefliesGraphics = scene.add.graphics();
    this.firefliesGraphics.setDepth(8);
    this.firefliesGraphics.setVisible(false);

    for (let i = 0; i < 8; i++) {
      this.fireflies.push({
        x: (Math.random() - 0.5) * 800,
        y: (Math.random() - 0.5) * 800,
        vx: (Math.random() - 0.5) * 15,
        vy: (Math.random() - 0.5) * 15,
        phase: Math.random() * Math.PI * 2,
        speed: 0.5 + Math.random() * 1.5,
      });
    }

    // Camera post-FX (WebGL only)
    try {
      const cam = scene.cameras.main;
      if (cam.postFX) {
        this.vignette = cam.postFX.addVignette(0.5, 0.5, 0.9, 0.2);
        this.bloom = cam.postFX.addBloom(0xffffff, 1, 1, 1, 0.6);
        this.bloom.active = false; // start inactive
      }
    } catch (_e) {
      // Canvas renderer — no postFX support, silently skip
    }
  }

  update(period: string) {
    if (period === this.currentPeriod) return;
    this.currentPeriod = period;

    const colors = DAY_COLORS[period] || DAY_COLORS.day;
    this.scene.cameras.main.setBackgroundColor(colors.bg);

    // Smooth tween to target overlay
    this.targetAlpha = colors.overlayAlpha;
    this.targetColor = colors.overlayColor;

    this.scene.tweens.add({
      targets: this.overlay,
      alpha: { from: this.overlay.alpha, to: 1 },
      duration: 2000,
      ease: 'Sine.easeInOut',
      onUpdate: () => {
        // Phaser rectangle fill alpha is set via fillStyle, so we tween manually
      },
    });
    this.overlay.setFillStyle(this.targetColor, this.targetAlpha);

    // Show/hide night effects
    const nightMode = period === 'night' || period === 'evening';
    this.starsGraphics.setVisible(nightMode);
    this.firefliesGraphics.setVisible(period === 'night');

    // Update camera post-FX per period
    if (this.vignette) {
      switch (period) {
        case 'morning':
          this.vignette.radius = 0.85; this.vignette.strength = 0.3;
          if (this.bloom) this.bloom.active = false;
          break;
        case 'day':
          this.vignette.radius = 0.9; this.vignette.strength = 0.2;
          if (this.bloom) this.bloom.active = false;
          break;
        case 'evening':
          this.vignette.radius = 0.7; this.vignette.strength = 0.5;
          if (this.bloom) { this.bloom.active = true; this.bloom.strength = 0.6; }
          break;
        case 'night':
          this.vignette.radius = 0.6; this.vignette.strength = 0.7;
          if (this.bloom) { this.bloom.active = true; this.bloom.strength = 1.0; }
          break;
      }
    }
  }

  /** Call every frame from VillageScene.update() */
  updateEffects(time: number, dt: number) {
    const isNightMode = this.currentPeriod === 'night' || this.currentPeriod === 'evening';
    if (!isNightMode) return;

    const t = time * 0.001;

    // Draw stars
    if (this.starsGraphics.visible) {
      this.starsGraphics.clear();
      for (const star of this.stars) {
        const alpha = 0.3 + Math.sin(t * star.speed + star.phase) * 0.3;
        this.starsGraphics.fillStyle(0xffffff, alpha);
        this.starsGraphics.fillCircle(star.x, star.y, star.size);
      }
    }

    // Draw fireflies
    if (this.firefliesGraphics.visible) {
      this.firefliesGraphics.clear();
      for (const ff of this.fireflies) {
        // Move with slow random wandering
        ff.x += ff.vx * dt;
        ff.y += ff.vy * dt;

        // Gentle direction changes
        ff.vx += (Math.random() - 0.5) * 2;
        ff.vy += (Math.random() - 0.5) * 2;
        ff.vx = Math.max(-20, Math.min(20, ff.vx));
        ff.vy = Math.max(-20, Math.min(20, ff.vy));

        // Wrap around
        if (ff.x < -500) ff.x = 500;
        if (ff.x > 500) ff.x = -500;
        if (ff.y < -500) ff.y = 500;
        if (ff.y > 500) ff.y = -500;

        const alpha = 0.3 + Math.sin(t * ff.speed + ff.phase) * 0.3;

        // Warm glow
        this.firefliesGraphics.fillStyle(0xffe464, alpha * 0.3);
        this.firefliesGraphics.fillCircle(ff.x, ff.y, 6);
        this.firefliesGraphics.fillStyle(0xffee88, alpha);
        this.firefliesGraphics.fillCircle(ff.x, ff.y, 2);
      }
    }
  }

  isNight(): boolean {
    return this.currentPeriod === 'night' || this.currentPeriod === 'evening';
  }

  getPeriod(): string {
    return this.currentPeriod;
  }
}
