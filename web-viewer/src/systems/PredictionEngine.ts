import { AgentSnapshot } from '../types/snapshot';

export interface PredictedPosition {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

export class PredictionEngine {
  private predictions = new Map<string, PredictedPosition>();

  onSnapshotReceived(agents: AgentSnapshot[]) {
    for (const a of agents) {
      const newVx = a.velocityX || 0;
      const newVy = a.velocityY || 0;
      const pred = this.predictions.get(a.id);

      if (!pred) {
        this.predictions.set(a.id, {
          x: a.position.x,
          y: a.position.y,
          vx: newVx,
          vy: newVy,
        });
      } else {
        // Adaptive LERP: bigger error → faster correction
        const error = Math.hypot(a.position.x - pred.x, a.position.y - pred.y);
        let rate: number;
        if (error > 80) rate = 0.7;
        else if (error > 40) rate = 0.45;
        else if (error > 15) rate = 0.25;
        else rate = 0.12;

        // Direction change detection — snap faster if direction reversed
        const dot = pred.vx * newVx + pred.vy * newVy;
        if (dot < 0) rate = Math.max(rate, 0.5);

        pred.x += (a.position.x - pred.x) * rate;
        pred.y += (a.position.y - pred.y) * rate;

        // Velocity smoothing
        pred.vx += (newVx - pred.vx) * 0.4;
        pred.vy += (newVy - pred.vy) * 0.4;
      }
    }
  }

  update(dt: number) {
    for (const pred of this.predictions.values()) {
      pred.x += pred.vx * dt;
      pred.y += pred.vy * dt;
    }
  }

  getPosition(id: string): PredictedPosition | undefined {
    return this.predictions.get(id);
  }
}
