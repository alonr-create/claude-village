import Phaser from 'phaser';
import { AgentSnapshot } from '../types/snapshot';
import { PredictedPosition } from '../systems/PredictionEngine';
import { SpeechBubble } from './SpeechBubble';
import { ICON_FALLBACK, MOOD_EMOJI_TO_ICON } from '../config/constants';

export class CrabAgent extends Phaser.GameObjects.Container {
  private crabBody: Phaser.GameObjects.Graphics;
  private shadow: Phaser.GameObjects.Graphics;
  private nameLabel: Phaser.GameObjects.Container;
  private moodIcon: Phaser.GameObjects.Text; // emoji fallback
  private stateIcon: Phaser.GameObjects.Text; // emoji fallback
  private speechBubble: SpeechBubble | null = null;

  private agentId: string;
  private color: number;
  private colorHex: string;
  private isMoving = false;
  private walkPhase = 0;
  private blinkTimer = 0;
  private nextBlink: number;
  private blinking = false;
  private blinkEnd = 0;
  private lastSpeech: string | null = null;

  // State tracking
  private currentState = 'idle';
  private currentMoodEmoji = '';

  constructor(scene: Phaser.Scene, data: AgentSnapshot) {
    super(scene, data.position.x, -data.position.y);
    this.agentId = data.id;
    this.colorHex = data.badgeColor || '#E8734A';
    this.color = parseInt(this.colorHex.replace('#', ''), 16);
    this.nextBlink = scene.time.now + 3000 + Math.random() * 3000;

    // Shadow
    this.shadow = scene.add.graphics();
    this.shadow.fillStyle(0x000000, 0.25);
    this.shadow.fillEllipse(0, 18, 32, 10);
    this.add(this.shadow);

    // Body graphics (drawn procedurally like the original)
    this.crabBody = scene.add.graphics();
    this.add(this.crabBody);

    // Name label
    this.nameLabel = this.createNameLabel(scene, data.name, this.color, this.colorHex);
    this.add(this.nameLabel);

    // Mood icon
    this.moodIcon = scene.add.text(22, -14, '', {
      fontSize: '12px',
    }).setOrigin(0.5, 0.5);
    this.add(this.moodIcon);

    // State icon
    this.stateIcon = scene.add.text(-22, -14, '', {
      fontSize: '11px',
    }).setOrigin(0.5, 0.5);
    this.add(this.stateIcon);

    this.setDepth(10);
    scene.add.existing(this as unknown as Phaser.GameObjects.GameObject);
  }

  private createNameLabel(scene: Phaser.Scene, name: string, _color: number, colorHex: string): Phaser.GameObjects.Container {
    const container = new Phaser.GameObjects.Container(scene, 0, 25);

    const text = scene.add.text(0, 0, name, {
      fontSize: '9px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      align: 'center',
      rtl: true,
    }).setOrigin(0.5, 0.5);

    const bg = scene.add.graphics();
    const w = text.width + 12;
    const h = 16;
    bg.fillStyle(parseInt(colorHex.replace('#', ''), 16), 0.8);
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 6);

    container.add([bg, text]);
    return container;
  }

  updateFromSnapshot(data: AgentSnapshot, time: number) {
    // Update mood icon
    if (data.moodEmoji !== this.currentMoodEmoji) {
      this.currentMoodEmoji = data.moodEmoji;
      this.moodIcon.setText(data.moodEmoji || '');
    }

    // Update state icon
    if (data.state !== this.currentState) {
      this.currentState = data.state;
      const stateIcons: Record<string, string> = {
        work: ICON_FALLBACK['state-work'] || '💻',
        build: ICON_FALLBACK['state-build'] || '🔨',
        eat: ICON_FALLBACK['state-eat'] || '🍽',
        eating: ICON_FALLBACK['state-eat'] || '🍽',
        rest: ICON_FALLBACK['state-sleep'] || '💤',
        socialize: ICON_FALLBACK['state-socialize'] || '💬',
        explore: ICON_FALLBACK['state-explore'] || '🚶',
        request: ICON_FALLBACK['state-request'] || '📋',
      };
      this.stateIcon.setText(data.state !== 'idle' ? (stateIcons[data.state] || '') : '');
    }

    // Update speech bubble
    if (data.currentSpeech && data.currentSpeech !== this.lastSpeech) {
      this.lastSpeech = data.currentSpeech;
      if (this.speechBubble) {
        this.speechBubble.setText(data.currentSpeech);
      } else {
        this.speechBubble = new SpeechBubble(this.scene, data.currentSpeech, this.colorHex);
        this.speechBubble.setPosition(0, -45);
        this.add(this.speechBubble);
      }
    } else if (!data.currentSpeech && this.speechBubble) {
      this.speechBubble.destroy();
      this.speechBubble = null;
      this.lastSpeech = null;
    }
  }

  updateAnimation(predicted: PredictedPosition, time: number) {
    const speed = Math.sqrt(predicted.vx ** 2 + predicted.vy ** 2);
    this.isMoving = speed > 2;

    // Update position
    this.setPosition(predicted.x, -predicted.y);

    // Walk phase
    if (this.isMoving) {
      this.walkPhase = time * 0.008 + this.agentId.charCodeAt(0);
    }

    // Blink logic
    if (time >= this.nextBlink && !this.blinking) {
      this.blinking = true;
      this.blinkEnd = time + 120;
    }
    if (this.blinking && time >= this.blinkEnd) {
      this.blinking = false;
      this.nextBlink = time + 3000 + Math.random() * 3000;
    }

    // Redraw the crab body
    this.drawCrab(time, predicted);

    // Update speech bubble pulse
    if (this.speechBubble) {
      this.speechBubble.updatePulse(time);
    }
  }

  private drawCrab(time: number, predicted: PredictedPosition) {
    const g = this.crabBody;
    g.clear();

    const t = time * 0.001;
    const walkBob = this.isMoving
      ? Math.sin(this.walkPhase) * 2.5
      : Math.sin(t * 1.5 + this.agentId.charCodeAt(0) * 0.5) * 1;
    const legWiggle = this.isMoving ? Math.sin(this.walkPhase) * 0.35 : 0;
    const bodyY = walkBob;
    const eyeOpen = !this.blinking;

    // Legs (3 per side)
    g.lineStyle(1.8, this.color, 1);
    for (let i = 0; i < 3; i++) {
      const ly = bodyY - 2 + i * 5;
      const phase = this.walkPhase + i * 1.2;
      const lw = this.isMoving ? Math.sin(phase) * 4 : 0;
      // Left legs
      g.beginPath();
      g.moveTo(-14, ly);
      g.lineTo(-22 - lw, ly + 5 + Math.abs(lw) * 0.3);
      g.strokePath();
      // Right legs
      g.beginPath();
      g.moveTo(14, ly);
      g.lineTo(22 + lw, ly + 5 + Math.abs(lw) * 0.3);
      g.strokePath();
    }

    // Body (crab-like oval)
    g.fillStyle(this.color, 1);
    g.fillEllipse(0, bodyY, 30, 22);
    g.lineStyle(1.5, 0x000000, 0.25);
    g.strokeEllipse(0, bodyY, 30, 22);

    // Body highlight
    g.fillStyle(0xffffff, 0.15);
    g.fillEllipse(-3, bodyY - 3, 16, 10);

    // Claws
    g.lineStyle(2.8, this.color, 1);
    // Left claw
    g.beginPath();
    g.moveTo(-15, bodyY - 4);
    g.lineTo(-23 + legWiggle * 5, bodyY - 11);
    g.strokePath();
    g.beginPath();
    g.moveTo(-23 + legWiggle * 5, bodyY - 11);
    g.lineTo(-19 + legWiggle * 5, bodyY - 7);
    g.strokePath();
    g.beginPath();
    g.moveTo(-23 + legWiggle * 5, bodyY - 11);
    g.lineTo(-25 + legWiggle * 5, bodyY - 5);
    g.strokePath();
    // Right claw
    g.beginPath();
    g.moveTo(15, bodyY - 4);
    g.lineTo(23 - legWiggle * 5, bodyY - 11);
    g.strokePath();
    g.beginPath();
    g.moveTo(23 - legWiggle * 5, bodyY - 11);
    g.lineTo(19 - legWiggle * 5, bodyY - 7);
    g.strokePath();
    g.beginPath();
    g.moveTo(23 - legWiggle * 5, bodyY - 11);
    g.lineTo(25 - legWiggle * 5, bodyY - 5);
    g.strokePath();

    // Eye stalks
    g.lineStyle(2, this.color, 1);
    g.beginPath();
    g.moveTo(-5, bodyY - 8);
    g.lineTo(-6, bodyY - 15);
    g.strokePath();
    g.beginPath();
    g.moveTo(5, bodyY - 8);
    g.lineTo(6, bodyY - 15);
    g.strokePath();

    const eyeY = bodyY - 15;

    if (eyeOpen) {
      // Eye whites
      g.fillStyle(0xffffff, 1);
      g.fillCircle(-6, eyeY, 4);
      g.fillCircle(6, eyeY, 4);
      g.lineStyle(0.5, 0x000000, 0.3);
      g.strokeCircle(-6, eyeY, 4);
      g.strokeCircle(6, eyeY, 4);

      // Pupils — track movement direction
      let pupilDx = 0, pupilDy = 0;
      if (this.isMoving) {
        const dir = Math.atan2(predicted.vy, predicted.vx);
        pupilDx = Math.cos(dir) * 1.5;
        pupilDy = -Math.sin(dir) * 1.5;
      }
      g.fillStyle(0x111111, 1);
      g.fillCircle(-6 + pupilDx, eyeY + pupilDy, 2);
      g.fillCircle(6 + pupilDx, eyeY + pupilDy, 2);

      // Eye glint
      g.fillStyle(0xffffff, 0.7);
      g.fillCircle(-5 + pupilDx, eyeY - 1 + pupilDy, 0.8);
      g.fillCircle(7 + pupilDx, eyeY - 1 + pupilDy, 0.8);
    } else {
      // Closed eyes — horizontal lines
      g.lineStyle(1.5, 0x333333, 1);
      g.beginPath();
      g.moveTo(-9, eyeY);
      g.lineTo(-3, eyeY);
      g.strokePath();
      g.beginPath();
      g.moveTo(3, eyeY);
      g.lineTo(9, eyeY);
      g.strokePath();
    }

    // Badge on body
    g.fillStyle(0xffffff, 0.9);
    g.fillCircle(0, bodyY + 1, 5);
  }

  getId(): string {
    return this.agentId;
  }
}
