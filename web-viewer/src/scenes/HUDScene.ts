import Phaser from 'phaser';
import { SimulationSnapshot, AgentSnapshot, RequestSnapshot } from '../types/snapshot';
import { FOODS, ICON_FALLBACK, NEED_META, STATE_LABELS, PERIOD_LABELS, NEED_COLORS_HEX } from '../config/constants';
import { VillageScene } from './VillageScene';

/**
 * HUD rendered directly on document.body (NOT via Phaser DOM) to avoid
 * `position: fixed` being broken by Phaser's transform container.
 */
export class HUDScene extends Phaser.Scene {
  private activePanel: string | null = null;
  private snapshot: SimulationSnapshot | null = null;
  private lastUIUpdate = 0;

  constructor() {
    super('HUDScene');
  }

  create() {
    // Inject all HUD HTML directly into document.body
    this.injectHUD();

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

    villageScene.events.on('returnSummary', (summary: string) => {
      this.showReturnPanel(summary);
    });

    villageScene.events.on('reconnecting', (seconds: number) => {
      this.showToast(`מתחבר מחדש... (${seconds}s)`);
    });
  }

  private injectHUD() {
    // Remove any existing HUD (hot reload safety)
    document.getElementById('hud-root')?.remove();

    const root = document.createElement('div');
    root.id = 'hud-root';
    root.innerHTML = `
      <style>
        #hud-root { position: fixed; inset: 0; pointer-events: none; z-index: 1000; font-family: -apple-system, 'Segoe UI', Roboto, sans-serif; direction: rtl; }
        #hud-root * { pointer-events: auto; }
        #hud-root [data-no-click] { pointer-events: none; }
        @keyframes toastSlideIn { from { opacity:0; transform:translateY(-20px); } to { opacity:1; transform:translateY(0); } }
        @keyframes toastSlideOut { from { opacity:1; transform:translateY(0); } to { opacity:0; transform:translateY(-20px); } }
        @keyframes hudPulse { 0%,100% { transform: translate(-50%,-50%) scale(1); } 50% { transform: translate(-50%,-50%) scale(1.05); } }
        .hud-tab:hover { background: rgba(255,255,255,0.1) !important; }
        .hud-tab:active { background: rgba(255,255,255,0.2) !important; }
      </style>

      <!-- Status bar (top) -->
      <div id="hud-status" style="
        position: fixed; top: 0; left: 0; right: 0;
        padding: 8px 16px; padding-top: max(8px, env(safe-area-inset-top));
        background: rgba(0,0,0,0.7); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
        display: flex; justify-content: space-between; align-items: center;
        font-size: 13px; color: #fff;
      ">
        <div>
          <span style="font-weight:700;font-size:15px">Claude Farm</span>
          <span id="hud-conn" style="display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:8px;background:#f44"></span>
        </div>
        <div style="opacity:0.7;font-size:11px;display:flex;align-items:center;gap:6px">
          <span id="hud-tick">Tick: 0</span>
          <span>&middot;</span>
          <span id="hud-period">יום</span>
          <span>&middot;</span>
          <span id="hud-sound-btn" style="cursor:pointer;font-size:16px">🔇</span>
        </div>
      </div>

      <!-- Food mode overlay -->
      <div id="hud-food-mode" style="
        position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
        background: rgba(212,175,55,0.9); color: #000; padding: 14px 28px;
        border-radius: 24px; font-size: 16px; font-weight: 700;
        display: none; animation: hudPulse 1.5s ease-in-out infinite;
      " data-no-click>🥙 לחץ על המפה להזריק אוכל!</div>

      <!-- Toast container -->
      <div id="hud-toast-container" style="
        position: fixed; top: 55px; left: 50%; transform: translateX(-50%);
        display: flex; flex-direction: column; gap: 8px;
        align-items: center;
      " data-no-click></div>

      <!-- Return panel -->
      <div id="hud-return-panel" style="
        position: fixed; top: 55px; left: 16px; right: 16px;
        background: rgba(20,30,50,0.95); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
        border-radius: 16px; padding: 20px; z-index: 1010;
        display: none; color: #fff; max-height: 40vh; overflow-y: auto;
        border: 1px solid rgba(100,150,255,0.3); box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      ">
        <div style="font-size:18px;font-weight:700;margin-bottom:12px">👋 ברוך שובך, אלון!</div>
        <div id="hud-return-content" style="font-size:14px;line-height:1.8"></div>
        <button id="hud-return-dismiss" style="display:block;width:100%;margin-top:16px;padding:14px;border-radius:12px;border:none;background:rgba(255,255,255,0.15);color:#fff;font-size:15px;font-weight:600;cursor:pointer;font-family:inherit">סגור</button>
      </div>

      <!-- Content panel (opens above toolbar) -->
      <div id="hud-panel" style="
        position: fixed; bottom: 72px; left: 8px; right: 8px; max-height: 50vh;
        overflow-y: auto; background: rgba(20,30,20,0.95);
        backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
        border-radius: 16px; padding: 16px;
        display: none; border: 1px solid rgba(255,255,255,0.12);
        color: #fff;
      "></div>

      <!-- Bottom toolbar -->
      <div id="hud-toolbar" style="
        position: fixed; bottom: 0; left: 0; right: 0;
        padding: 6px 8px; padding-bottom: max(8px, env(safe-area-inset-bottom));
        background: rgba(0,0,0,0.8); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
        display: flex; gap: 4px;
      ">
        <div class="hud-tab" data-panel="agents" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none;transition:background 0.2s">
          <div style="font-size:20px">👨‍🌾</div>חקלאים
        </div>
        <div class="hud-tab" data-panel="food" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none;transition:background 0.2s">
          <div style="font-size:20px">🥙</div>אוכל
        </div>
        <div class="hud-tab" data-panel="requests" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none;position:relative;transition:background 0.2s">
          <div style="font-size:20px">📋</div>בקשות
          <span id="hud-req-badge" style="position:absolute;top:4px;right:4px;background:#f44;color:#fff;font-size:10px;font-weight:700;min-width:16px;height:16px;border-radius:8px;display:none;align-items:center;justify-content:center;padding:0 4px"></span>
        </div>
        <div class="hud-tab" data-panel="events" style="flex:1;text-align:center;padding:10px 4px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;color:#fff;user-select:none;transition:background 0.2s">
          <div style="font-size:20px">📜</div>אירועים
        </div>
      </div>
    `;
    document.body.appendChild(root);
  }

  private setupEventListeners() {
    document.addEventListener('click', (e) => {
      const target = e.target as HTMLElement;
      const tab = target.closest('.hud-tab') as HTMLElement | null;
      if (tab) {
        const panel = tab.dataset.panel;
        if (!panel) return;

        const panelEl = document.getElementById('hud-panel');
        if (!panelEl) return;

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
        this.activePanel = null;
        const panelEl = document.getElementById('hud-panel');
        if (panelEl) panelEl.style.display = 'none';
        document.querySelectorAll('.hud-tab').forEach(t => {
          (t as HTMLElement).style.background = 'transparent';
        });
      }

      // Return panel dismiss
      if (target.id === 'hud-return-dismiss') {
        const panel = document.getElementById('hud-return-panel');
        if (panel) panel.style.display = 'none';
      }
    });
  }

  private updateUI() {
    if (!this.snapshot) return;

    const now = Date.now();
    if (now - this.lastUIUpdate < 1000) return;
    this.lastUIUpdate = now;

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
    if (!agents.length) return '<div style="text-align:center;padding:24px;opacity:0.4;font-size:13px">אין חקלאים</div>';

    return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">👨‍🌾 חקלאים</div>' +
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
      `<div class="hud-food-btn" data-idx="${i}" style="background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.1);border-radius:12px;padding:12px 4px;text-align:center;cursor:pointer;user-select:none;transition:all 0.2s" onmouseover="this.style.borderColor='#D4AF37';this.style.background='rgba(255,255,255,0.2)'" onmouseout="this.style.borderColor='rgba(255,255,255,0.1)';this.style.background='rgba(255,255,255,0.08)'">
        <img src="/icons/${f.icon}.png" alt="${f.name}" style="width:40px;height:40px;object-fit:contain" onerror="this.outerHTML='<span style=font-size:24px>${f.emoji}</span>'">
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

    const eventIcons: Record<string, string> = {
      conversation: '💬', eat: '🍽', build_request: '🔨',
      build_complete: '🏗', request: '📋', mood_change: '🎭',
      food_drop: '🥙', auto_manage: '📋', callout: '📢',
    };
    const eventColors: Record<string, string> = {
      conversation: 'rgba(100,200,200,0.15)', eat: 'rgba(212,175,55,0.15)',
      build_request: 'rgba(200,150,50,0.15)', build_complete: 'rgba(50,200,100,0.15)',
      request: 'rgba(150,150,200,0.15)', mood_change: 'rgba(200,100,200,0.15)',
      food_drop: 'rgba(212,175,55,0.15)', auto_manage: 'rgba(100,150,255,0.15)',
      callout: 'rgba(255,100,100,0.15)',
    };

    return '<div style="font-size:16px;font-weight:700;margin-bottom:12px">📜 אירועים</div>' +
      events.slice().reverse().map(e => {
        let time = '';
        if (e.timestamp) {
          const d = new Date(typeof e.timestamp === 'number' && e.timestamp < 1e12 ? e.timestamp * 1000 : e.timestamp);
          time = d.toLocaleTimeString('he-IL', { hour: '2-digit', minute: '2-digit' });
        }
        const icon = eventIcons[e.type] || '📌';
        const bg = eventColors[e.type] || 'rgba(255,255,255,0.05)';

        return `<div style="display:flex;gap:8px;padding:8px;border-radius:8px;margin-bottom:4px;background:${bg};align-items:center">
          <span style="font-size:16px;flex-shrink:0">${icon}</span>
          <div style="flex:1;min-width:0">
            <div style="font-size:12px">${e.message || ''}</div>
            <div style="font-size:10px;opacity:0.4;margin-top:2px">${time}</div>
          </div>
        </div>`;
      }).join('');
  }

  private toastCount = 0;

  private showToast(msg: string) {
    const container = document.getElementById('hud-toast-container');
    if (!container) return;

    if (container.children.length >= 3) {
      container.removeChild(container.firstChild!);
    }

    const id = 'toast-' + (++this.toastCount);
    const toast = document.createElement('div');
    toast.id = id;
    toast.textContent = msg;
    toast.style.cssText = `
      background: rgba(45,138,78,0.95); color: #fff; padding: 10px 20px;
      border-radius: 20px; font-size: 13px; font-weight: 600;
      animation: toastSlideIn 0.3s ease-out; white-space: nowrap;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3); pointer-events: auto;
    `;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.animation = 'toastSlideOut 0.3s ease-in forwards';
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }

  private showReturnPanel(summary: string) {
    const panel = document.getElementById('hud-return-panel');
    const content = document.getElementById('hud-return-content');
    if (!panel || !content) return;

    content.innerHTML = summary.split('\n').map(line =>
      `<div style="padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.05);font-size:14px">${line}</div>`
    ).join('');

    panel.style.display = 'block';

    const timer = setTimeout(() => { panel.style.display = 'none'; }, 15000);

    const dismissBtn = document.getElementById('hud-return-dismiss');
    if (dismissBtn) {
      dismissBtn.onclick = () => {
        clearTimeout(timer);
        panel.style.display = 'none';
      };
    }
  }
}
