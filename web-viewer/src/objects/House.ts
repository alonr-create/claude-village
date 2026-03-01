import Phaser from 'phaser';
import { HouseSnapshot } from '../types/snapshot';
import { ICON_FALLBACK, HOUSE_EMOJI_TO_ICON, FARM_BUILDING_MAP } from '../config/constants';
import { cartToIso, isoDepth } from '../systems/IsometricUtils';

// Farm building sprite textures (isometric)
const FARM_TEXTURES = ['barn-red-iso', 'farmhouse-blue-iso', 'silo-green-iso', 'windmill-brown-iso'];

// Fallback to old house textures if farm ones don't exist
const HOUSE_TEXTURES = ['house-red', 'house-blue', 'house-green', 'house-brown'];

// Scale for building sprites
const BUILDING_SCALE = 0.40;

export class House extends Phaser.GameObjects.Container {
  private houseSprite: Phaser.GameObjects.Image | null = null;
  private nameText: Phaser.GameObjects.Text;
  private iconDisplay: Phaser.GameObjects.Image | Phaser.GameObjects.Text;
  private shadow: Phaser.GameObjects.Graphics;
  private windowGlow: Phaser.GameObjects.Graphics | null = null;
  private activePulse: Phaser.Tweens.Tween | null = null;

  // Store world coords for depth sorting
  private worldX: number;
  private worldY: number;

  constructor(scene: Phaser.Scene, data: HouseSnapshot) {
    // Convert to isometric position
    const iso = cartToIso(data.position.x, data.position.y);
    super(scene, iso.x, iso.y);

    this.worldX = data.position.x;
    this.worldY = data.position.y;

    // Pick building sprite
    const textureKey = this.pickBuildingTexture(scene, data.roofColor);

    // Isometric shadow (flatter, wider)
    this.shadow = scene.add.graphics();
    this.shadow.fillStyle(0x000000, 0.15);
    this.shadow.fillEllipse(0, 30, 200, 50);
    this.add(this.shadow);

    if (textureKey) {
      this.houseSprite = scene.add.image(0, 0, textureKey)
        .setScale(BUILDING_SCALE)
        .setOrigin(0.5, 0.75);
      this.add(this.houseSprite);
    } else {
      // Procedural fallback — isometric barn shape
      const g = scene.add.graphics();
      this.drawFallbackBuilding(g, data.roofColor);
      this.add(g);
    }

    // Small icon above building
    const iconName = data.icon || HOUSE_EMOJI_TO_ICON[data.emoji] || 'house';
    const iconTextureKey = 'icon-' + iconName;
    if (scene.textures.exists(iconTextureKey)) {
      this.iconDisplay = scene.add.image(0, -130, iconTextureKey)
        .setDisplaySize(36, 36).setOrigin(0.5, 0.5);
    } else {
      const fallback = ICON_FALLBACK[iconName] || data.emoji || '🏠';
      this.iconDisplay = scene.add.text(0, -130, fallback, {
        fontSize: '22px',
      }).setOrigin(0.5, 0.5);
    }
    this.add(this.iconDisplay);

    // Name label below building
    this.nameText = scene.add.text(0, 65, data.name || '', {
      fontSize: '15px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      align: 'center',
      rtl: true,
      stroke: '#000000',
      strokeThickness: 3,
    }).setOrigin(0.5, 0.5);
    this.add(this.nameText);

    // Isometric depth sorting
    this.setDepth(isoDepth(data.position.x, data.position.y, 4));
    scene.add.existing(this);

    this.setActivityMode(data.isActive);
  }

  setActivityMode(active: boolean) {
    if (active && !this.activePulse && this.houseSprite) {
      this.activePulse = this.scene.tweens.add({
        targets: this.houseSprite,
        scaleX: BUILDING_SCALE * 1.03,
        scaleY: BUILDING_SCALE * 1.03,
        duration: 800,
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      });
    } else if (!active && this.activePulse) {
      this.activePulse.stop();
      this.activePulse = null;
      if (this.houseSprite) {
        this.houseSprite.setScale(BUILDING_SCALE);
      }
    }
  }

  private pickBuildingTexture(scene: Phaser.Scene, roofColor?: string): string | null {
    // Try farm building textures first
    if (roofColor) {
      const r = parseInt(roofColor.slice(1, 3), 16);
      const g = parseInt(roofColor.slice(3, 5), 16);
      const b = parseInt(roofColor.slice(5, 7), 16);

      let colorKey = 'brown';
      if (r > g && r > b) colorKey = 'red';
      else if (b > r && b > g) colorKey = 'blue';
      else if (g > r && g > b) colorKey = 'green';

      const farmKey = FARM_BUILDING_MAP[colorKey];
      if (farmKey && scene.textures.exists(farmKey)) return farmKey;
    }

    // Fallback to farm textures
    const farmAvailable = FARM_TEXTURES.filter(t => scene.textures.exists(t));
    if (farmAvailable.length > 0) {
      return farmAvailable[Math.floor(Math.random() * farmAvailable.length)];
    }

    // Fallback to old house textures
    const available = HOUSE_TEXTURES.filter(t => scene.textures.exists(t));
    if (available.length > 0) {
      return available[Math.floor(Math.random() * available.length)];
    }

    return null;
  }

  /** Draw a simple isometric barn when no sprite is available */
  private drawFallbackBuilding(g: Phaser.GameObjects.Graphics, roofColor?: string) {
    const color = roofColor ? parseInt(roofColor.replace('#', ''), 16) : 0xCC4444;
    const wallColor = 0xDDC8A0;

    // Front wall (isometric parallelogram)
    g.fillStyle(wallColor, 1);
    g.beginPath();
    g.moveTo(-40, 0);    // bottom-left
    g.lineTo(0, 20);     // bottom-center
    g.lineTo(0, -40);    // top-center
    g.lineTo(-40, -60);  // top-left
    g.closePath();
    g.fillPath();

    // Right wall (darker)
    g.fillStyle(0xC4B08A, 1);
    g.beginPath();
    g.moveTo(0, 20);     // bottom-center
    g.lineTo(40, 0);     // bottom-right
    g.lineTo(40, -60);   // top-right
    g.lineTo(0, -40);    // top-center
    g.closePath();
    g.fillPath();

    // Roof
    g.fillStyle(color, 1);
    g.beginPath();
    g.moveTo(-50, -60);  // left eave
    g.lineTo(0, -90);    // peak
    g.lineTo(50, -60);   // right eave
    g.lineTo(0, -40);    // center bottom
    g.closePath();
    g.fillPath();

    // Roof right side
    g.fillStyle(color - 0x222222, 1);
    g.beginPath();
    g.moveTo(0, -90);    // peak
    g.lineTo(50, -60);   // right eave
    g.lineTo(0, -40);    // center bottom
    g.closePath();
    g.fillPath();

    // Door
    g.fillStyle(0x6B4226, 1);
    g.fillRect(-12, -10, 12, 20);

    // Window
    g.fillStyle(0x88BBEE, 0.8);
    g.fillRect(12, -30, 10, 10);
    g.lineStyle(1, 0x6B4226, 0.8);
    g.strokeRect(12, -30, 10, 10);
  }

  setNightMode(isNight: boolean) {
    if (this.houseSprite) {
      if (isNight) {
        this.houseSprite.setTint(0x8888cc);
      } else {
        this.houseSprite.clearTint();
      }
    }

    if (isNight) {
      if (!this.windowGlow) {
        this.windowGlow = this.scene.add.graphics();
        this.addAt(this.windowGlow as unknown as Phaser.GameObjects.GameObject, 1);
      }
      this.windowGlow.clear();
      this.windowGlow.fillStyle(0xff9933, 0.06);
      this.windowGlow.fillCircle(0, -20, 100);
      this.windowGlow.fillStyle(0xffaa44, 0.10);
      this.windowGlow.fillCircle(0, -20, 60);
      this.windowGlow.fillStyle(0xffcc66, 0.15);
      this.windowGlow.fillCircle(0, -20, 30);
      this.windowGlow.fillStyle(0xffe088, 0.25);
      this.windowGlow.fillRect(-16, -32, 10, 10);
      this.windowGlow.fillRect(6, -32, 10, 10);
      this.windowGlow.setVisible(true);
    } else {
      if (this.windowGlow) {
        this.windowGlow.setVisible(false);
      }
    }
  }
}
