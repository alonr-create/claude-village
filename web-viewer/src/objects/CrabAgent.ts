import Phaser from 'phaser';
import { AgentSnapshot } from '../types/snapshot';
import { PredictedPosition } from '../systems/PredictionEngine';
import { SpeechBubble } from './SpeechBubble';
import { ICON_FALLBACK, MOOD_EMOJI_TO_ICON } from '../config/constants';
import { ParticleManager } from '../systems/ParticleManager';

// State → icon key mapping
const STATE_ICON_MAP: Record<string, string> = {
  work: 'state-work', build: 'state-build',
  eat: 'state-eat', eating: 'state-eat',
  rest: 'state-sleep', socialize: 'state-socialize',
  explore: 'state-explore', request: 'state-request',
};

export class CrabAgent extends Phaser.GameObjects.Container {
  private crabBody: Phaser.GameObjects.Graphics;
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
  private nextBlink: number;
  private blinking = false;
  private blinkEnd = 0;
  private lastSpeech: string | null = null;

  // State tracking
  private currentState = 'idle';
  private currentMoodEmoji = '';

  // Particle timers
  private nextDustTime = 0;
  private nextSleepZTime = 0;
  private nextHeartTime = 0;
  private nextClawWiggle = 0;
  private clawWiggling = false;
  private clawWiggleEnd = 0;

  // Entrance animation
  private entranceComplete = false;

  // Reference to particle manager (set externally)
  particles: ParticleManager | null = null;

  constructor(scene: Phaser.Scene, data: AgentSnapshot) {
    super(scene, data.position.x, -data.position.y);
    this.agentId = data.id;
    this.colorHex = data.badgeColor || '#E8734A';
    this.color = parseInt(this.colorHex.replace('#', ''), 16);
    this.nextBlink = scene.time.now + 3000 + Math.random() * 3000;
    this.nextClawWiggle = scene.time.now + 4000 + Math.random() * 3000;

    // Shadow — scaled for 1.5x crab
    this.shadow = scene.add.graphics();
    this.shadow.fillStyle(0x000000, 0.20);
    this.shadow.fillEllipse(0, 28, 52, 16);
    this.add(this.shadow);

    // Body graphics
    this.crabBody = scene.add.graphics();
    this.add(this.crabBody);

    // Name label
    this.nameLabel = this.createNameLabel(scene, data.name, this.color, this.colorHex);
    this.add(this.nameLabel);

    // Mood icon (PNG from Nano Banana) — scaled for 1.5x
    this.moodIcon = scene.add.image(34, -24, '__DEFAULT')
      .setDisplaySize(24, 24).setOrigin(0.5, 0.5).setVisible(false);
    this.add(this.moodIcon);

    // State icon (PNG from Nano Banana) — scaled for 1.5x
    this.stateIcon = scene.add.image(-34, -24, '__DEFAULT')
      .setDisplaySize(22, 22).setOrigin(0.5, 0.5).setVisible(false);
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

    // Dynamic depth based on Y position — agents layer properly with trees
    this.setDepth(10 + data.position.y * 0.0001);
    scene.add.existing(this as unknown as Phaser.GameObjects.GameObject);
  }

  private createNameLabel(scene: Phaser.Scene, name: string, _color: number, colorHex: string): Phaser.GameObjects.Container {
    const container = new Phaser.GameObjects.Container(scene, 0, 38);

    const text = scene.add.text(0, 0, name, {
      fontSize: '14px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      align: 'center',
      rtl: true,
    }).setOrigin(0.5, 0.5);

    const bg = scene.add.graphics();
    const w = text.width + 16;
    const h = 24;
    bg.fillStyle(parseInt(colorHex.replace('#', ''), 16), 0.85);
    bg.fillRoundedRect(-w / 2, -h / 2, w, h, 8);
    bg.lineStyle(1, 0xffffff, 0.2);
    bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 8);

    container.add([bg, text]);
    return container;
  }

  updateFromSnapshot(data: AgentSnapshot, time: number) {
    // Update mood icon (PNG)
    if (data.moodEmoji !== this.currentMoodEmoji) {
      this.currentMoodEmoji = data.moodEmoji;
      const moodKey = MOOD_EMOJI_TO_ICON[data.moodEmoji];
      if (moodKey && this.scene.textures.exists('icon-' + moodKey)) {
        this.moodIcon.setTexture('icon-' + moodKey).setDisplaySize(18, 18).setVisible(true);
      } else {
        this.moodIcon.setVisible(false);
      }
    }

    // Update state icon (PNG)
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
        this.speechBubble.setPosition(0, -60);
        this.add(this.speechBubble);
      }
    } else if (!data.currentSpeech && this.speechBubble) {
      this.speechBubble.destroy();
      this.speechBubble = null;
      this.lastSpeech = null;
    }
  }

  updateAnimation(predicted: PredictedPosition, time: number) {
    // Use smoothed currentSpeed from PredictionEngine for natural animation
    const speed = predicted.currentSpeed ?? Math.sqrt(predicted.vx ** 2 + predicted.vy ** 2);
    this.isMoving = speed > 2;

    // Update position and depth (Y-sorting for proper layering)
    this.setPosition(predicted.x, -predicted.y);
    this.setDepth(10 + (-predicted.y) * 0.0001);

    // Walk phase
    if (this.isMoving) {
      this.walkPhase = time * 0.008 + this.agentId.charCodeAt(0);
    }

    // Blink logic (not when sleeping)
    if (this.currentState !== 'rest') {
      if (time >= this.nextBlink && !this.blinking) {
        this.blinking = true;
        this.blinkEnd = time + 120;
      }
      if (this.blinking && time >= this.blinkEnd) {
        this.blinking = false;
        this.nextBlink = time + 3000 + Math.random() * 3000;
      }
    }

    // Idle claw wiggle
    if (!this.isMoving && this.currentState === 'idle') {
      if (time >= this.nextClawWiggle && !this.clawWiggling) {
        this.clawWiggling = true;
        this.clawWiggleEnd = time + 300;
      }
      if (this.clawWiggling && time >= this.clawWiggleEnd) {
        this.clawWiggling = false;
        this.nextClawWiggle = time + 4000 + Math.random() * 3000;
      }
    }

    // Particle effects based on state
    if (this.particles && this.entranceComplete) {
      this.emitStateParticles(time, predicted);
    }

    // Redraw the crab body
    this.drawCrab(time, predicted);

    // Update speech bubble pulse
    if (this.speechBubble) {
      this.speechBubble.updatePulse(time);
    }
  }

  private emitStateParticles(time: number, predicted: PredictedPosition) {
    if (!this.particles) return;

    // Walking dust — adjusted for 1.5x scale
    if (this.isMoving && time > this.nextDustTime) {
      this.particles.dustBurst(predicted.x, -predicted.y + 28, 3);
      this.nextDustTime = time + 400;
    }

    // Sleeping Z's
    if (this.currentState === 'rest' && time > this.nextSleepZTime) {
      this.particles.sleepZ(predicted.x + 16, -predicted.y - 32);
      this.nextSleepZTime = time + 1200;
    }

    // Eating hearts
    if ((this.currentState === 'eat' || this.currentState === 'eating') && time > this.nextHeartTime) {
      this.particles.hearts(predicted.x, -predicted.y - 24);
      this.nextHeartTime = time + 2000;
    }

    // Building sparks
    if (this.currentState === 'build' && time > this.nextDustTime) {
      this.particles.constructionDust(predicted.x, -predicted.y + 8);
      this.nextDustTime = time + 600;
    }

    // Working sparkles
    if (this.currentState === 'work' && time > this.nextDustTime) {
      this.particles.sparkleBurst(predicted.x + 22, -predicted.y - 8, 2);
      this.nextDustTime = time + 1500;
    }
  }

  private drawCrab(time: number, predicted: PredictedPosition) {
    const g = this.crabBody;
    g.clear();

    const t = time * 0.001;
    const state = this.currentState;
    // Scale for visibility — proportional to houses (3.5x), crabs should be ~1/3 of house height
    const S = 1.2;

    // === STATE-BASED BODY ANIMATION ===
    let walkBob: number;
    let legWiggle: number;
    let bodyYOffset = 0;
    let bodyWidthScale = 1;
    let eyeOpen = !this.blinking;

    if (this.isMoving) {
      walkBob = Math.sin(this.walkPhase) * 4 * S;
      legWiggle = Math.sin(this.walkPhase) * 0.4;
    } else if (state === 'eat' || state === 'eating') {
      walkBob = Math.sin(t * 4) * 3 * S;
      legWiggle = Math.sin(t * 3) * 0.15;
    } else if (state === 'rest') {
      bodyYOffset = 4 * S;
      walkBob = Math.sin(t * 0.5) * 2 * S;
      legWiggle = 0;
      eyeOpen = false;
      bodyWidthScale = 1 + Math.sin(t * 0.5) * 0.02;
    } else if (state === 'work') {
      walkBob = Math.sin(t * 2) * 1.5 * S;
      legWiggle = Math.sin(t * 4) * 0.1;
    } else if (state === 'build') {
      const hammerPhase = t * 4;
      walkBob = Math.abs(Math.sin(hammerPhase)) * 3 * S;
      legWiggle = Math.sin(hammerPhase) * 0.2;
    } else if (state === 'socialize') {
      walkBob = Math.sin(t * 1.8) * 2 * S;
      legWiggle = Math.sin(t * 2.5) * 0.1;
    } else {
      walkBob = Math.sin(t * 1.2 + this.agentId.charCodeAt(0) * 0.5) * 1.5 * S;
      legWiggle = this.clawWiggling ? Math.sin(t * 8) * 0.15 : 0;
      bodyWidthScale = 1 + Math.sin(t * 2) * 0.01;
    }

    const bodyY = walkBob + bodyYOffset;

    // === LEGS (3 per side) ===
    g.lineStyle(2.5 * S, this.color, 0.9);
    for (let i = 0; i < 3; i++) {
      const ly = bodyY - 2 * S + i * 5 * S;
      const phase = this.walkPhase + i * 1.2;
      const lw = this.isMoving ? Math.sin(phase) * 5 * S : legWiggle * 8 * S;
      // Left legs with joints
      g.beginPath();
      g.moveTo(-14 * S, ly);
      g.lineTo(-18 * S - lw * 0.5, ly + 2 * S);
      g.lineTo(-22 * S - lw, ly + 6 * S + Math.abs(lw) * 0.3);
      g.strokePath();
      // Right legs with joints
      g.beginPath();
      g.moveTo(14 * S, ly);
      g.lineTo(18 * S + lw * 0.5, ly + 2 * S);
      g.lineTo(22 * S + lw, ly + 6 * S + Math.abs(lw) * 0.3);
      g.strokePath();
    }

    // === BODY (crab oval with breathing) ===
    const bodyW = 30 * S * bodyWidthScale;
    const bodyH = 22 * S;
    // Body outline glow
    g.fillStyle(0x000000, 0.15);
    g.fillEllipse(0, bodyY + 2, bodyW + 4, bodyH + 4);
    // Main body
    g.fillStyle(this.color, 1);
    g.fillEllipse(0, bodyY, bodyW, bodyH);
    g.lineStyle(1.5 * S, 0x000000, 0.2);
    g.strokeEllipse(0, bodyY, bodyW, bodyH);
    // Body highlight (glossy look)
    g.fillStyle(0xffffff, 0.2);
    g.fillEllipse(-3 * S, bodyY - 4 * S, 18 * S, 10 * S);
    // Secondary highlight
    g.fillStyle(0xffffff, 0.08);
    g.fillEllipse(2 * S, bodyY - 2 * S, 10 * S, 6 * S);

    // === CLAWS (state-specific animation) ===
    g.lineStyle(3 * S, this.color, 1);

    let leftClawOffset = legWiggle * 5 * S;
    let rightClawOffset = -legWiggle * 5 * S;
    let leftClawY = bodyY - 11 * S;
    let rightClawY = bodyY - 11 * S;

    if (state === 'eat' || state === 'eating') {
      const eatPhase = Math.sin(t * 5);
      leftClawOffset = eatPhase * 8 * S;
      rightClawOffset = -eatPhase * 8 * S;
      leftClawY = bodyY - 8 * S + eatPhase * 3 * S;
      rightClawY = bodyY - 8 * S - eatPhase * 3 * S;
    } else if (state === 'work') {
      const typePhase = t * 6;
      leftClawOffset = Math.sin(typePhase) * 4 * S;
      rightClawOffset = Math.sin(typePhase + Math.PI) * 4 * S;
      leftClawY = bodyY - 9 * S + Math.abs(Math.sin(typePhase)) * 3 * S;
      rightClawY = bodyY - 9 * S + Math.abs(Math.sin(typePhase + Math.PI)) * 3 * S;
    } else if (state === 'build') {
      const hammerY = Math.sin(t * 4) * 6 * S;
      leftClawY = bodyY - 14 * S + hammerY;
      rightClawOffset = 0;
    } else if (state === 'socialize') {
      const gesturePhase = Math.sin(t * 2);
      leftClawOffset = -gesturePhase * 6 * S;
      rightClawOffset = gesturePhase * 6 * S;
    }

    // Left claw — pincer shape
    g.beginPath();
    g.moveTo(-15 * S, bodyY - 4 * S);
    g.lineTo(-23 * S + leftClawOffset, leftClawY);
    g.strokePath();
    // Pincer fingers
    g.lineStyle(2.5 * S, this.color, 1);
    g.beginPath();
    g.moveTo(-23 * S + leftClawOffset, leftClawY);
    g.lineTo(-18 * S + leftClawOffset, leftClawY + 5 * S);
    g.strokePath();
    g.beginPath();
    g.moveTo(-23 * S + leftClawOffset, leftClawY);
    g.lineTo(-26 * S + leftClawOffset, leftClawY + 7 * S);
    g.strokePath();

    // Right claw — pincer shape
    g.lineStyle(3 * S, this.color, 1);
    g.beginPath();
    g.moveTo(15 * S, bodyY - 4 * S);
    g.lineTo(23 * S + rightClawOffset, rightClawY);
    g.strokePath();
    g.lineStyle(2.5 * S, this.color, 1);
    g.beginPath();
    g.moveTo(23 * S + rightClawOffset, rightClawY);
    g.lineTo(18 * S + rightClawOffset, rightClawY + 5 * S);
    g.strokePath();
    g.beginPath();
    g.moveTo(23 * S + rightClawOffset, rightClawY);
    g.lineTo(26 * S + rightClawOffset, rightClawY + 7 * S);
    g.strokePath();

    // === EYE STALKS ===
    g.lineStyle(2.5 * S, this.color, 1);
    const stalkSway = state === 'rest' ? 0 : Math.sin(t * 0.8) * S;
    g.beginPath();
    g.moveTo(-6 * S, bodyY - 8 * S);
    g.lineTo(-7 * S + stalkSway, bodyY - 16 * S);
    g.strokePath();
    g.beginPath();
    g.moveTo(6 * S, bodyY - 8 * S);
    g.lineTo(7 * S + stalkSway, bodyY - 16 * S);
    g.strokePath();

    const eyeY = bodyY - 16 * S;

    if (eyeOpen) {
      // Eye whites
      g.fillStyle(0xffffff, 1);
      g.fillCircle(-7 * S, eyeY, 5 * S);
      g.fillCircle(7 * S, eyeY, 5 * S);
      g.lineStyle(0.8, 0x000000, 0.3);
      g.strokeCircle(-7 * S, eyeY, 5 * S);
      g.strokeCircle(7 * S, eyeY, 5 * S);

      // Pupils
      let pupilDx = 0, pupilDy = 0;
      if (this.isMoving) {
        const dir = Math.atan2(predicted.vy, predicted.vx);
        pupilDx = Math.cos(dir) * 2 * S;
        pupilDy = -Math.sin(dir) * 2 * S;
      } else {
        pupilDx = Math.sin(t * 0.5 + this.agentId.charCodeAt(0)) * 1.5 * S;
        pupilDy = Math.cos(t * 0.3 + this.agentId.charCodeAt(0)) * S;
      }
      g.fillStyle(0x111111, 1);
      g.fillCircle(-7 * S + pupilDx, eyeY + pupilDy, 2.5 * S);
      g.fillCircle(7 * S + pupilDx, eyeY + pupilDy, 2.5 * S);

      // Eye glint
      g.fillStyle(0xffffff, 0.8);
      g.fillCircle(-6 * S + pupilDx, eyeY - 1.5 * S + pupilDy, 1.2 * S);
      g.fillCircle(8 * S + pupilDx, eyeY - 1.5 * S + pupilDy, 1.2 * S);
    } else {
      // Closed eyes
      g.lineStyle(2 * S, 0x333333, 1);
      g.beginPath();
      g.moveTo(-10 * S, eyeY);
      g.lineTo(-4 * S, eyeY);
      g.strokePath();
      g.beginPath();
      g.moveTo(4 * S, eyeY);
      g.lineTo(10 * S, eyeY);
      g.strokePath();
    }

    // Badge on body — larger
    g.fillStyle(0xffffff, 0.9);
    g.fillCircle(0, bodyY + 1 * S, 6 * S);
    g.lineStyle(1, 0x000000, 0.15);
    g.strokeCircle(0, bodyY + 1 * S, 6 * S);
  }

  getId(): string {
    return this.agentId;
  }
}
