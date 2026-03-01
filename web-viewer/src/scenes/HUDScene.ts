import Phaser from 'phaser';
import { SimulationSnapshot, AgentSnapshot, RequestSnapshot } from '../types/snapshot';
import { FOODS, ICON_FALLBACK, NEED_META, STATE_LABELS, PERIOD_LABELS, NEED_COLORS_HEX } from '../config/constants';
import { VillageScene } from './VillageScene';

export class HUDScene extends Phaser.Scene {
  private statusBar!: Phaser.GameObjects.DOMElement;
  private toolbar!: Phaser.GameObjects.DOMElement;
  private panel!: Phaser.GameObjects.DOMElement;
  private toastEl!: Phaser.GameObjects.DOMElement;
  private foodModeOverlay!: Phaser.GameObjects.DOMElement;

  private activePanel: string | null = null;
  private snapshot: SimulationSnapshot | null = null;
  private lastUIUpdate = 0;

  constructor() {
    super('HUDScene');
  }

  create() {
    // Status bar (top)
    this.statusBar = this.add.dom(0, 0).createFromHTML(`
      <div id="hud-status" style="
        position: fixed; top: 0; left: 0; right: 0;
        padding: 8px 16px; padding-top: max(8px, env(safe-area-inset-top));
        background: rgba(0,0,0,0.6); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
        display: flex; justify-content: space-between; align-items: center;
        font-size: 13px; z-index: 100; color: #fff;
        font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
        direction: rtl;
      ">
        <div>
          <span style="font-weight:700;font-size:15px">Claude Village v4.0</span>
          <span id="hud-conn" style="display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:8px;background:#f44"></span>
        </div>
        <div style="opacity:0.7;font-size:11px;display:flex;align-items:center;gap:6px">
          <span id="hud-tick">Tick: 0</span>
          <span>&middot;</span>
          <span id="hud-period">יום</span>
          <span>&middot;</span>
          <span id="hud-sound-btn" style="cursor:pointer">🔇</span>
        </div>
      </div>
    `);
    this.statusBar.setScrollFactor(0);

    // Food mode overlay
    this.foodModeOverlay = this.add.dom(0, 0).createFromHTML(`
      <div id="hud-food-mode" style="
        position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
        background: rgba(212,175,55,0.9); color: #000; padding: 14px 28px;
        border-radius: 24px; font-size: 16px; font-weight: 700; z-index: 101;
        display: none; pointer-events: none; direction: rtl;
        font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
        animation: pulse 1.5s ease-in-out infinite;
      ">🥙 לחץ על המפה להזריק אוכל!</div>
      <style>@keyframes pulse { 0%,100% { transform: translate(-50%,-50%) scale(1); } 50% { transform: translate(-50%,-50%) scale(1.05); } }</style>
    `);
    this.foodModeOverlay.setScrollFactor(0);

    // Toast notification
    this.toastEl = this.add.dom(0, 0).createFromHTML(`
      <div id="hud-toast" style="
        position: fixed; top: 60px; left: 50%; transform: translateX(-50%);
        background: rgba(45,138,78,0.95); color: #fff; padding: 10px 20px;
        border-radius: 20px; font-size: 13px; font-weight: 600; z-index: 200;
        display: none; pointer-events: none; direction: rtl;
        font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
      "></div>
    `);
    this.toastEl.setScrollFactor(0);

    // Panel (content changes based on active tab)
    this.panel = this.add.dom(0, 0).createFromHTML(`
      <div id="hud-panel" style="
        position: fixed; bottom: 68px; left: 8px; right: 8px; max-height: 50vh;
        overflow-y: auto; background: rgba(20,30,20,0.92);
        backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
        border-radius: 16px; padding: 16px; z-index: 99;
        display: none; border: 1px solid rgba(255,255,255,0.1);
        color: #fff; direction: rtl;
        font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
      "></div>
    `);
    this.panel.setScrollFactor(0);

    // Bottom toolbar
    this.toolbar = this.add.dom(0, 0).createFromHTML(`
      <div id="hud-toolbar" style="
        position: fixed; bottom: 0; left: 0; right: 0;
        padding: 6px 8px; padding-bottom: max(6px, env(safe-area-inset-bottom));
        background: rgba(0,0,0,0.75); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
        display: flex; gap: 4px; z-index: 100;
        font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
        direction: rtl;
      ">
        <div class="hud-tab" data-panel="agents" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none">
          <div style="font-size:20px">🦀</div>סוכנים
        </div>
        <div class="hud-tab" data-panel="food" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none">
          <div style="font-size:20px">🥙</div>אוכל
        </div>
        <div class="hud-tab" data-panel="requests" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none;position:relative">
          <div style="font-size:20px">📋</div>בקשות
          <span id="hud-req-badge" style="position:absolute;top:4px;right:4px;background:#f44;color:#fff;font-size:10px;font-weight:700;min-width:16px;height:16px;border-radius:8px;display:none;align-items:center;justify-content:center;padding:0 4px"></span>
        </div>
        <div class="hud-tab" data-panel="events" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none">
          <div style="font-size:20px">📜</div>אירועים
        </div>
      </div>
    `);
    this.toolbar.setScrollFactor(0);

    // Event listeners
    this.setupEventListeners();

    // Listen for snapshot updates from VillageScene
    const villageScene = this.scene.get('VillageScene') as VillageScene;
    villageScene.events.on('snapshotUpdate', (snap: SimulationSnapshot) => {
      this.snapshot = snap;
      this.updateUI();
    });

    villageScene.events.on('toast', (msg: string) => {
      this.showToast(msg);
    });

    villageScene.events.on('foodModeChanged', (active: boolean) => {
      const el = document.getElementById('hud-food-mode');
      if (el) el.style.display = active ? 'block' : 'none';
    });
  }

  private setupEventListeners() {
    // Tab clicks
    document.addEventListener('click', (e) => {
      const target = e.target as HTMLElement;
      const tab = target.closest('.hud-tab') as HTMLElement | null;
      if (tab) {
        const panel = tab.dataset.panel;
        if (!panel) return;

        // Toggle panel
        const panelEl = document.getElementById('hud-panel');
        if (!panelEl) return;

        // Deactivate all tabs
        document.querySelectorAll('.hud-tab').forEach(t => {
          (t as HTMLElement).style.background = 'transparent';
        });

        if (this.activePanel === panel) {
          this.activePanel = null;
          panelEl.style.display = 'none';
          return;
        }

        this.activePanel = panel;
        tab.style.background = 'rgba(255,255,255,0.15)';
        panelEl.style.display = 'block';
        this.renderPanel();
      }

      // Sound toggle
      if (target.id === 'hud-sound-btn' || target.closest('#hud-sound-btn')) {
        const villageScene = this.scene.get('VillageScene') as VillageScene;
        villageScene.soundManager.toggle();
        const btn = document.getElementById('hud-sound-btn');
        if (btn) btn.textContent = villageScene.soundManager.enabled ? '🔊' : '🔇';
      }

      // Approve/deny buttons
      if (target.classList.contains('hud-approve-btn')) {
        const id = target.dataset.id;
        if (id) (this.scene.get('VillageScene') as VillageScene).approveRequest(id);
      }
      if (target.classList.contains('hud-deny-btn')) {
        const id = target.dataset.id;
        if (id) (this.scene.get('VillageScene') as VillageScene).denyRequest(id);
      }

      // Agent focus
      if (target.closest('.hud-agent-card')) {
        const card = target.closest('.hud-agent-card') as HTMLElement;
        const id = card.dataset.id;
        if (id) {
          (this.scene.get('VillageScene') as VillageScene).focusOnAgent(id);
          // Close panel
          this.activePanel = null;
          const panelEl = document.getElementById('hud-panel');
          if (panelEl) panelEl.style.display = 'none';
          document.querySelectorAll('.hud-tab').forEach(t => {
            (t as HTMLElement).style.background = 'transparent';
          });
        }
      }

      // Food selection
      if (target.closest('.hud-food-btn')) {
        const btn = target.closest('.hud-food-btn') as HTMLElement;
        const idx = parseInt(btn.dataset.idx || '0');
        const food = FOODS[idx];
        if (food) {
          const villageScene = this.scene.get('VillageScene') as VillageScene;
          villageScene.selectedFood = food;
          villageScene.foodMode = true;
          const el = document.getElementById('hud-food-mode');
          if (el) el.style.display = 'block';
          // Close panel
          this.activePanel = null;
          const panelEl = document.getElementById('hud-panel');
          if (panelEl) panelEl.style.display = 'none';
          document.querySelectorAll('.hud-tab').forEach(t => {
            (t as HTMLElement).style.background = 'transparent';
          });
        }
      }

      // Quick drop
      if (target.closest('#hud-quick-drop')) {
        (this.scene.get('VillageScene') as VillageScene).quickDropFood();
        // Close panel
        this.activePanel = null;
        const panelEl = document.getElementById('hud-panel');
        if (panelEl) panelEl.style.display = 'none';
        document.querySelectorAll('.hud-tab').forEach(t => {
          (t as HTMLElement).style.background = 'transparent';
        });
      }
    });
  }

  private updateUI() {
    if (!this.snapshot) return;

    const now = Date.now();
    if (now - this.lastUIUpdate < 1000) return;
    this.lastUIUpdate = now;

    // Status bar
    const conn = document.getElementById('hud-conn');
    if (conn) {
      const isConnected = this.registry.get('connected');
      conn.style.background = isConnected ? '#4f4' : '#f44';
      conn.style.boxShadow = isConnected ? '0 0 6px #4f4' : 'none';
    }

    const tick = document.getElementById('hud-tick');
    if (tick) tick.textContent = 'Tick: ' + (this.snapshot.tick || 0);

    const period = document.getElementById('hud-period');
    if (period) period.textContent = PERIOD_LABELS[this.snapshot.dayPeriod] || this.snapshot.dayPeriod;

    // Badge
    const badge = document.getElementById('hud-req-badge');
    const reqCount = (this.snapshot.pendingRequests || []).length;
    if (badge) {
      if (reqCount > 0) {
        badge.style.display = 'flex';
        badge.textContent = String(reqCount);
      } else {
        badge.style.display = 'none';
      }
    }

    // Update active panel content
    if (this.activePanel) {
      this.renderPanel();
    }
  }

  private renderPanel() {
    const panelEl = document.getElementById('hud-panel');
    if (!panelEl || !this.snapshot) return;

    switch (this.activePanel) {
      case 'agents':
        panelEl.innerHTML = this.renderAgentsPanel(this.snapshot.agents || []);
        break;
      case 'food':
        panelEl.innerHTML = this.renderFoodPanel();
        break;
      case 'requests':
        panelEl.innerHTML = this.renderRequestsPanel(this.snapshot.pendingRequests || []);
        break;
      case 'events':
        panelEl.innerHTML = this.renderEventsPanel(this.snapshot.recentEvents || []);
        break;
    }
  }

  private renderAgentsPanel(agents: AgentSnapshot[]): string {
    if (!agents.length) return '<div style="text-align:center;padding:24px;opacity:0.4;font-size:13px">אין סוכנים</div>';

    return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">🦀 סוכנים</div>' +
      agents.map(a => {
        const needs = a.needs || {};
        const needBars = Object.entries(needs).map(([k, v]) => {
          const m = NEED_META[k] || { icon: 'need-hunger', label: k, color: '#888' };
          const pct = Math.round(v * 100);
          const fallback = ICON_FALLBACK[m.icon] || '❓';
          return `<div style="display:flex;align-items:center;gap:6px;font-size:10px">
            <span style="width:14px;text-align:center">${fallback}</span>
            <span style="width:42px;opacity:0.6">${m.label}</span>
            <div style="flex:1;height:6px;border-radius:3px;background:rgba(255,255,255,0.1);overflow:hidden">
              <div style="width:${pct}%;height:100%;border-radius:3px;background:${m.color};transition:width 0.5s"></div>
            </div>
            <span style="width:28px;text-align:left;opacity:0.5;font-size:9px">${pct}%</span>
          </div>`;
        }).join('');

        const goalText = STATE_LABELS[a.state] || a.currentGoal || a.state || '';
        const speechText = a.currentSpeech
          ? `<div style="font-size:10px;opacity:0.7;margin-top:3px;font-style:italic">"${a.currentSpeech.length > 40 ? a.currentSpeech.substring(0, 40) + '...' : a.currentSpeech}"</div>`
          : '';

        return `<div class="hud-agent-card" data-id="${a.id}" style="display:flex;align-items:center;gap:10px;padding:10px;border-radius:12px;margin-bottom:8px;cursor:pointer;transition:background 0.2s" onmouseover="this.style.background='rgba(255,255,255,0.08)'" onmouseout="this.style.background='transparent'">
          <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:700;color:#fff;background:${a.badgeColor || '#E8734A'};flex-shrink:0">${a.name?.charAt(0) || '?'}</div>
          <div style="flex:1;min-width:0">
            <div style="font-weight:600;font-size:14px">${a.name || ''} ${a.moodEmoji || ''}</div>
            <div style="font-size:11px;opacity:0.6">${a.role || ''} · ${goalText}</div>
            ${speechText}
            <div style="display:flex;flex-direction:column;gap:3px;margin-top:6px">${needBars}</div>
          </div>
        </div>`;
      }).join('');
  }

  private renderFoodPanel(): string {
    const foodButtons = FOODS.map((f, i) =>
      `<div class="hud-food-btn" data-idx="${i}" style="background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.1);border-radius:12px;padding:12px 4px;text-align:center;cursor:pointer;font-size:24px;user-select:none;transition:all 0.2s" onmouseover="this.style.borderColor='#D4AF37';this.style.background='rgba(255,255,255,0.2)'" onmouseout="this.style.borderColor='rgba(255,255,255,0.1)';this.style.background='rgba(255,255,255,0.08)'">
        ${f.emoji}
        <div style="font-size:10px;margin-top:4px;opacity:0.7">${f.name}</div>
      </div>`
    ).join('');

    return `<div style="font-size:16px;font-weight:700;margin-bottom:12px">🥙 אוכל טורקי</div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px">${foodButtons}</div>
      <div style="text-align:center;font-size:12px;opacity:0.5;margin-top:12px">בחר אוכל ולחץ על המפה, או:</div>
      <button id="hud-quick-drop" style="display:block;width:100%;margin-top:12px;padding:14px;border-radius:12px;border:2px dashed rgba(212,175,55,0.5);background:rgba(212,175,55,0.1);color:#D4AF37;font-size:14px;font-weight:600;cursor:pointer;text-align:center;font-family:inherit">🎲 זרוק אוכל אקראי למרכז</button>`;
  }

  private renderRequestsPanel(requests: RequestSnapshot[]): string {
    if (!requests.length) {
      return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">📋 בקשות</div>' +
        '<div style="text-align:center;padding:24px;opacity:0.4;font-size:13px">אין בקשות ממתינות 🎉</div>';
    }

    const typeIcons: Record<string, string> = {
      food: '🥙', buildPermission: '🔨', tool: '🔧', vacation: '🏖', raise: '💰', general: '📋',
    };

    return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">📋 בקשות</div>' +
      requests.map(r => {
        const icon = typeIcons[r.type] || '📋';
        return `<div style="background:rgba(255,255,255,0.06);border-radius:12px;padding:12px;margin-bottom:8px">
          <div style="font-weight:600;font-size:13px">${r.fromName || ''} · ${icon}</div>
          <div style="font-size:12px;opacity:0.8;margin:6px 0">${r.message || ''}</div>
          <div style="display:flex;gap:8px">
            <button class="hud-approve-btn" data-id="${r.id}" style="flex:1;padding:10px;border-radius:8px;border:none;font-size:14px;font-weight:600;cursor:pointer;background:#2d8a4e;color:#fff;font-family:inherit">✅ אישור</button>
            <button class="hud-deny-btn" data-id="${r.id}" style="flex:1;padding:10px;border-radius:8px;border:none;font-size:14px;font-weight:600;cursor:pointer;background:#8a2d2d;color:#fff;font-family:inherit">❌ דחייה</button>
          </div>
        </div>`;
      }).join('');
  }

  private renderEventsPanel(events: { type: string; agentID: string; message: string; timestamp: number }[]): string {
    if (!events.length) {
      return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">📜 אירועים</div>' +
        '<div style="text-align:center;padding:24px;opacity:0.4;font-size:13px">אין אירועים עדיין</div>';
    }

    return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">📜 אירועים</div>' +
      events.slice().reverse().map(e => {
        let time = '';
        if (e.timestamp) {
          const d = new Date(typeof e.timestamp === 'number' && e.timestamp < 1e12 ? e.timestamp * 1000 : e.timestamp);
          time = d.toLocaleTimeString('he-IL', { hour: '2-digit', minute: '2-digit' });
        }
        return `<div style="padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.05);font-size:12px;opacity:0.8">
          <span style="font-size:10px;opacity:0.5">${time}</span> ${e.message || ''}
        </div>`;
      }).join('');
  }

  private showToast(msg: string) {
    const el = document.getElementById('hud-toast');
    if (!el) return;
    el.textContent = msg;
    el.style.display = 'block';
    el.style.animation = 'none';
    el.offsetHeight; // Force reflow
    el.style.animation = 'toastIn 0.3s ease-out';
    setTimeout(() => { el.style.display = 'none'; }, 2000);
  }
}
