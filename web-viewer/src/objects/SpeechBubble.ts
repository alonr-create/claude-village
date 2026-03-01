import Phaser from 'phaser';

export class SpeechBubble extends Phaser.GameObjects.Container {
  private bg: Phaser.GameObjects.Graphics;
  private textObj: Phaser.GameObjects.Text;
  private pointer: Phaser.GameObjects.Graphics;
  private color: number;
  private pulseTime = 0;

  constructor(scene: Phaser.Scene, text: string, color: string) {
    super(scene, 0, 0);
    this.color = parseInt(color.replace('#', ''), 16) || 0xe8734a;

    const displayText = text.length > 35 ? text.substring(0, 35) + '...' : text;

    // Text
    this.textObj = scene.add.text(0, 0, displayText, {
      fontSize: '10px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#222222',
      align: 'center',
      maxLines: 1,
      rtl: true,
    }).setOrigin(0.5, 0.5);

    const textW = Math.min(this.textObj.width + 20, 180);
    const textH = 26;

    // Background bubble
    this.bg = scene.add.graphics();
    this.drawBubble(textW, textH, 0.4);

    // Pointer triangle
    this.pointer = scene.add.graphics();
    this.pointer.fillStyle(0xffffff, 0.93);
    this.pointer.fillTriangle(-5, textH / 2, 5, textH / 2, 0, textH / 2 + 7);

    this.add([this.bg, this.pointer, this.textObj]);
    scene.add.existing(this);
  }

  private drawBubble(w: number, h: number, pulseAlpha: number) {
    this.bg.clear();
    // White background
    this.bg.fillStyle(0xffffff, 0.93);
    this.bg.fillRoundedRect(-w / 2, -h / 2, w, h, 10);
    // Colored border
    this.bg.lineStyle(1.5, this.color, pulseAlpha);
    this.bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 10);
  }

  updatePulse(time: number) {
    this.pulseTime = time;
    const pulseAlpha = 0.4 + Math.sin(time * 0.005) * 0.2;
    const textW = Math.min(this.textObj.width + 20, 180);
    this.drawBubble(textW, 26, pulseAlpha);
  }

  setText(text: string) {
    const displayText = text.length > 35 ? text.substring(0, 35) + '...' : text;
    this.textObj.setText(displayText);
  }
}
