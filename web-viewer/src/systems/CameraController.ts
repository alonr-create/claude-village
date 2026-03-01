import Phaser from 'phaser';
import { WORLD_SIZE } from '../config/constants';

export class CameraController {
  private scene: Phaser.Scene;
  private isDragging = false;
  private dragStartX = 0;
  private dragStartY = 0;
  private camStartX = 0;
  private camStartY = 0;
  private dragDist = 0;
  private pinchStartDist = 0;
  private pinchStartZoom = 1;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    const cam = scene.cameras.main;

    // Set world bounds
    cam.setBounds(
      -WORLD_SIZE - 100, -WORLD_SIZE - 100,
      (WORLD_SIZE + 100) * 2, (WORLD_SIZE + 100) * 2,
    );
    cam.zoom = 0.65;
    cam.centerOn(0, 0);

    // Mouse drag
    scene.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      if (pointer.rightButtonDown()) return;
      this.isDragging = true;
      this.dragDist = 0;
      this.dragStartX = pointer.x;
      this.dragStartY = pointer.y;
      this.camStartX = cam.scrollX;
      this.camStartY = cam.scrollY;
    });

    scene.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (!this.isDragging || !pointer.isDown) return;
      const dx = pointer.x - this.dragStartX;
      const dy = pointer.y - this.dragStartY;
      this.dragDist = Math.hypot(dx, dy);
      cam.scrollX = this.camStartX - dx / cam.zoom;
      cam.scrollY = this.camStartY - dy / cam.zoom;
    });

    scene.input.on('pointerup', () => {
      this.isDragging = false;
    });

    // Mouse wheel zoom
    scene.input.on('wheel', (_pointer: Phaser.Input.Pointer, _gameObjects: Phaser.GameObjects.GameObject[], _deltaX: number, deltaY: number) => {
      const factor = deltaY > 0 ? 0.92 : 1.08;
      cam.zoom = Phaser.Math.Clamp(cam.zoom * factor, 0.15, 3);
    });
  }

  wasDrag(): boolean {
    return this.dragDist > 5;
  }

  focusOn(worldX: number, worldY: number) {
    const cam = this.scene.cameras.main;
    cam.pan(worldX, worldY, 300, 'Power2');
    if (cam.zoom < 1) {
      cam.zoomTo(1.2, 300, 'Power2');
    }
  }
}
