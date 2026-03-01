import Phaser from 'phaser';
import { FoodSnapshot } from '../types/snapshot';
import { ICON_FALLBACK, FOOD_EMOJI_TO_ICON } from '../config/constants';

export class FoodItem extends Phaser.GameObjects.Container {
  private iconText: Phaser.GameObjects.Text;
  private nameText: Phaser.GameObjects.Text;
  private glow: Phaser.GameObjects.Graphics;
  private isBeingEaten = false;
  private isLocal = false;

  constructor(scene: Phaser.Scene, data: FoodSnapshot & { _local?: boolean }) {
    super(scene, data.position.x, -data.position.y);

    this.isBeingEaten = data.isBeingEaten;
    this.isLocal = data._local || false;

    // Glow effect
    this.glow = scene.add.graphics();
    this.drawGlow(16);
    this.add(this.glow);

    // Food icon (emoji fallback)
    const iconName = data.icon || FOOD_EMOJI_TO_ICON[data.emoji] || 'doner';
    const fallback = ICON_FALLBACK[iconName] || data.emoji || '🥙';
    const size = this.isBeingEaten ? 16 : 22;
    this.iconText = scene.add.text(0, 0, fallback, {
      fontSize: size + 'px',
    }).setOrigin(0.5, 0.5);
    this.add(this.iconText);

    // Name label
    this.nameText = scene.add.text(0, 24, data.name || '', {
      fontSize: '8px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: 'rgba(255,255,255,0.7)',
      align: 'center',
      rtl: true,
    }).setOrigin(0.5, 0.5);
    this.add(this.nameText);

    // Set alpha
    if (this.isBeingEaten) {
      this.setAlpha(0.4);
    } else if (this.isLocal) {
      this.setAlpha(0.7);
    }

    // Bounce tween
    if (!this.isBeingEaten) {
      scene.tweens.add({
        targets: this.iconText,
        y: { from: 0, to: -3 },
        duration: 1000,
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      });
    }

    this.setDepth(7);
    scene.add.existing(this);
  }

  private drawGlow(size: number) {
    if (this.isBeingEaten) return;
    this.glow.clear();
    // Simple radial glow using concentric circles
    for (let i = 0; i < 5; i++) {
      const r = size - i * 2;
      const alpha = 0.04 * (5 - i);
      this.glow.fillStyle(0xffc832, alpha);
      this.glow.fillCircle(0, 0, r);
    }
  }

  updateGlow(time: number) {
    if (this.isBeingEaten) return;
    const size = 16 + Math.sin(time * 0.004) * 4;
    this.drawGlow(size);
  }
}
