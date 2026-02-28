import Foundation

/// Everything a renderer/viewer needs to draw one frame — the rendering contract
public struct SimulationSnapshot: Codable, Sendable {
    public let tick: UInt64
    public let timestamp: Double
    public let dayPeriod: String  // "morning", "day", "evening", "night"
    public let agents: [AgentSnapshot]
    public let structures: [StructureSnapshot]
    public let foods: [FoodSnapshot]
    public let houses: [HouseSnapshot]
    public let recentEvents: [EventSnapshot]
    public let pendingRequests: [RequestSnapshot]

    public struct AgentSnapshot: Codable, Sendable {
        public let id: String
        public let name: String
        public let role: String
        public let position: Vec2
        public let state: String  // "idle", "walking", "working", "building", "eating", "talking", "resting"
        public let mood: String
        public let moodEmoji: String
        public let currentGoal: String
        public let currentSpeech: String?
        public let speechHash: String?
        public let facingLeft: Bool
        public let badgeColor: String  // hex
        public let needs: [String: Double]
        // v2.0: velocity for client-side prediction
        public let velocityX: Double
        public let velocityY: Double
        public let moveTarget: Vec2?
        public let moveSpeed: Double
    }

    public struct StructureSnapshot: Codable, Sendable {
        public let id: String
        public let type: String
        public let position: Vec2
        public let builder: String
        public let buildDate: Double
    }

    public struct FoodSnapshot: Codable, Sendable {
        public let position: Vec2
        public let emoji: String
        public let name: String
        public let isBeingEaten: Bool
    }

    public struct HouseSnapshot: Codable, Sendable {
        public let id: String
        public let name: String
        public let emoji: String
        public let position: Vec2
        public let roofColor: String
        public let wallColor: String
        public let isActive: Bool
        public let fileCount: Int
        public let activeTasks: Int
    }

    public struct EventSnapshot: Codable, Sendable {
        public let type: String
        public let agentID: String
        public let message: String
        public let timestamp: Double
    }

    public struct RequestSnapshot: Codable, Sendable {
        public let id: String
        public let from: String
        public let fromName: String
        public let message: String
        public let type: String
        public let timestamp: Double
    }
}
