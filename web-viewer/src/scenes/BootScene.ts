import Phaser from 'phaser';
import { ICON_NAMES } from '../config/constants';

export class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  preload() {
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;

    // Loading background
    this.load.image('loading-bg', '/assets/ui/loading-bg.png');

    this.load.once('filecomplete-image-loading-bg', () => {
      const bg = this.add.image(width / 2, height / 2, 'loading-bg');
      const scaleX = width / bg.width;
      const scaleY = height / bg.height;
      bg.setScale(Math.max(scaleX, scaleY));
      bg.setDepth(0);

      const overlay = this.add.rectangle(width / 2, height / 2, width, height, 0x000000, 0.45);
      overlay.setDepth(1);
    });

    // Loading bar
    const barBg = this.add.rectangle(width / 2, height / 2 + 30, 300, 12, 0x000000, 0.5).setDepth(10);
    const barBorder = this.add.rectangle(width / 2, height / 2 + 30, 302, 14)
      .setStrokeStyle(1, 0xffffff, 0.3).setDepth(10);
    const barFill = this.add.rectangle(width / 2 - 148, height / 2 + 30, 0, 10, 0x4CAF50)
      .setOrigin(0, 0.5).setDepth(11);

    const loadText = this.add.text(width / 2, height / 2 - 20, 'Claude Farm', {
      fontSize: '28px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      fontStyle: 'bold',
    }).setOrigin(0.5).setDepth(10);

    const loadTextShadow = this.add.text(width / 2 + 2, height / 2 - 18, 'Claude Farm', {
      fontSize: '28px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#000000',
      fontStyle: 'bold',
    }).setOrigin(0.5).setAlpha(0.3).setDepth(9);

    const progressText = this.add.text(width / 2, height / 2 + 55, 'טוען...', {
      fontSize: '13px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: 'rgba(255,255,255,0.7)',
    }).setOrigin(0.5).setDepth(10);

    this.load.on('progress', (value: number) => {
      barFill.width = 296 * value;
      progressText.setText(Math.round(value * 100) + '%');
    });

    this.load.on('complete', () => {
      barBg.destroy();
      barBorder.destroy();
      barFill.destroy();
      loadText.destroy();
      loadTextShadow.destroy();
      progressText.destroy();
    });

    // Preload all icon images
    for (const name of ICON_NAMES) {
      this.load.image('icon-' + name, '/icons/' + name + '.png');
    }

    // === ISOMETRIC FARM ASSETS ===

    // Farm tileset (isometric tiles — 128x64 each, spritesheet)
    this.load.spritesheet('farm-tileset', '/assets/tilesets/farm-tileset.png', {
      frameWidth: 128,
      frameHeight: 64,
    });

    // Legacy ground tile (fallback)
    this.load.image('village-ground', '/assets/tilesets/village-ground.png');
    this.load.image('panel-bg', '/assets/ui/panel-bg.png');

    // Farm building sprites (isometric)
    this.load.image('barn-red-iso', '/assets/sprites/barn-red-iso.png');
    this.load.image('farmhouse-blue-iso', '/assets/sprites/farmhouse-blue-iso.png');
    this.load.image('silo-green-iso', '/assets/sprites/silo-green-iso.png');
    this.load.image('windmill-brown-iso', '/assets/sprites/windmill-brown-iso.png');

    // Fallback to old house sprites
    this.load.image('house-red', '/assets/sprites/house-red.png');
    this.load.image('house-blue', '/assets/sprites/house-blue.png');
    this.load.image('house-green', '/assets/sprites/house-green.png');
    this.load.image('house-brown', '/assets/sprites/house-brown.png');

    // Farm tree sprites (isometric)
    this.load.image('tree-apple-iso', '/assets/sprites/tree-apple-iso.png');
    this.load.image('tree-oak-iso', '/assets/sprites/tree-oak-iso.png');
    this.load.image('tree-pine-iso', '/assets/sprites/tree-pine-iso.png');
    this.load.image('tree-cherry-iso', '/assets/sprites/tree-cherry-iso.png');
    this.load.image('tree-autumn-iso', '/assets/sprites/tree-autumn-iso.png');

    // Fallback to old tree sprites
    this.load.image('tree-oak', '/assets/sprites/tree-oak.png');
    this.load.image('tree-pine', '/assets/sprites/tree-pine.png');
    this.load.image('tree-autumn', '/assets/sprites/tree-autumn.png');
    this.load.image('tree-birch', '/assets/sprites/tree-birch.png');

    // Farm decorations (isometric)
    this.load.image('bush-iso', '/assets/sprites/bush-iso.png');
    this.load.image('rock-iso', '/assets/sprites/rock-iso.png');
    this.load.image('fence-iso', '/assets/sprites/fence-iso.png');
    this.load.image('haystack-iso', '/assets/sprites/haystack-iso.png');
    this.load.image('scarecrow-iso', '/assets/sprites/scarecrow-iso.png');
    this.load.image('water-well-iso', '/assets/sprites/water-well-iso.png');
    this.load.image('flowerbed-iso', '/assets/sprites/flowerbed-iso.png');
    this.load.image('animal-iso', '/assets/sprites/animal-iso.png');

    // Fallback old decoration sprites
    this.load.image('sprite-bush', '/assets/sprites/bush.png');
    this.load.image('sprite-rock', '/assets/sprites/rock.png');
    this.load.image('sprite-fountain', '/assets/sprites/fountain.png');

    // Ambient audio
    this.load.audio('ambient', '/village-ambient.mp3');
  }

  create() {
    // Set LINEAR filter on all loaded textures (illustrated style, not pixel art)
    const allKeys = [
      ...ICON_NAMES.map(n => 'icon-' + n),
      'barn-red-iso', 'farmhouse-blue-iso', 'silo-green-iso', 'windmill-brown-iso',
      'house-red', 'house-blue', 'house-green', 'house-brown',
      'tree-apple-iso', 'tree-oak-iso', 'tree-pine-iso', 'tree-cherry-iso', 'tree-autumn-iso',
      'tree-oak', 'tree-pine', 'tree-autumn', 'tree-birch',
      'bush-iso', 'rock-iso', 'fence-iso', 'haystack-iso', 'scarecrow-iso',
      'water-well-iso', 'flowerbed-iso', 'animal-iso',
      'sprite-bush', 'sprite-rock', 'sprite-fountain',
    ];

    for (const key of allKeys) {
      if (this.textures.exists(key)) {
        this.textures.get(key).setFilter(Phaser.Textures.FilterMode.LINEAR);
      }
    }

    // Start both main scenes
    this.scene.start('VillageScene');
    this.scene.launch('HUDScene');
  }
}
