import Foundation

/// Agent needs — decay over time from 0.0 (fulfilled) to 1.0 (desperate)
struct AgentNeeds: Codable {
    var hunger: Double = 0.0
    var social: Double = 0.0
    var creativity: Double = 0.0
    var workDrive: Double = 0.0
    var rest: Double = 0.0

    /// Clamp all values to 0...1
    mutating func clamp() {
        hunger = min(1, max(0, hunger))
        social = min(1, max(0, social))
        creativity = min(1, max(0, creativity))
        workDrive = min(1, max(0, workDrive))
        rest = min(1, max(0, rest))
    }
}

/// Personality-specific need decay rates (per minute)
struct NeedDecayRates {
    let hunger: Double
    let social: Double
    let creativity: Double
    let workDrive: Double
    let rest: Double

    static func forAgent(_ id: AgentID) -> NeedDecayRates {
        switch id {
        case .eyal:
            // Product manager: high work drive, medium social
            return NeedDecayRates(hunger: 0.008, social: 0.006, creativity: 0.003, workDrive: 0.010, rest: 0.004)
        case .yael:
            // Designer: high creativity, medium social
            return NeedDecayRates(hunger: 0.008, social: 0.006, creativity: 0.010, workDrive: 0.005, rest: 0.004)
        case .ido:
            // Backend: high work drive, high rest (burns out fast)
            return NeedDecayRates(hunger: 0.007, social: 0.003, creativity: 0.004, workDrive: 0.010, rest: 0.008)
        case .roni:
            // QA: high social, medium creativity
            return NeedDecayRates(hunger: 0.008, social: 0.009, creativity: 0.005, workDrive: 0.006, rest: 0.004)
        }
    }
}

enum AgentMood: String, Codable, CaseIterable {
    case happy
    case content
    case bored
    case hungry
    case social
    case creative
    case tired
    case excited

    /// Determine mood from current needs
    static func fromNeeds(_ needs: AgentNeeds) -> AgentMood {
        // Find the dominant need
        let pairs: [(Double, AgentMood)] = [
            (needs.hunger, .hungry),
            (needs.social, .social),
            (needs.creativity, .creative),
            (needs.rest, .tired),
        ]

        // If any need is above 0.7, that becomes the mood
        if let dominant = pairs.max(by: { $0.0 < $1.0 }), dominant.0 > 0.7 {
            return dominant.1
        }
        // If all needs are low, agent is happy
        if needs.hunger < 0.3 && needs.social < 0.3 && needs.rest < 0.3 {
            return .happy
        }
        return .content
    }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .content: return "🙂"
        case .bored: return "😐"
        case .hungry: return "🤤"
        case .social: return "🗣️"
        case .creative: return "🎨"
        case .tired: return "😴"
        case .excited: return "🤩"
        }
    }

    var iconName: String {
        switch self {
        case .happy: return "mood-happy"
        case .content: return "mood-content"
        case .bored: return "mood-bored"
        case .hungry: return "mood-hungry"
        case .social: return "mood-social"
        case .creative: return "mood-creative"
        case .tired: return "mood-tired"
        case .excited: return "mood-excited"
        }
    }
}

enum AgentGoal: Codable, Equatable {
    case eat
    case socialize(with: AgentID)
    case work(at: ProjectID)
    case build(type: String)
    case rest(at: CGPoint)
    case explore
    case requestFromAlon(message: String)
    case idle

    var description: String {
        switch self {
        case .eat: return "מחפש אוכל"
        case .socialize(let with): return "מדבר עם \(AgentDefinition.find(with).nameHebrew)"
        case .work(let at): return "עובד ב-\(ProjectDefinition.find(at).nameHebrew)"
        case .build(let type): return "בונה \(type)"
        case .rest: return "נח"
        case .explore: return "מטייל בכפר"
        case .requestFromAlon(let msg): return "מבקש: \(msg)"
        case .idle: return "מחכה"
        }
    }
}

/// Conversation memory entry
struct ConversationMemory: Codable {
    let withAgent: AgentID
    let topic: String
    let time: Date
}

/// Build history entry
struct BuildMemory: Codable {
    let structureType: String
    let position: CGPoint
    let time: Date
}

/// Agent's persistent memory
struct AgentMemory: Codable {
    var recentConversations: [ConversationMemory] = []
    var buildHistory: [BuildMemory] = []
    var requestHistory: [AgentRequest] = []

    /// Keep memory bounded
    mutating func trim() {
        if recentConversations.count > 20 {
            recentConversations = Array(recentConversations.suffix(20))
        }
        if buildHistory.count > 50 {
            buildHistory = Array(buildHistory.suffix(50))
        }
        if requestHistory.count > 20 {
            requestHistory = Array(requestHistory.suffix(20))
        }
    }
}

/// Full agent state — drives all autonomous behavior
class AgentState: Codable {
    let agentID: AgentID
    var needs: AgentNeeds
    var mood: AgentMood
    var memory: AgentMemory
    var currentGoal: AgentGoal
    var position: CGPoint
    var lastUpdate: Date
    let decayRates: NeedDecayRates

    init(agentID: AgentID, position: CGPoint) {
        self.agentID = agentID
        self.needs = AgentNeeds()
        self.mood = .content
        self.memory = AgentMemory()
        self.currentGoal = .idle
        self.position = position
        self.lastUpdate = Date()
        self.decayRates = NeedDecayRates.forAgent(agentID)
    }

    // Custom Codable for NeedDecayRates (computed, not stored)
    enum CodingKeys: String, CodingKey {
        case agentID, needs, mood, memory, currentGoal, position, lastUpdate
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        agentID = try c.decode(AgentID.self, forKey: .agentID)
        needs = try c.decode(AgentNeeds.self, forKey: .needs)
        mood = try c.decode(AgentMood.self, forKey: .mood)
        memory = try c.decode(AgentMemory.self, forKey: .memory)
        currentGoal = try c.decode(AgentGoal.self, forKey: .currentGoal)
        position = try c.decode(CGPoint.self, forKey: .position)
        lastUpdate = try c.decode(Date.self, forKey: .lastUpdate)
        decayRates = NeedDecayRates.forAgent(agentID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(agentID, forKey: .agentID)
        try c.encode(needs, forKey: .needs)
        try c.encode(mood, forKey: .mood)
        try c.encode(memory, forKey: .memory)
        try c.encode(currentGoal, forKey: .currentGoal)
        try c.encode(position, forKey: .position)
        try c.encode(lastUpdate, forKey: .lastUpdate)
    }

    /// Update needs based on elapsed time
    func decayNeeds(deltaMinutes: Double) {
        needs.hunger += decayRates.hunger * deltaMinutes
        needs.social += decayRates.social * deltaMinutes
        needs.creativity += decayRates.creativity * deltaMinutes
        needs.workDrive += decayRates.workDrive * deltaMinutes
        needs.rest += decayRates.rest * deltaMinutes
        needs.clamp()
        mood = AgentMood.fromNeeds(needs)
    }

    /// Satisfy a need (e.g., after eating, socializing)
    func satisfy(_ keyPath: WritableKeyPath<AgentNeeds, Double>, by amount: Double = 0.5) {
        needs[keyPath: keyPath] = max(0, needs[keyPath: keyPath] - amount)
        mood = AgentMood.fromNeeds(needs)
    }
}
