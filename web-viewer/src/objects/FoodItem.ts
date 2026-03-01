import Phaser from 'phaser';
import { FoodSnapshot } from '../types/snapshot';
import { ICON_FALLBACK, FOOD_EMOJI_TO_ICON } from '../config/constants';
import { cartToIso, isoDepth } from '../systems/IsometricUtils';

export class FoodItem extends Phaser.GameObjects.Container {
  private iconDisplay: Phaser.GameObjects.Image | Phaser.GameObjects.Text;
  private nameText: Phaser.GameObjects.Text;
  private glow: Phaser.GameObjects.Graphics;
  private isBeingEaten = false;
  private isLocal = false;

  constructor(scene: Phaser.Scene, data: FoodSnapshot & { _local?: boolean }) {
    const iso = cartToIso(data.position.x, data.position.y);
    super(scene, iso.x, iso.y);

    this.isBeingEaten = data.isBeingEaten;
    this.isLocal = data._local || false;

    // Glow effect
    this.glow = scene.add.graphics();
    this.drawGlow(16);
    this.add(this.glow);

    // Food icon (PNG from Nano Banana, fallback to emoji)
    const iconName = data.icon || FOOD_EMOJI_TO_ICON[data.emoji] || 'doner';
    const textureKey = 'icon-' + iconName;
    const displaySize = this.isBeingEaten ? 28 : 42;
    if (scene.textures.exists(textureKey)) {
      this.iconDisplay = scene.add.image(0, 0, textureKey)
        .setDisplaySize(displaySize, displaySize).setOrigin(0.5, 0.5);
    } else {
      const fallback = ICON_FALLBACK[iconName] || data.emoji || '🥙';
      this.iconDisplay = scene.add.text(0, 0, fallback, {
        fontSize: displaySize + 'px',
      }).setOrigin(0.5, 0.5);
    }
    this.add(this.iconDisplay);

    // Name label
    this.nameText = scene.add.text(0, 36, data.name || '', {
      fontSize: '12px',
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
        targets: this.iconDisplay,
        y: { from: 0, to: -3 },
        duration: 1000,
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      });
    }

    this.setDepth(isoDepth(data.position.x, data.position.y, 7));
    scene.add.existing(this);
  }

  private drawGlow(size: number) {
    if (this.isBeingEaten) return;
    this.glow.clear();
    // Simple radial glow using concentric circles
    for (let i = 0; i < 6; i++) {
      const r = size - i * 3;
      const alpha = 0.05 * (6 - i);
      this.glow.fillStyle(0xffc832, alpha);
      this.glow.fillCircle(0, 0, r);
    }
  }

  updateGlow(time: number) {
    if (this.isBeingEaten) return;
    const size = 28 + Math.sin(time * 0.004) * 6;
    this.drawGlow(size);
  }
}
