import Phaser from 'phaser';
import { HouseSnapshot } from '../types/snapshot';
import { ICON_FALLBACK, HOUSE_EMOJI_TO_ICON } from '../config/constants';

export class House extends Phaser.GameObjects.Container {
  private graphics: Phaser.GameObjects.Graphics;
  private nameText: Phaser.GameObjects.Text;
  private iconText: Phaser.GameObjects.Text;
  private windowGlowing = false;

  constructor(scene: Phaser.Scene, data: HouseSnapshot) {
    super(scene, data.position.x, -data.position.y);

    const roofColor = parseInt((data.roofColor || '#A0522D').replace('#', ''), 16);
    const wallColor = parseInt((data.wallColor || '#8B7355').replace('#', ''), 16);

    this.graphics = scene.add.graphics();
    this.drawHouse(roofColor, wallColor, false);
    this.add(this.graphics);

    // Icon above roof
    const iconName = data.icon || HOUSE_EMOJI_TO_ICON[data.emoji] || 'house';
    const fallback = ICON_FALLBACK[iconName] || data.emoji || '🏠';
    this.iconText = scene.add.text(0, -34, fallback, {
      fontSize: '20px',
    }).setOrigin(0.5, 0.5);
    this.add(this.iconText);

    // Name label below
    this.nameText = scene.add.text(0, 64, data.name || '', {
      fontSize: '10px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: 'rgba(255,255,255,0.8)',
      align: 'center',
      rtl: true,
    }).setOrigin(0.5, 0.5);
    this.add(this.nameText);

    this.setDepth(5);
    scene.add.existing(this);
  }

  private drawHouse(roofColor: number, wallColor: number, isNight: boolean) {
    const g = this.graphics;
    g.clear();

    // Shadow
    g.fillStyle(0x000000, 0.2);
    g.fillRect(-38, 4, 76, 56);

    // Walls
    g.fillStyle(wallColor, 1);
    g.fillRect(-35, 0, 70, 50);
    g.lineStyle(1, 0xffffff, 0.12);
    g.strokeRect(-35, 0, 70, 50);

    // Roof
    g.fillStyle(roofColor, 1);
    g.fillTriangle(-42, 0, 0, -25, 42, 0);

    // Door
    g.fillStyle(0x644628, 0.8);
    g.fillRect(-8, 25, 16, 25);
    // Door knob
    g.fillStyle(0xc8b432, 0.6);
    g.fillCircle(4, 38, 2);

    // Windows
    const windowColor = isNight ? 0xffe664 : 0x96b4dc;
    const windowAlpha = isNight ? 0.7 : 0.3;
    g.fillStyle(windowColor, windowAlpha);
    g.fillRect(-25, 10, 12, 12);
    g.fillRect(13, 10, 12, 12);

    // Window cross-bars
    g.lineStyle(0.5, 0xffffff, 0.15);
    g.beginPath();
    g.moveTo(-19, 10); g.lineTo(-19, 22);
    g.moveTo(-25, 16); g.lineTo(-13, 16);
    g.moveTo(19, 10); g.lineTo(19, 22);
    g.moveTo(13, 16); g.lineTo(25, 16);
    g.strokePath();
  }

  setNightMode(isNight: boolean) {
    if (isNight === this.windowGlowing) return;
    this.windowGlowing = isNight;
    // Redraw is expensive, so we cache the state
    // We'd need the colors from the snapshot for a full redraw
    // For now, we'll handle this via the DayNightCycle overlay
  }
}
