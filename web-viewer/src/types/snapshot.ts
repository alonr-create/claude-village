// Mirrors VillageSimulation/SimulationSnapshot.swift exactly

export interface Vec2 {
  x: number;
  y: number;
}

export interface SimulationSnapshot {
  tick: number;
  timestamp: number;
  dayPeriod: 'morning' | 'day' | 'evening' | 'night';
  agents: AgentSnapshot[];
  structures: StructureSnapshot[];
  foods: FoodSnapshot[];
  houses: HouseSnapshot[];
  recentEvents: EventSnapshot[];
  pendingRequests: RequestSnapshot[];
}

export interface AgentSnapshot {
  id: string;
  name: string;
  role: string;
  position: Vec2;
  state: string; // idle, walking, working, building, eating, talking, resting
  mood: string;
  moodEmoji: string;
  moodIcon: string;
  currentGoal: string;
  currentSpeech: string | null;
  speechHash: string | null;
  facingLeft: boolean;
  badgeColor: string; // hex e.g. '#3366EE'
  needs: Record<string, number>; // hunger, social, creativity, workDrive, rest (0..1)
  velocityX: number;
  velocityY: number;
  moveTarget: Vec2 | null;
  moveSpeed: number;
}

export interface StructureSnapshot {
  id: string;
  type: string;
  position: Vec2;
  builder: string;
  buildDate: number;
}

export interface FoodSnapshot {
  position: Vec2;
  emoji: string;
  icon: string;
  name: string;
  isBeingEaten: boolean;
}

export interface HouseSnapshot {
  id: string;
  name: string;
  emoji: string;
  icon: string;
  position: Vec2;
  roofColor: string;
  wallColor: string;
  isActive: boolean;
  fileCount: number;
  activeTasks: number;
}

export interface EventSnapshot {
  type: string;
  agentID: string;
  message: string;
  timestamp: number;
}

export interface RequestSnapshot {
  id: string;
  from: string;
  fromName: string;
  message: string;
  type: string;
  timestamp: number;
}
