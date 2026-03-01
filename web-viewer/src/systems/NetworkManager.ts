import { SimulationSnapshot } from '../types/snapshot';
import { POLL_INTERVAL } from '../config/constants';

export class NetworkManager {
  onSnapshot: ((snap: SimulationSnapshot) => void) | null = null;
  onReturnSummary: ((summary: string) => void) | null = null;
  onReconnecting: ((seconds: number) => void) | null = null;
  lastDayPeriod: string = 'day';
  connected = false;

  private pollingInterval: ReturnType<typeof setInterval> | null = null;
  private presenceInterval: ReturnType<typeof setInterval> | null = null;
  private tickSaveInterval: ReturnType<typeof setInterval> | null = null;
  private ws: WebSocket | null = null;
  private wsPingInterval: ReturnType<typeof setInterval> | null = null;
  private lastTick = 0;

  // Exponential backoff
  private wsReconnectDelay = 1000;
  private readonly WS_MAX_DELAY = 30000;
  private wsReconnectAttempt = 0;

  start() {
    this.startPolling();
    this.connectWebSocket();
    this.sendConnect();
    this.presenceInterval = setInterval(() => this.sendPresence(), 10000);
    this.tickSaveInterval = setInterval(() => {
      if (this.lastTick > 0) {
        localStorage.setItem('cv_lastTick', String(this.lastTick));
      }
    }, 5000);
  }

  private startPolling() {
    this.poll();
    this.pollingInterval = setInterval(() => this.poll(), POLL_INTERVAL);
  }

  private async poll() {
    try {
      const resp = await fetch('/api/snapshot');
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data: SimulationSnapshot = await resp.json();
      if (!data.agents) return;
      this.connected = true;
      this.lastDayPeriod = data.dayPeriod;
      this.lastTick = data.tick;
      this.onSnapshot?.(data);
    } catch {
      this.connected = false;
    }
  }

  private connectWebSocket() {
    try {
      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      this.ws = new WebSocket(proto + '//' + location.host + '/ws');

      this.ws.onopen = () => {
        // Reset backoff on successful connection
        this.wsReconnectDelay = 1000;
        this.wsReconnectAttempt = 0;
        this.connected = true;

        if (this.wsPingInterval) clearInterval(this.wsPingInterval);
        this.wsPingInterval = setInterval(() => {
          if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ action: 'ping' }));
          }
        }, 5000);
      };

      this.ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.action) return; // control frame (pong)
          if (!data.agents) return;
          this.connected = true;
          this.lastDayPeriod = data.dayPeriod;
          this.lastTick = data.tick;
          this.onSnapshot?.(data);
        } catch {
          console.warn('[WS] Failed to parse message');
        }
      };

      this.ws.onclose = () => {
        if (this.wsPingInterval) clearInterval(this.wsPingInterval);
        this.connected = false;

        // Exponential backoff with jitter
        const delay = Math.min(
          this.wsReconnectDelay * Math.pow(1.5, this.wsReconnectAttempt),
          this.WS_MAX_DELAY,
        ) + Math.random() * 1000;

        this.wsReconnectAttempt++;
        this.onReconnecting?.(Math.round(delay / 1000));

        setTimeout(() => this.connectWebSocket(), delay);
      };

      this.ws.onerror = () => {
        if (this.wsPingInterval) clearInterval(this.wsPingInterval);
        try { this.ws?.close(); } catch { /* ignore */ }
      };
    } catch {
      // WebSocket not available — polling handles everything
    }
  }

  async dropFood(x: number, y: number, emoji: string, name: string) {
    await fetch('/api/food', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ x, y, emoji, name }),
    }).catch(() => {});
  }

  async approveRequest(id: string) {
    await fetch('/api/requests/' + id + '/approve', { method: 'POST' }).catch(() => {});
  }

  async denyRequest(id: string) {
    await fetch('/api/requests/' + id + '/deny', { method: 'POST' }).catch(() => {});
  }

  private async sendPresence() {
    await fetch('/api/presence', { method: 'POST' }).catch(() => {});
  }

  private async sendConnect() {
    const lastTick = parseInt(localStorage.getItem('cv_lastTick') || '0');
    try {
      const resp = await fetch('/api/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lastTick }),
      });
      const data = await resp.json();
      if (data.summary) {
        this.onReturnSummary?.(data.summary);
      }
    } catch { /* ignore */ }
  }

  destroy() {
    if (this.pollingInterval) clearInterval(this.pollingInterval);
    if (this.presenceInterval) clearInterval(this.presenceInterval);
    if (this.tickSaveInterval) clearInterval(this.tickSaveInterval);
    if (this.wsPingInterval) clearInterval(this.wsPingInterval);
    if (this.ws) this.ws.close();
  }
}
