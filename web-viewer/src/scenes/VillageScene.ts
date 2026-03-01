import Phaser from 'phaser';
import { SimulationSnapshot, AgentSnapshot, FoodSnapshot } from '../types/snapshot';
import { NetworkManager } from '../systems/NetworkManager';
import { PredictionEngine } from '../systems/PredictionEngine';
import { CameraController } from '../systems/CameraController';
import { DayNightCycle } from '../systems/DayNightCycle';
import { SoundManager } from '../systems/SoundManager';
import { CrabAgent } from '../objects/CrabAgent';
import { House } from '../objects/House';
import { FoodItem } from '../objects/FoodItem';
import { WORLD_SIZE, STRUCT_ICON_MAP, ICON_FALLBACK, FOODS } from '../config/constants';

export class VillageScene extends Phaser.Scene {
  private networkManager!: NetworkManager;
  private predictionEngine!: PredictionEngine;
  private cameraController!: CameraController;
  private dayNightCycle!: DayNightCycle;
  soundManager!: SoundManager;

  private agents = new Map<string, CrabAgent>();
  private houses = new Map<string, House>();
  private foodItems: FoodItem[] = [];
  private structureTexts: Phaser.GameObjects.Container[] = [];

  snapshot: SimulationSnapshot | null = null;
  private prevSnapshot: SimulationSnapshot | null = null;

  // Particles
  private particles: { x: number; y: number; vx: number; vy: number; life: number; maxLife: number; color: number; size: number; graphics: Phaser.GameObjects.Graphics }[] = [];

  // Food mode
  foodMode = false;
  selectedFood: typeof FOODS[0] | null = null;

  // Local optimistic foods
  private localFoods: (FoodSnapshot & { _local: boolean })[] = [];

  constructor() {
    super('VillageScene');
  }

  create() {
    // Draw ground
    this.drawGround();

    // Camera
    this.cameraController = new CameraController(this);

    // Day/Night
    this.dayNightCycle = new DayNightCycle(this);

    // Sound
    this.soundManager = new SoundManager();

    // Prediction
    this.predictionEngine = new PredictionEngine();

    // Network
    this.networkManager = new NetworkManager();
    this.networkManager.onSnapshot = (snap) => this.handleSnapshot(snap);
    this.networkManager.onReturnSummary = (summary) => {
      this.events.emit('toast', summary);
    };
    this.networkManager.start();

    // Food drop via click
    this.input.on('pointerup', (pointer: Phaser.Input.Pointer) => {
      if (this.cameraController.wasDrag()) return;
      if (this.foodMode) {
        this.handleFoodDrop(pointer);
      }
    });

    // Expose network manager and sound for HUD
    this.registry.set('networkManager', this.networkManager);
    this.registry.set('soundManager', this.soundManager);
  }

  private handleSnapshot(snap: SimulationSnapshot) {
    this.prevSnapshot = this.snapshot;
    this.snapshot = snap;

    // Sound events (comparing to previous)
    if (this.prevSnapshot && this.soundManager.enabled) {
      for (const a of snap.agents) {
        const prev = this.prevSnapshot.agents?.find(p => p.id === a.id);
        if (prev) {
          if (a.currentSpeech && a.currentSpeech !== prev.currentSpeech) {
            this.soundManager.playTTS(a);
          }
          if ((a.state === 'eating' || a.state === 'eat') && prev.state !== 'eating' && prev.state !== 'eat') {
            this.soundManager.sfxEat();
          }
        }
      }
    }

    // Update prediction
    this.predictionEngine.onSnapshotReceived(snap.agents);

    // Update crickets
    if (this.soundManager.enabled) {
      this.soundManager.updateCrickets(snap);
    }

    // Day/night
    this.dayNightCycle.update(snap.dayPeriod);

    // Create/update houses (only once)
    if (this.houses.size === 0 && snap.houses) {
      for (const h of snap.houses) {
        const house = new House(this, h);
        this.houses.set(h.id, house);
      }
    }

    // Create/update agents
    for (const a of snap.agents) {
      let agent = this.agents.get(a.id);
      if (!agent) {
        agent = new CrabAgent(this, a);
        this.agents.set(a.id, agent);
      }
      agent.updateFromSnapshot(a, this.time.now);
    }

    // Update structures
    this.updateStructures(snap);

    // Update food items
    this.updateFoods(snap);

    // Clear local optimistic foods on server sync
    this.localFoods = [];

    // Emit to HUD
    this.events.emit('snapshotUpdate', snap);
    this.registry.set('connected', this.networkManager.connected);
  }

  private updateStructures(snap: SimulationSnapshot) {
    // Clear old structures
    for (const s of this.structureTexts) {
      s.destroy();
    }
    this.structureTexts = [];

    for (const s of snap.structures || []) {
      const iconName = STRUCT_ICON_MAP[s.type] || 'house';
      const fallback = ICON_FALLBACK[iconName] || '🏠';

      const container = this.add.container(s.position.x, -s.position.y);

      const icon = this.add.text(0, 0, fallback, {
        fontSize: '22px',
      }).setOrigin(0.5, 0.5);

      const label = this.add.text(0, 20, s.type || '', {
        fontSize: '8px',
        fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
        color: 'rgba(255,255,255,0.5)',
        align: 'center',
        rtl: true,
      }).setOrigin(0.5, 0.5);

      container.add([icon, label]);
      container.setDepth(4);
      this.structureTexts.push(container);
    }
  }

  private updateFoods(snap: SimulationSnapshot) {
    // Destroy old food items
    for (const f of this.foodItems) {
      f.destroy();
    }
    this.foodItems = [];

    // Server foods + local optimistic foods
    const allFoods = [...(snap.foods || []), ...this.localFoods];
    for (const f of allFoods) {
      const food = new FoodItem(this, f as FoodSnapshot & { _local?: boolean });
      this.foodItems.push(food);
    }
  }

  private handleFoodDrop(pointer: Phaser.Input.Pointer) {
    const cam = this.cameras.main;
    const worldPoint = cam.getWorldPoint(pointer.x, pointer.y);
    const worldX = worldPoint.x;
    const worldY = -worldPoint.y; // Flip Y back to simulation coords

    const food = this.selectedFood || FOODS[Math.floor(Math.random() * FOODS.length)];

    // Optimistic local food
    this.localFoods.push({
      position: { x: worldX, y: worldY },
      emoji: food.emoji,
      icon: food.icon,
      name: food.name,
      isBeingEaten: false,
      _local: true,
    });

    // Spawn particles
    this.spawnFoodParticles(worldX, -worldY);

    // Toast + sound
    this.events.emit('toast', 'אוכל נזרק!');
    this.soundManager.sfxFoodDrop();

    // Send to server
    this.networkManager.dropFood(worldX, worldY, food.emoji, food.name);

    // Reset food mode
    this.foodMode = false;
    this.selectedFood = null;
    this.events.emit('foodModeChanged', false);
  }

  quickDropFood() {
    const x = (Math.random() - 0.5) * 200;
    const y = (Math.random() - 0.5) * 200;
    const food = FOODS[Math.floor(Math.random() * FOODS.length)];

    this.localFoods.push({
      position: { x, y },
      emoji: food.emoji,
      icon: food.icon,
      name: food.name,
      isBeingEaten: false,
      _local: true,
    });

    this.spawnFoodParticles(x, -y);
    this.events.emit('toast', 'אוכל נזרק למרכז הכפר!');
    this.soundManager.sfxFoodDrop();
    this.networkManager.dropFood(x, y, food.emoji, food.name);
  }

  private spawnFoodParticles(x: number, y: number) {
    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2 + Math.random() * 0.3;
      const speed = 40 + Math.random() * 60;
      const g = this.add.graphics();
      g.fillStyle(0xd4af37, 1);
      g.fillCircle(0, 0, 3 + Math.random() * 2);
      g.setPosition(x, y);
      g.setDepth(950);
      this.particles.push({
        x, y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 0.6 + Math.random() * 0.3,
        maxLife: 0.6 + Math.random() * 0.3,
        color: 0xd4af37,
        size: 3 + Math.random() * 2,
        graphics: g,
      });
    }
  }

  focusOnAgent(agentId: string) {
    const agent = this.agents.get(agentId);
    if (agent) {
      this.cameraController.focusOn(agent.x, agent.y);
    }
  }

  approveRequest(id: string) {
    this.networkManager.approveRequest(id);
    this.events.emit('toast', 'בקשה אושרה!');
    this.soundManager.sfxCelebration();
  }

  denyRequest(id: string) {
    this.networkManager.denyRequest(id);
    this.events.emit('toast', 'בקשה נדחתה');
  }

  private drawGround() {
    // Use the pixel art village ground image
    const groundImg = this.add.image(0, 0, 'village-ground');
    // Scale to cover the world area (the image is 1024x1024, world is ~1000x1000)
    groundImg.setDisplaySize(1000, 1000);
    groundImg.setDepth(0);
  }

  update(time: number, delta: number) {
    const dt = Math.min(delta / 1000, 0.1);

    // Advance prediction
    this.predictionEngine.update(dt);

    // Update agent positions and animations
    for (const [id, agent] of this.agents) {
      const predicted = this.predictionEngine.getPosition(id);
      if (predicted) {
        agent.updateAnimation(predicted, time);
      }
    }

    // Update food glow
    for (const food of this.foodItems) {
      food.updateGlow(time);
    }

    // Update particles
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) {
        p.graphics.destroy();
        this.particles.splice(i, 1);
      } else {
        p.graphics.setPosition(p.x, p.y);
        p.graphics.setAlpha(p.life / p.maxLife);
      }
    }

    // Animated fountain sparkles
    const t = time * 0.001;
    // (This could be done with a separate graphics object for efficiency)
  }
}
