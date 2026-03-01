/**
 * FarmerAgent — Isometric farmer character (replaces CrabAgent).
 * Uses spritesheet animation with 4 directions, or procedural drawing as fallback.
 */
import Phaser from 'phaser';
import { AgentSnapshot } from '../types/snapshot';
import { PredictedPosition } from '../systems/PredictionEngine';
import { SpeechBubble } from './SpeechBubble';
import { ICON_FALLBACK, MOOD_EMOJI_TO_ICON } from '../config/constants';
import { cartToIso, isoDepth, velocityToDirection } from '../systems/IsometricUtils';
import { ParticleManager } from '../systems/ParticleManager';

// State → icon key mapping
const STATE_ICON_MAP: Record<string, string> = {
  work: 'state-work', build: 'state-build',
  eat: 'state-eat', eating: 'state-eat',
  rest: 'state-sleep', socialize: 'state-socialize',
  explore: 'state-explore', request: 'state-request',
};

export class FarmerAgent extends Phaser.GameObjects.Container {
  private farmerBody: Phaser.GameObjects.Graphics;
  private shadow: Phaser.GameObjects.Graphics;
  private nameLabel: Phaser.GameObjects.Container;
  private moodIcon: Phaser.GameObjects.Image;
  private stateIcon: Phaser.GameObjects.Image;
  private speechBubble: SpeechBubble | null = null;

  private agentId: string;
  private color: number;
  private colorHex: string;
  private isMoving = false;
  private walkPhase = 0;
  private direction: 'se' | 'sw' | 'ne' | 'nw' = 'se';
  private lastSpeech: string | null = null;

  // State tracking
  private currentState = 'idle';
  private currentMoodEmoji = '';

  // Particle timers
  private nextDustTime = 0;
  private nextSleepZTime = 0;
  private nextHeartTime = 0;

  // Entrance animation
  private entranceComplete = false;

  // Reference to particle manager (set externally)
  particles: ParticleManager | null = null;

  // Store world coords for depth sorting
  private worldX = 0;
  private worldY = 0;

  constructor(scene: Phaser.Scene, data: AgentSnapshot) {
    const iso = cartToIso(data.position.x, data.position.y);
    super(scene, iso.x, iso.y);
    this.agentId = data.id;
    this.colorHex = data.badgeColor || '#E8734A';
    this.color = parseInt(this.colorHex.replace('#', ''), 16);
    this.worldX = data.position.x;
    this.worldY = data.position.y;

    // Shadow (isometric — flatter ellipse)
    this.shadow = scene.add.graphics();
    this.shadow.fillStyle(0x000000, 0.20);
    this.shadow.fillEllipse(0, 24, 48, 14);
    this.add(this.shadow);

    // Body graphics (procedural farmer drawing)
    this.farmerBody = scene.add.graphics();
    this.add(this.farmerBody);

    // Name label
    this.nameLabel = this.createNameLabel(scene, data.name, this.colorHex);
    this.add(this.nameLabel);

    // Mood icon
    this.moodIcon = scene.add.image(30, -30, '__DEFAULT')
      .setDisplaySize(20, 20).setOrigin(0.5, 0.5).setVisible(false);
    this.add(this.moodIcon);

    // State icon
    this.stateIcon = scene.add.image(-30, -30, '__DEFAULT')
      .setDisplaySize(18, 18).setOrigin(0.5, 0.5).setVisible(false);
    this.add(this.stateIcon);

    // Entrance animation
    this.setScale(0);
    scene.tweens.add({
      targets: this,
      scaleX: 1, scaleY: 1,
      duration: 400,
      ease: 'Back.easeOut',
      onComplete: () => { this.entranceComplete = true; },
    });

    // Initial depth
    this.setDepth(isoDepth(data.position.x, data.position.y, 10));
    scene.add.existing(this as unknown as Phaser.GameObjects.GameObject);
  }

  private createNameLabel(scene: Phaser.Scene, name: string, colorHex: string): Phaser.GameObjects.Container {
    const container = new Phaser.GameObjects.Container(scene, 0, 34);

    const text = scene.add.text(0, 0, name, {
      fontSize: '13px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      align: 'center',
      rtl: true,
    }).setOrigin(0.5, 0.5);

    const bg = scene.add.graphics();
    const w = text.width + 14;
    const h = 22;
    bg.fillStyle(parseInt(colorHex.replace('#', ''), 16), 0.85);
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 8);
    bg.lineStyle(1, 0xffffff, 0.2);
    bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 8);

    container.add([bg, text]);
    return container;
  }

  updateFromSnapshot(data: AgentSnapshot, time: number) {
    // Update mood icon
    if (data.moodEmoji !== this.currentMoodEmoji) {
      this.currentMoodEmoji = data.moodEmoji;
      const moodKey = MOOD_EMOJI_TO_ICON[data.moodEmoji];
      if (moodKey && this.scene.textures.exists('icon-' + moodKey)) {
        this.moodIcon.setTexture('icon-' + moodKey).setDisplaySize(18, 18).setVisible(true);
      } else {
        this.moodIcon.setVisible(false);
      }
    }

    // Update state icon
    if (data.state !== this.currentState) {
      this.currentState = data.state;
      const stateKey = STATE_ICON_MAP[data.state];
      if (data.state !== 'idle' && stateKey && this.scene.textures.exists('icon-' + stateKey)) {
        this.stateIcon.setTexture('icon-' + stateKey).setDisplaySize(16, 16).setVisible(true);
      } else {
        this.stateIcon.setVisible(false);
      }
    }

    // Update speech bubble
    if (data.currentSpeech && data.currentSpeech !== this.lastSpeech) {
      this.lastSpeech = data.currentSpeech;
      if (this.speechBubble) {
        this.speechBubble.setText(data.currentSpeech);
      } else {
        this.speechBubble = new SpeechBubble(this.scene, data.currentSpeech, this.colorHex);
        this.speechBubble.setPosition(0, -65);
        this.add(this.speechBubble);
      }
    } else if (!data.currentSpeech && this.speechBubble) {
      this.speechBubble.destroy();
      this.speechBubble = null;
      this.lastSpeech = null;
    }
  }

  updateAnimation(predicted: PredictedPosition, time: number) {
    const speed = predicted.currentSpeed ?? Math.sqrt(predicted.vx ** 2 + predicted.vy ** 2);
    this.isMoving = speed > 2;

    // Store world coords
    this.worldX = predicted.x;
    this.worldY = predicted.y;

    // Convert to isometric screen position
    const iso = cartToIso(predicted.x, predicted.y);
    this.setPosition(iso.x, iso.y);

    // Isometric depth sorting
    this.setDepth(isoDepth(predicted.x, predicted.y, 10));

    // Direction from velocity
    if (this.isMoving) {
      this.direction = velocityToDirection(predicted.vx, predicted.vy);
      this.walkPhase = time * 0.008 + this.agentId.charCodeAt(0);
    }

    // Particle effects
    if (this.particles && this.entranceComplete) {
      this.emitStateParticles(time, iso);
    }

    // Draw the farmer
    this.drawFarmer(time);

    // Update speech bubble
    if (this.speechBubble) {
      this.speechBubble.updatePulse(time);
    }
  }

  private emitStateParticles(time: number, iso: { x: number; y: number }) {
    if (!this.particles) return;

    // Walking dust
    if (this.isMoving && time > this.nextDustTime) {
      this.particles.dustBurst(iso.x, iso.y + 22, 3);
      this.nextDustTime = time + 400;
    }

    // Sleeping Z's
    if (this.currentState === 'rest' && time > this.nextSleepZTime) {
      this.particles.sleepZ(iso.x + 14, iso.y - 36);
      this.nextSleepZTime = time + 1200;
    }

    // Eating hearts
    if ((this.currentState === 'eat' || this.currentState === 'eating') && time > this.nextHeartTime) {
      this.particles.hearts(iso.x, iso.y - 30);
      this.nextHeartTime = time + 2000;
    }

    // Building sparks
    if (this.currentState === 'build' && time > this.nextDustTime) {
      this.particles.constructionDust(iso.x, iso.y + 8);
      this.nextDustTime = time + 600;
    }

    // Working sparkles
    if (this.currentState === 'work' && time > this.nextDustTime) {
      this.particles.sparkleBurst(iso.x + 18, iso.y - 10, 2);
      this.nextDustTime = time + 1500;
    }
  }

  /** Procedural farmer drawing — cartoony FarmVille style */
  private drawFarmer(time: number) {
    const g = this.farmerBody;
    g.clear();

    const t = time * 0.001;
    const state = this.currentState;

    // Animation parameters
    let walkBob = 0;
    let armSwing = 0;
    let bodyYOffset = 0;

    if (this.isMoving) {
      walkBob = Math.sin(this.walkPhase) * 3;
      armSwing = Math.sin(this.walkPhase) * 0.4;
    } else if (state === 'rest') {
      bodyYOffset = 8;
      walkBob = Math.sin(t * 0.5) * 2;
    } else if (state === 'eat' || state === 'eating') {
      walkBob = Math.sin(t * 3) * 2;
      armSwing = Math.sin(t * 4) * 0.3;
    } else if (state === 'work') {
      walkBob = Math.sin(t * 2) * 1.5;
      armSwing = Math.sin(t * 5) * 0.2;
    } else if (state === 'build') {
      walkBob = Math.abs(Math.sin(t * 4)) * 3;
      armSwing = Math.sin(t * 4) * 0.35;
    } else {
      walkBob = Math.sin(t * 1.2 + this.agentId.charCodeAt(0) * 0.5) * 1;
    }

    const by = walkBob + bodyYOffset;

    // Direction-based offsets for facing
    const facingRight = this.direction === 'se' || this.direction === 'ne';
    const dirMul = facingRight ? 1 : -1;

    // === LEGS ===
    const legSpread = 5;
    const leftLegX = -legSpread;
    const rightLegX = legSpread;
    const legY = by + 10;
    const footY = by + 22;

    // Left leg
    g.lineStyle(4, 0x3366AA, 1); // blue jeans
    g.beginPath();
    g.moveTo(leftLegX, legY);
    const lLegOff = this.isMoving ? Math.sin(this.walkPhase) * 6 : 0;
    g.lineTo(leftLegX + lLegOff * 0.5, footY + lLegOff * 0.5);
    g.strokePath();

    // Right leg
    g.beginPath();
    g.moveTo(rightLegX, legY);
    const rLegOff = this.isMoving ? -Math.sin(this.walkPhase) * 6 : 0;
    g.lineTo(rightLegX + rLegOff * 0.5, footY + rLegOff * 0.5);
    g.strokePath();

    // Boots
    g.fillStyle(0x8B4513, 1); // brown boots
    g.fillCircle(leftLegX + lLegOff * 0.5, footY + lLegOff * 0.5 + 2, 4);
    g.fillCircle(rightLegX + rLegOff * 0.5, footY + rLegOff * 0.5 + 2, 4);

    // === BODY (overall/shirt) ===
    // Overalls base
    g.fillStyle(0x3366AA, 1); // blue overalls
    g.fillRoundedRect(-10, by - 2, 20, 16, 3);

    // Shirt
    g.fillStyle(this.color, 1); // Agent's badge color as shirt
    g.fillRoundedRect(-11, by - 12, 22, 14, 4);

    // Overall straps
    g.lineStyle(2, 0x3366AA, 1);
    g.beginPath();
    g.moveTo(-6, by - 2);
    g.lineTo(-5, by - 10);
    g.strokePath();
    g.beginPath();
    g.moveTo(6, by - 2);
    g.lineTo(5, by - 10);
    g.strokePath();

    // === ARMS ===
    g.lineStyle(3.5, this.color, 1);
    // Left arm
    const leftArmAngle = armSwing * dirMul;
    g.beginPath();
    g.moveTo(-11, by - 6);
    g.lineTo(-18 + leftArmAngle * 10, by + 2 + Math.abs(leftArmAngle) * 8);
    g.strokePath();
    // Hand
    g.fillStyle(0xFFDBAC, 1); // skin
    g.fillCircle(-18 + leftArmAngle * 10, by + 4 + Math.abs(leftArmAngle) * 8, 3);

    // Right arm
    const rightArmAngle = -armSwing * dirMul;
    g.beginPath();
    g.moveTo(11, by - 6);
    g.lineTo(18 + rightArmAngle * 10, by + 2 + Math.abs(rightArmAngle) * 8);
    g.strokePath();
    // Hand
    g.fillCircle(18 + rightArmAngle * 10, by + 4 + Math.abs(rightArmAngle) * 8, 3);

    // === HEAD ===
    const headY = by - 22;

    // Neck
    g.fillStyle(0xFFDBAC, 1); // skin tone
    g.fillRect(-3, by - 14, 6, 5);

    // Head (round)
    g.fillStyle(0xFFDBAC, 1);
    g.fillCircle(0, headY, 10);
    g.lineStyle(0.8, 0xD4A574, 0.4);
    g.strokeCircle(0, headY, 10);

    // Straw hat
    g.fillStyle(0xDAA520, 1); // golden straw
    // Hat top
    g.fillEllipse(0, headY - 8, 14, 8);
    // Hat brim (wide)
    g.fillStyle(0xC8961E, 1);
    g.fillEllipse(0, headY - 4, 24, 6);
    // Hat band
    g.fillStyle(0x8B0000, 1); // dark red band
    g.fillRect(-7, headY - 7, 14, 2);

    // Face based on state
    if (state === 'rest') {
      // Sleeping — closed eyes, peaceful smile
      g.lineStyle(1.5, 0x333333, 1);
      g.beginPath(); g.moveTo(-5, headY); g.lineTo(-2, headY); g.strokePath();
      g.beginPath(); g.moveTo(2, headY); g.lineTo(5, headY); g.strokePath();
      // Peaceful smile
      g.lineStyle(1, 0x333333, 0.6);
      g.beginPath();
      g.arc(0, headY + 3, 3, 0, Math.PI);
      g.strokePath();
    } else {
      // Eyes — dot style
      const lookX = facingRight ? 1 : -1;
      g.fillStyle(0x333333, 1);
      g.fillCircle(-4 + lookX, headY, 1.8);
      g.fillCircle(4 + lookX, headY, 1.8);

      // Smile / expression
      if (state === 'eat' || state === 'eating') {
        // Open mouth eating
        g.fillStyle(0x333333, 0.8);
        g.fillCircle(0, headY + 4, 2.5);
      } else if (state === 'socialize') {
        // Happy talking mouth
        g.lineStyle(1.2, 0x333333, 0.8);
        g.beginPath();
        g.arc(0, headY + 2, 3.5, 0, Math.PI);
        g.strokePath();
      } else {
        // Default smile
        g.lineStyle(1, 0x333333, 0.6);
        g.beginPath();
        g.arc(0, headY + 3, 3, 0.2, Math.PI - 0.2);
        g.strokePath();
      }
    }

    // === TOOL (state-specific) ===
    if (state === 'build') {
      // Hammer
      const hammerAngle = Math.sin(t * 4) * 0.6;
      const hx = 18 + rightArmAngle * 10;
      const hy = by - 2 + Math.abs(rightArmAngle) * 8;
      g.lineStyle(2, 0x8B4513, 1);
      g.beginPath();
      g.moveTo(hx, hy);
      g.lineTo(hx + Math.cos(hammerAngle - 1) * 12, hy + Math.sin(hammerAngle - 1) * 12);
      g.strokePath();
      // Hammer head
      g.fillStyle(0x666666, 1);
      g.fillRect(hx + Math.cos(hammerAngle - 1) * 12 - 3, hy + Math.sin(hammerAngle - 1) * 12 - 2, 6, 4);
    } else if (state === 'work') {
      // Pitchfork / hoe
      const toolX = 18 + rightArmAngle * 10;
      const toolY = by - 2;
      g.lineStyle(2, 0x8B4513, 1);
      g.beginPath();
      g.moveTo(toolX, toolY);
      g.lineTo(toolX, toolY + 20);
      g.strokePath();
    }

    // Badge/initial on overalls
    g.fillStyle(0xffffff, 0.85);
    g.fillCircle(0, by + 4, 5);
    g.fillStyle(0x333333, 1);
    // Tiny initial (just a dot for now since we can't render text in Graphics)
    g.fillCircle(0, by + 4, 1.5);
  }

  getId(): string {
    return this.agentId;
  }

  getWorldX(): number { return this.worldX; }
  getWorldY(): number { return this.worldY; }
}
