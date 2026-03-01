import Phaser from 'phaser';
import { WORLD_SIZE } from '../config/constants';
import { cartToIso } from './IsometricUtils';

export class CameraController {
  private scene: Phaser.Scene;
  private isDragging = false;
  private dragStartX = 0;
  private dragStartY = 0;
  private camStartX = 0;
  private camStartY = 0;
  private dragDist = 0;
  private minZoom = 0.1;

  // Isometric world extents
  private isoExtentX: number;
  private isoExtentY: number;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    const cam = scene.cameras.main;

    // Isometric world bounds — the diamond is wider and shorter
    this.isoExtentX = WORLD_SIZE * 2;
    this.isoExtentY = WORLD_SIZE;

    this.minZoom = this.calcMinZoom(cam);

    cam.setBounds(
      -this.isoExtentX, -this.isoExtentY,
      this.isoExtentX * 2, this.isoExtentY * 2,
    );
    cam.zoom = Math.max(this.minZoom, 0.8);
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
      cam.zoom = Phaser.Math.Clamp(cam.zoom * factor, this.minZoom, 3);
    });

    // Recalculate on resize
    scene.scale.on('resize', () => {
      this.minZoom = this.calcMinZoom(cam);
      if (cam.zoom < this.minZoom) {
        cam.zoom = this.minZoom;
      }
    });
  }

  private calcMinZoom(cam: Phaser.Cameras.Scene2D.Camera): number {
    const zoomW = cam.width / (this.isoExtentX * 2);
    const zoomH = cam.height / (this.isoExtentY * 2);
    return Math.max(zoomW, zoomH);
  }

  wasDrag(): boolean {
    return this.dragDist > 5;
  }

  /** Focus camera on a point (already in isometric screen coords) */
  focusOn(isoX: number, isoY: number) {
    const cam = this.scene.cameras.main;
    cam.pan(isoX, isoY, 300, 'Power2');
    if (cam.zoom < 0.8) {
      cam.zoomTo(1.0, 300, 'Power2');
    }
  }

  /** Focus camera on a point given in Cartesian world coordinates */
  focusOnWorld(worldX: number, worldY: number) {
    const iso = cartToIso(worldX, worldY);
    this.focusOn(iso.x, iso.y);
  }
}
