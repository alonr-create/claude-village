import Phaser from 'phaser';
import { SimulationSnapshot, AgentSnapshot, FoodSnapshot } from '../types/snapshot';
import { NetworkManager } from '../systems/NetworkManager';
import { PredictionEngine } from '../systems/PredictionEngine';
import { CameraController } from '../systems/CameraController';
import { DayNightCycle } from '../systems/DayNightCycle';
import { SoundManager } from '../systems/SoundManager';
import { FarmerAgent } from '../objects/FarmerAgent';
import { House } from '../objects/House';
import { FoodItem } from '../objects/FoodItem';
import { WORLD_SIZE, STRUCT_ICON_MAP, ICON_FALLBACK, FOODS, FARM_TREE_TEXTURES, FARM_DECO_TEXTURES } from '../config/constants';
import { IsometricTerrain } from '../systems/IsometricTerrain';
import { cartToIso, isoToCart, isoDepth } from '../systems/IsometricUtils';
import { minPathDist } from '../config/pathNetwork';
import { ParticleManager } from '../systems/ParticleManager';
import { WeatherSystem } from '../systems/WeatherSystem';

export class VillageScene extends Phaser.Scene {
  private networkManager!: NetworkManager;
  private predictionEngine!: PredictionEngine;
  private cameraController!: CameraController;
  private dayNightCycle!: DayNightCycle;
  soundManager!: SoundManager;

  private agents = new Map<string, FarmerAgent>();
  private houses = new Map<string, House>();
  private foodItems: FoodItem[] = [];
  private structureTexts: Phaser.GameObjects.Container[] = [];

  snapshot: SimulationSnapshot | null = null;
  private prevSnapshot: SimulationSnapshot | null = null;

  // Particle system
  private particleManager!: ParticleManager;

  // Isometric terrain
  private terrain!: IsometricTerrain;

  // Animated decorations (for wind)
  private animatedTrees: Phaser.GameObjects.Image[] = [];
  private animatedBushes: Phaser.GameObjects.Image[] = [];

  // Ambient particle timer
  private ambientTimer = 0;

  // Chimney smoke timer per house
  private houseSmokeTimers = new Map<string, number>();

  // Weather system
  private weatherSystem!: WeatherSystem;

  // Season (based on real month)
  private season: 'spring' | 'summer' | 'autumn' | 'winter';

  // Food mode
  foodMode = false;
  selectedFood: typeof FOODS[0] | null = null;

  // Local optimistic foods
  private localFoods: (FoodSnapshot & { _local: boolean })[] = [];

  constructor() {
    super('VillageScene');
    const month = new Date().getMonth();
    if (month >= 2 && month <= 4) this.season = 'spring';
    else if (month >= 5 && month <= 7) this.season = 'summer';
    else if (month >= 8 && month <= 10) this.season = 'autumn';
    else this.season = 'winter';
  }

  create() {
    // Isometric terrain (tile-based)
    this.terrain = new IsometricTerrain(this);

    // Farm decorations (trees, bushes, etc.)
    this.drawFarmDecorations();

    // Particles
    this.particleManager = new ParticleManager(this);

    // Camera (isometric)
    this.cameraController = new CameraController(this);

    // Day/Night
    this.dayNightCycle = new DayNightCycle(this);

    // Weather
    this.weatherSystem = new WeatherSystem(this);

    // Sound
    this.soundManager = new SoundManager();

    // Prediction
    this.predictionEngine = new PredictionEngine();

    // Network
    this.networkManager = new NetworkManager();
    this.networkManager.onSnapshot = (snap) => this.handleSnapshot(snap);
    this.networkManager.onReturnSummary = (summary) => {
      this.events.emit('returnSummary', summary);
    };
    this.networkManager.onReconnecting = (seconds) => {
      this.events.emit('reconnecting', seconds);
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

    // Sound events
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

    // Update house night mode + activity
    const isNight = this.dayNightCycle.isNight();
    for (const [id, house] of this.houses) {
      house.setNightMode(isNight);
      const hData = snap.houses?.find(h => h.id === id);
      if (hData) house.setActivityMode(hData.isActive);
    }

    // Create/update houses (only once)
    if (this.houses.size === 0 && snap.houses) {
      for (const h of snap.houses) {
        const house = new House(this, h);
        this.houses.set(h.id, house);
      }
    }

    // Create/update agents (FarmerAgent instead of CrabAgent)
    for (const a of snap.agents) {
      let agent = this.agents.get(a.id);
      if (!agent) {
        agent = new FarmerAgent(this, a);
        agent.particles = this.particleManager;
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
    for (const s of this.structureTexts) {
      s.destroy();
    }
    this.structureTexts = [];

    for (const s of snap.structures || []) {
      const iconName = STRUCT_ICON_MAP[s.type] || 'house';
      const textureKey = 'icon-' + iconName;

      // Convert structure position to isometric
      const iso = cartToIso(s.position.x, s.position.y);
      const container = this.add.container(iso.x, iso.y);

      let icon: Phaser.GameObjects.Image | Phaser.GameObjects.Text;
      if (this.textures.exists(textureKey)) {
        icon = this.add.image(0, 0, textureKey)
          .setDisplaySize(56, 56).setOrigin(0.5, 0.5);
      } else {
        const fallback = ICON_FALLBACK[iconName] || '🏠';
        icon = this.add.text(0, 0, fallback, {
          fontSize: '40px',
        }).setOrigin(0.5, 0.5);
      }

      const label = this.add.text(0, 38, s.type || '', {
        fontSize: '13px',
        fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
        color: '#ffffff',
        align: 'center',
        rtl: true,
        stroke: '#000000',
        strokeThickness: 2,
      }).setOrigin(0.5, 0.5);

      container.add([icon, label]);
      container.setDepth(isoDepth(s.position.x, s.position.y, 4));
      this.structureTexts.push(container);
    }
  }

  private updateFoods(snap: SimulationSnapshot) {
    for (const f of this.foodItems) {
      f.destroy();
    }
    this.foodItems = [];

    const allFoods = [...(snap.foods || []), ...this.localFoods];
    for (const f of allFoods) {
      const food = new FoodItem(this, f as FoodSnapshot & { _local?: boolean });
      this.foodItems.push(food);
    }
  }

  private handleFoodDrop(pointer: Phaser.Input.Pointer) {
    const cam = this.cameras.main;
    const screenPoint = cam.getWorldPoint(pointer.x, pointer.y);

    // Convert from isometric screen space back to Cartesian world
    const world = isoToCart(screenPoint.x, screenPoint.y);
    const worldX = world.x;
    const worldY = world.y;

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

    // Spawn particles at iso position + camera shake
    const isoPos = cartToIso(worldX, worldY);
    this.particleManager.foodBurst(isoPos.x, isoPos.y);
    this.cameras.main.shake(100, 0.002);

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

    const isoPos = cartToIso(x, y);
    this.particleManager.foodBurst(isoPos.x, isoPos.y);
    this.events.emit('toast', 'אוכל נזרק למרכז החווה!');
    this.soundManager.sfxFoodDrop();
    this.networkManager.dropFood(x, y, food.emoji, food.name);
  }

  focusOnAgent(agentId: string) {
    const agent = this.agents.get(agentId);
    if (agent) {
      // Agent container is already in iso coords
      this.cameraController.focusOn(agent.x, agent.y);
    }
  }

  approveRequest(id: string) {
    this.networkManager.approveRequest(id);
    this.events.emit('toast', 'בקשה אושרה!');
    this.soundManager.sfxCelebration();
    this.cameras.main.flash(200, 255, 215, 0, false);
  }

  denyRequest(id: string) {
    this.networkManager.denyRequest(id);
    this.events.emit('toast', 'בקשה נדחתה');
  }

  /** Draw farm-style decorations in isometric positions */
  private drawFarmDecorations() {
    let seed = 123;
    const rng = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };

    // Available tree textures
    const hasTreeSprites = FARM_TREE_TEXTURES.some(k => this.textures.exists(k));
    // Fallback to old tree textures
    const OLD_TREES = ['tree-oak', 'tree-pine', 'tree-autumn', 'tree-birch'];
    const hasOldTrees = OLD_TREES.some(k => this.textures.exists(k));
    const treeTextures = hasTreeSprites ? FARM_TREE_TEXTURES : (hasOldTrees ? OLD_TREES : []);

    const hasBush = this.textures.exists('bush-iso') || this.textures.exists('sprite-bush');
    const bushKey = this.textures.exists('bush-iso') ? 'bush-iso' : 'sprite-bush';
    const hasFountain = this.textures.exists('water-well-iso') || this.textures.exists('sprite-fountain');
    const fountainKey = this.textures.exists('water-well-iso') ? 'water-well-iso' : 'sprite-fountain';

    type TreeData = { wx: number; wy: number; scale: number; texture: string; warmTint?: boolean };
    type BushData = { wx: number; wy: number; scale: number };

    const trees: TreeData[] = [];
    const bushes: BushData[] = [];

    // Tree scale based on distance
    const treeScale = (dist: number) => {
      if (dist < 1200) return 0.10 + rng() * 0.10;
      if (dist < 2500) return 0.14 + rng() * 0.18;
      return 0.18 + rng() * 0.20;
    };

    // Scatter trees
    for (let i = 0; i < 3000; i++) {
      const wx = (rng() - 0.5) * WORLD_SIZE * 1.8;
      const wy = (rng() - 0.5) * WORLD_SIZE * 1.8;
      const dist = Math.sqrt(wx * wx + wy * wy);
      if (dist < 500) continue;

      const roadDist = minPathDist(wx, wy);
      if (roadDist < 120) continue;

      const roll = rng();
      if (roll < 0.15 && treeTextures.length > 0) {
        const tex = treeTextures[Math.floor(rng() * treeTextures.length)];
        trees.push({ wx, wy, scale: treeScale(dist), texture: tex });
      } else if (roll < 0.20) {
        bushes.push({ wx, wy, scale: 0.06 + rng() * 0.10 });
      }
    }

    // Village perimeter trees
    for (let i = 0; i < 80; i++) {
      const angle = rng() * Math.PI * 2;
      const radius = 700 + rng() * 600;
      const wx = Math.cos(angle) * radius;
      const wy = Math.sin(angle) * radius;
      const roadDist = minPathDist(wx, wy);
      if (roadDist < 140) continue;
      if (treeTextures.length > 0 && rng() < 0.5) {
        const tex = treeTextures[Math.floor(rng() * treeTextures.length)];
        trees.push({ wx, wy, scale: 0.12 + rng() * 0.12, texture: tex, warmTint: true });
      } else {
        bushes.push({ wx, wy, scale: 0.04 + rng() * 0.05 });
      }
    }

    // Village center — well/fountain
    if (hasFountain) {
      const iso = cartToIso(0, 0);
      this.add.image(iso.x, iso.y, fountainKey)
        .setScale(0.25).setOrigin(0.5, 0.7).setDepth(isoDepth(0, 0, 4));
    }
    const wellIso = cartToIso(0, 0);
    this.add.text(wellIso.x, wellIso.y + 45, 'כיכר החווה', {
      fontSize: '13px',
      fontFamily: '-apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#ffffff',
      align: 'center', rtl: true,
      stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5, 0.5).setDepth(isoDepth(0, 0, 4));

    // Sort trees by world position for correct isometric depth
    trees.sort((a, b) => (a.wx + a.wy) - (b.wx + b.wy));

    // Render trees
    for (const t of trees) {
      const textureKey = treeTextures.length > 0 && this.textures.exists(t.texture) ? t.texture : null;
      if (textureKey) {
        const iso = cartToIso(t.wx, t.wy);
        const tree = this.add.image(iso.x, iso.y, textureKey)
          .setScale(t.scale)
          .setOrigin(0.5, 0.95)
          .setDepth(isoDepth(t.wx, t.wy, 3));
        if (t.warmTint) tree.setTint(0xfff0d8);
        // Seasonal tint
        if (!t.warmTint) {
          switch (this.season) {
            case 'summer': tree.setTint(0xfff8e0); break;
            case 'autumn':
              if (t.texture.includes('oak') || t.texture.includes('autumn') || t.texture.includes('cherry')) {
                tree.setTint(0xffcc80);
              }
              break;
            case 'winter': tree.setTint(0xdde8f0); break;
          }
        }
        this.animatedTrees.push(tree);
        // Shadow
        const shadow = this.add.graphics().setDepth(isoDepth(t.wx, t.wy, 1.8));
        shadow.fillStyle(0x000000, 0.12);
        shadow.fillEllipse(iso.x, iso.y + 4, t.scale * 300, t.scale * 80);
      }
    }

    // Render bushes
    for (const b of bushes) {
      if (hasBush) {
        const iso = cartToIso(b.wx, b.wy);
        const bush = this.add.image(iso.x, iso.y, bushKey)
          .setScale(b.scale)
          .setOrigin(0.5, 0.8)
          .setDepth(isoDepth(b.wx, b.wy, 2.5));
        this.animatedBushes.push(bush);
      }
    }

    // Procedural flowers (isometric position)
    const flowerGfx = this.add.graphics().setDepth(1.5);
    for (let i = 0; i < 200; i++) {
      const angle = rng() * Math.PI * 2;
      const radius = 250 + rng() * 500;
      const wx = Math.cos(angle) * radius;
      const wy = Math.sin(angle) * radius;
      if (minPathDist(wx, wy) < 90) continue;

      const iso = cartToIso(wx, wy);
      const fColors = [0xe87090, 0xf0d040, 0xb080d0, 0xf0f0e0, 0xff8866];
      const color = fColors[Math.floor(rng() * fColors.length)];
      const count = 4 + Math.floor(rng() * 6);
      for (let j = 0; j < count; j++) {
        const fx = iso.x + (rng() - 0.5) * 25;
        const fy = iso.y + (rng() - 0.5) * 15; // flatter spread for iso
        const petalR = 1.5 + rng() * 1.5;
        const petalCount = 4 + Math.floor(rng() * 2);
        for (let p = 0; p < petalCount; p++) {
          const a = (p / petalCount) * Math.PI * 2;
          flowerGfx.fillStyle(color, 0.55 + rng() * 0.2);
          flowerGfx.fillCircle(fx + Math.cos(a) * petalR, fy + Math.sin(a) * petalR, petalR * 0.55);
        }
        flowerGfx.fillStyle(0xf0d040, 0.6);
        flowerGfx.fillCircle(fx, fy, petalR * 0.3);
      }
    }
  }

  update(time: number, delta: number) {
    const dt = Math.min(delta / 1000, 0.1);
    const t = time * 0.001;

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

    // Update particle system
    this.particleManager.update(dt);

    // Day/night effects
    this.dayNightCycle.updateEffects(time, dt);

    // Weather
    this.weatherSystem.update(time, dt);

    // Wind animation (trees & bushes — uses iso screen positions)
    const cam = this.cameras.main;
    const camL = cam.scrollX - 200;
    const camR = cam.scrollX + cam.width + 200;
    const camT = cam.scrollY - 200;
    const camB = cam.scrollY + cam.height + 200;

    for (const tree of this.animatedTrees) {
      if (tree.x < camL || tree.x > camR || tree.y < camT || tree.y > camB) continue;
      const sway = Math.sin(t * 1.5 + tree.x * 0.002 + tree.y * 0.001) * 2.0;
      tree.setAngle(sway);
    }
    for (const bush of this.animatedBushes) {
      if (bush.x < camL || bush.x > camR || bush.y < camT || bush.y > camB) continue;
      const sway = Math.sin(t * 2.0 + bush.x * 0.003 + bush.y * 0.002) * 3.0;
      bush.setAngle(sway);
    }

    // Ambient particles
    this.ambientTimer -= dt;
    if (this.ambientTimer <= 0) {
      this.ambientTimer = 0.3;
      const period = this.dayNightCycle.getPeriod();
      if (period !== 'night') {
        const cx = cam.scrollX + cam.width * 0.5 + (Math.random() - 0.5) * cam.width;
        const cy = cam.scrollY + cam.height * 0.5 + (Math.random() - 0.5) * cam.height;
        this.particleManager.emitAmbient(cx, cy, period);
      }
    }

    // Chimney smoke
    for (const [id, house] of this.houses) {
      const timer = this.houseSmokeTimers.get(id) || 0;
      if (time > timer) {
        this.houseSmokeTimers.set(id, time + 800 + Math.random() * 400);
        this.particleManager.chimneySmoke(house.x - 15, house.y - 120);
      }
    }
  }
}
