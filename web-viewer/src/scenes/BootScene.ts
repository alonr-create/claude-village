import Phaser from 'phaser';
import { ICON_NAMES } from '../config/constants';

export class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  preload() {
    // Create loading bar
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;

    const barBg = this.add.rectangle(width / 2, height / 2, 300, 20, 0x333333);
    const barFill = this.add.rectangle(width / 2 - 148, height / 2, 0, 16, 0x4ecdc4);
    barFill.setOrigin(0, 0.5);

    const loadText = this.add.text(width / 2, height / 2 - 40, 'Claude Village v4.0', {
      fontSize: '20px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
    }).setOrigin(0.5);

    const progressText = this.add.text(width / 2, height / 2 + 30, 'טוען...', {
      fontSize: '12px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: 'rgba(255,255,255,0.6)',
    }).setOrigin(0.5);

    this.load.on('progress', (value: number) => {
      barFill.width = 296 * value;
      progressText.setText(Math.round(value * 100) + '%');
    });

    this.load.on('complete', () => {
      barBg.destroy();
      barFill.destroy();
      loadText.destroy();
      progressText.destroy();
    });

    // Preload all icon images
    for (const name of ICON_NAMES) {
      this.load.image('icon-' + name, '/icons/' + name + '.png');
    }

    // Pixel art assets
    this.load.image('village-ground', '/assets/tilesets/village-ground.png');
    this.load.image('panel-bg', '/assets/ui/panel-bg.png');

    // Ambient audio
    this.load.audio('ambient', '/village-ambient.mp3');
  }

  create() {
    // Start both main scenes simultaneously
    this.scene.start('VillageScene');
    this.scene.launch('HUDScene');
  }
}
