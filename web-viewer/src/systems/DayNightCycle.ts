import Phaser from 'phaser';
import { DAY_COLORS } from '../config/constants';

export class DayNightCycle {
  private overlay: Phaser.GameObjects.Rectangle;
  private currentPeriod = 'day';

  constructor(private scene: Phaser.Scene) {
    // Create a large overlay rectangle for night/evening tinting
    this.overlay = scene.add.rectangle(0, 0, 4000, 4000, 0x000000, 0);
    this.overlay.setDepth(900); // Above game objects, below HUD
    this.overlay.setScrollFactor(1); // Moves with camera
  }

  update(period: string) {
    if (period === this.currentPeriod) return;
    this.currentPeriod = period;

    const colors = DAY_COLORS[period] || DAY_COLORS.day;
    this.scene.cameras.main.setBackgroundColor(colors.bg);
    this.overlay.setFillStyle(colors.overlayColor, colors.overlayAlpha);
  }

  isNight(): boolean {
    return this.currentPeriod === 'night' || this.currentPeriod === 'evening';
  }
}
