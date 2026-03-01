import Phaser from 'phaser';
import { BootScene } from './scenes/BootScene';
import { VillageScene } from './scenes/VillageScene';
import { HUDScene } from './scenes/HUDScene';

const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  parent: 'game-container',
  width: window.innerWidth,
  height: window.innerHeight,
  backgroundColor: '#1a2e1a',
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [BootScene, VillageScene, HUDScene],
  dom: {
    createContainer: true,
  },
  input: {
    touch: {
      capture: true,
    },
  },
  render: {
    pixelArt: true,
    antialias: false,
    roundPixels: true,
  },
  fps: {
    target: 60,
    forceSetTimeOut: false,
  },
};

new Phaser.Game(config);
