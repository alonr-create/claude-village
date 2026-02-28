import Foundation

/// Agent state for the headless simulation
public class SimAgent: Codable, @unchecked Sendable {
    public let id: SimAgentID
    public let name: String
    public let role: String
    public var position: Vec2
    public var needs: SimNeeds
    public var mood: SimAgentMood
    public var currentGoal: SimGoal
    public var currentSpeech: String?
    public var speechExpiry: Date?

    public init(id: SimAgentID) {
        self.id = id
        switch id {
        case .eyal: name = "אייל"; role = "מנהל מוצר"
        case .yael: name = "יעל"; role = "מעצבת"
        case .ido: name = "עידו"; role = "באק-אנד"
        case .roni: name = "רוני"; role = "בודקת איכות"
        }
        position = Vec2(x: Double.random(in: -200...200), y: Double.random(in: -200...200))
        needs = SimNeeds()
        mood = .content
        currentGoal = SimGoal(type: .idle)
        currentSpeech = nil
        speechExpiry = nil
    }
}

public struct SimNeeds: Codable, Sendable {
    public var hunger: Double = 0.1
    public var social: Double = 0.1
    public var creativity: Double = 0.1
    public var workDrive: Double = 0.1
    public var rest: Double = 0.1

    mutating func clamp() {
        hunger = min(1, max(0, hunger))
        social = min(1, max(0, social))
        creativity = min(1, max(0, creativity))
        workDrive = min(1, max(0, workDrive))
        rest = min(1, max(0, rest))
    }
}

public struct SimGoal: Codable, Sendable {
    public var type: SimAgentGoalType
    public var target: Vec2?
    public var targetAgent: SimAgentID?
    public var detail: String?

    public init(type: SimAgentGoalType, target: Vec2? = nil, targetAgent: SimAgentID? = nil, detail: String? = nil) {
        self.type = type
        self.target = target
        self.targetAgent = targetAgent
        self.detail = detail
    }
}

public struct SimStructure: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: String
    public let position: Vec2
    public let builder: SimAgentID
    public let buildDate: Date
}

public struct SimFood: Codable, Sendable, Identifiable {
    public let id: UUID
    public let position: Vec2
    public let emoji: String
    public let name: String
    public var isBeingEaten: Bool
    public let dropTime: Date
}

public struct SimRequest: Codable, Sendable, Identifiable {
    public let id: UUID
    public let from: SimAgentID
    public let message: String
    public let type: String
    public let timestamp: Date
    public var status: String  // "pending", "approved", "denied"
}

public struct SimEvent: Codable, Sendable {
    public let type: String
    public let agentID: SimAgentID
    public let message: String
    public let timestamp: Date
}

/// House layout data
public struct SimHouse: Codable, Sendable {
    public let id: SimProjectID
    public let name: String
    public let emoji: String
    public let position: Vec2
    public let roofColor: String
    public let wallColor: String
    public var isActive: Bool
    public var fileCount: Int
    public var activeTasks: Int
}

/// The core headless simulation — no rendering, pure logic
public class SimulationLoop: @unchecked Sendable {
    public var agents: [SimAgentID: SimAgent] = [:]
    public var structures: [SimStructure] = []
    public var foods: [SimFood] = []
    public var requests: [SimRequest] = []
    public var events: [SimEvent] = []
    public var houses: [SimHouse] = []
    public var tick: UInt64 = 0
    private var lastTickTime = Date()

    // Turkish foods
    static let turkishFoods: [(emoji: String, name: String)] = [
        ("🥙", "דונר"), ("🍖", "איסקנדר"), ("🥟", "מנטי"), ("🫓", "לחמג׳ון"),
        ("🍢", "שיש קבב"), ("🧆", "כופתה"), ("🫕", "פידה"), ("🍚", "פילאף"),
        ("🍬", "באקלווה"), ("🫖", "צ׳אי"), ("☕", "קפה טורקי"),
    ]

    // Conversation templates
    static let conversationOpeners: [SimAgentID: [String]] = [
        .eyal: ["היי! יש לי תוכנית חדשה 📋", "בואו נסדר את הפרויקטים", "מה המצב עם הדדליינים?"],
        .yael: ["ראיתי עיצוב מדהים! 🎨", "צריך לשפר את ה-UI", "יש לי רעיון לאנימציה חדשה ✨"],
        .ido: ["בדקתי את הביצועים 🔧", "יש בעיית אבטחה", "כתבתי API חדש"],
        .roni: ["מצאתי באג! 🐛", "הטסטים נכשלו שוב...", "בדקתי את הפיצ׳ר החדש — יש בעיות"],
    ]

    // Build types per personality
    static let buildPreferences: [SimAgentID: [String]] = [
        .eyal: ["שלט", "ספסל", "לוח מודעות"],
        .yael: ["גן פרחים", "פנס", "גדר דקורטיבית"],
        .ido: ["גשר", "באר", "דרך"],
        .roni: ["ספסל תצפית", "גדר", "עמדת בדיקה"],
    ]

    // Need decay rates per agent
    static let decayRates: [SimAgentID: (h: Double, s: Double, c: Double, w: Double, r: Double)] = [
        .eyal: (0.008, 0.006, 0.003, 0.010, 0.004),
        .yael: (0.008, 0.006, 0.010, 0.005, 0.004),
        .ido:  (0.007, 0.003, 0.004, 0.010, 0.008),
        .roni: (0.008, 0.009, 0.005, 0.006, 0.004),
    ]

    public init() {
        setupHouses()
        setupAgents()
    }

    private func setupHouses() {
        houses = [
            SimHouse(id: .matzpen, name: "מצפן לעושר", emoji: "🧭", position: Vec2(x: -400, y: 200), roofColor: "#D4AF37", wallColor: "#1C0B2E", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .dekel, name: "דקל לפרישה", emoji: "🌴", position: Vec2(x: -400, y: -200), roofColor: "#1A6FC4", wallColor: "#0D2248", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .alonDev, name: "Alon.dev", emoji: "💻", position: Vec2(x: 400, y: 200), roofColor: "#8B5CF6", wallColor: "#0A0E1A", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .aliza, name: "עליזה המפרסמת", emoji: "📣", position: Vec2(x: 400, y: -200), roofColor: "#DD3333", wallColor: "#4A0E0E", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .boker, name: "הודעת בוקר", emoji: "🌅", position: Vec2(x: 0, y: 400), roofColor: "#10B981", wallColor: "#1F2937", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .games, name: "אפליקציות ומשחקים", emoji: "🎮", position: Vec2(x: 0, y: -400), roofColor: "#F59E0B", wallColor: "#1F2937", isActive: false, fileCount: 0, activeTasks: 0),
        ]
    }

    private func setupAgents() {
        for id in SimAgentID.allCases {
            let agent = SimAgent(id: id)
            let houseIndex = SimAgentID.allCases.firstIndex(of: id)! % houses.count
            agent.position = Vec2(
                x: houses[houseIndex].position.x + Double.random(in: -40...40),
                y: houses[houseIndex].position.y - 70
            )
            agents[id] = agent
        }
    }

    /// Main simulation tick — call every 2 seconds
    public func doTick() -> SimulationSnapshot {
        let now = Date()
        let deltaMinutes = now.timeIntervalSince(lastTickTime) / 60.0
        lastTickTime = now
        tick += 1

        // 1. Decay needs
        for (id, agent) in agents {
            let rates = SimulationLoop.decayRates[id]!
            agent.needs.hunger += rates.h * deltaMinutes
            agent.needs.social += rates.s * deltaMinutes
            agent.needs.creativity += rates.c * deltaMinutes
            agent.needs.workDrive += rates.w * deltaMinutes
            agent.needs.rest += rates.r * deltaMinutes
            agent.needs.clamp()
            agent.mood = determineMood(agent.needs)
        }

        // 2. Expire speech
        for (_, agent) in agents {
            if let expiry = agent.speechExpiry, now > expiry {
                agent.currentSpeech = nil
                agent.speechExpiry = nil
            }
        }

        // 3. Expire food (30 second timeout)
        foods.removeAll { now.timeIntervalSince($0.dropTime) > 30 && !$0.isBeingEaten }

        // 4. Decide & act for each agent
        for (_, agent) in agents {
            if agent.currentGoal.type == .idle || shouldReEvaluate(agent) {
                decideGoal(for: agent)
            }
            executeGoal(for: agent, deltaMinutes: deltaMinutes)
        }

        // 5. Check for spontaneous conversations
        checkConversations()

        // 6. Trim events
        if events.count > 50 { events = Array(events.suffix(50)) }

        return generateSnapshot()
    }

    // MARK: - Decision Making

    private func determineMood(_ needs: SimNeeds) -> SimAgentMood {
        if needs.hunger > 0.7 { return .hungry }
        if needs.rest > 0.7 { return .tired }
        if needs.social > 0.7 { return .social }
        if needs.creativity > 0.7 { return .creative }
        if needs.hunger < 0.3 && needs.rest < 0.3 { return .happy }
        return .content
    }

    private func shouldReEvaluate(_ agent: SimAgent) -> Bool {
        switch agent.currentGoal.type {
        case .idle: return true
        case .explore:
            if let target = agent.currentGoal.target {
                return agent.position.distance(to: target) < 10
            }
            return true
        case .work: return Double.random(in: 0...1) < 0.1
        case .eat: return foods.filter({ !$0.isBeingEaten }).isEmpty
        case .socialize: return Double.random(in: 0...1) < 0.05
        case .build: return Double.random(in: 0...1) < 0.08
        case .rest: return agent.needs.rest < 0.2
        case .request: return true
        }
    }

    private func decideGoal(for agent: SimAgent) {
        var candidates: [(SimGoal, Double)] = []

        // Eat
        if !foods.filter({ !$0.isBeingEaten }).isEmpty {
            candidates.append((SimGoal(type: .eat), agent.needs.hunger * 0.95))
        } else if agent.needs.hunger > 0.7 {
            let food = SimulationLoop.turkishFoods.randomElement()!
            let msg = "אלון, אני רעב! אפשר \(food.name) \(food.emoji)?"
            candidates.append((SimGoal(type: .request, detail: msg), agent.needs.hunger * 0.7))
        }

        // Socialize
        for (id, other) in agents where id != agent.id {
            let dist = agent.position.distance(to: other.position)
            let bonus = max(0, 1.0 - dist / 500.0) * 0.2
            candidates.append((SimGoal(type: .socialize, targetAgent: id), agent.needs.social * 0.8 + bonus))
        }

        // Build
        if agent.needs.creativity > 0.4 {
            let type = SimulationLoop.buildPreferences[agent.id]?.randomElement() ?? "מבנה"
            candidates.append((SimGoal(type: .build, detail: type), agent.needs.creativity * 0.85))
        }

        // Work
        let house = houses.randomElement()!
        candidates.append((SimGoal(type: .work, target: house.position), agent.needs.workDrive * 0.8))

        // Rest
        if agent.needs.rest > 0.5 {
            let spot = Vec2(x: Double.random(in: -200...200), y: Double.random(in: -200...200))
            candidates.append((SimGoal(type: .rest, target: spot), agent.needs.rest * 0.75))
        }

        // Explore
        candidates.append((SimGoal(type: .explore, target: houses.randomElement().map { $0.position }), 0.3))

        // Fun request (5% chance)
        if Double.random(in: 0...1) < 0.05 {
            let funReqs = ["אלון, מגיע לי חופשה! 🏖️", "אלון, אפשר העלאה? 💰", "אלון, צריך ריהוט חדש לכפר! 🪑"]
            candidates.append((SimGoal(type: .request, detail: funReqs.randomElement()!), 0.3))
        }

        // Pick highest utility with randomness
        guard !candidates.isEmpty else { return }
        let sorted = candidates.sorted { $0.1 > $1.1 }
        // Top-3 weighted random
        let top = Array(sorted.prefix(3))
        let totalWeight = top.reduce(0.0) { $0 + $1.1 + 0.01 }
        var r = Double.random(in: 0..<totalWeight)
        for item in top {
            r -= item.1 + 0.01
            if r <= 0 {
                agent.currentGoal = item.0
                return
            }
        }
        agent.currentGoal = top[0].0
    }

    private func executeGoal(for agent: SimAgent, deltaMinutes: Double) {
        switch agent.currentGoal.type {
        case .eat:
            if let food = foods.filter({ !$0.isBeingEaten }).min(by: {
                agent.position.distance(to: $0.position) < agent.position.distance(to: $1.position)
            }) {
                moveToward(agent, target: food.position, speed: 120)
                if agent.position.distance(to: food.position) < 15 {
                    if let idx = foods.firstIndex(where: { $0.id == food.id }) {
                        foods[idx].isBeingEaten = true
                        agent.needs.hunger = max(0, agent.needs.hunger - 0.6)
                        let thanks = ["!וואו! דונר! 😍", "!באקלווה! חיים טובים 🍬", "!קבב! הכי טעים 🍖", "!תודה אלון! יאמי 😋"]
                        speak(agent, text: thanks.randomElement()!, duration: 3)
                        events.append(SimEvent(type: "eat", agentID: agent.id, message: "\(agent.name) אכל \(food.name)", timestamp: Date()))
                        // Remove food after eating
                        foods.remove(at: idx)
                    }
                    agent.currentGoal = SimGoal(type: .idle)
                }
            } else {
                agent.currentGoal = SimGoal(type: .idle)
            }

        case .socialize:
            if let targetID = agent.currentGoal.targetAgent, let target = agents[targetID] {
                moveToward(agent, target: target.position, speed: 80)
                if agent.position.distance(to: target.position) < 60 {
                    let openers = SimulationLoop.conversationOpeners[agent.id] ?? ["שלום!"]
                    speak(agent, text: openers.randomElement()!, duration: 3)
                    agent.needs.social = max(0, agent.needs.social - 0.4)
                    target.needs.social = max(0, target.needs.social - 0.3)
                    events.append(SimEvent(type: "conversation", agentID: agent.id, message: "\(agent.name) דיבר עם \(target.name)", timestamp: Date()))
                    agent.currentGoal = SimGoal(type: .idle)
                }
            } else {
                agent.currentGoal = SimGoal(type: .idle)
            }

        case .work:
            if let target = agent.currentGoal.target {
                moveToward(agent, target: target, speed: 80)
                if agent.position.distance(to: target) < 50 {
                    agent.needs.workDrive = max(0, agent.needs.workDrive - 0.02)
                    agent.needs.rest += 0.005
                    agent.needs.clamp()
                }
            }

        case .build:
            let detail = agent.currentGoal.detail ?? "מבנה"
            let msg = "\(agent.name) רוצה לבנות \(detail) בכפר"
            requests.append(SimRequest(id: UUID(), from: agent.id, message: msg, type: "buildPermission", timestamp: Date(), status: "pending"))
            speak(agent, text: "רוצה לבנות \(detail)... 🔨", duration: 3)
            events.append(SimEvent(type: "build_request", agentID: agent.id, message: msg, timestamp: Date()))
            agent.currentGoal = SimGoal(type: .idle)

        case .rest:
            if let target = agent.currentGoal.target {
                moveToward(agent, target: target, speed: 40)
                if agent.position.distance(to: target) < 30 {
                    agent.needs.rest = max(0, agent.needs.rest - 0.03)
                    if Double.random(in: 0...1) < 0.03 {
                        speak(agent, text: "💤", duration: 2)
                    }
                }
            }

        case .explore:
            if let target = agent.currentGoal.target {
                moveToward(agent, target: target, speed: 60)
                if agent.position.distance(to: target) < 15 {
                    let chatter = ["מה קורה פה?", "הכל שקט...", "☕ הפסקת צ׳אי", "נוף יפה! 🏡", "הכפר גדל! 🌱"]
                    if Double.random(in: 0...1) < 0.5 {
                        speak(agent, text: chatter.randomElement()!, duration: 3)
                    }
                    agent.currentGoal = SimGoal(type: .idle)
                }
            }

        case .request:
            if let msg = agent.currentGoal.detail {
                let type = msg.contains("רעב") || msg.contains("אוכל") ? "food" : "general"
                requests.append(SimRequest(id: UUID(), from: agent.id, message: msg, type: type, timestamp: Date(), status: "pending"))
                speak(agent, text: msg, duration: 4)
                events.append(SimEvent(type: "request", agentID: agent.id, message: msg, timestamp: Date()))
            }
            agent.currentGoal = SimGoal(type: .idle)

        case .idle:
            break
        }
    }

    private func moveToward(_ agent: SimAgent, target: Vec2, speed: Double) {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist > 1 else { return }
        let step = min(speed * 2.0 / 60.0, dist)  // 2 sec ticks
        agent.position.x += dx / dist * step
        agent.position.y += dy / dist * step
    }

    private func speak(_ agent: SimAgent, text: String, duration: TimeInterval) {
        agent.currentSpeech = text
        agent.speechExpiry = Date().addingTimeInterval(duration)
    }

    private func checkConversations() {
        let agentList = Array(agents.values)
        for i in 0..<agentList.count {
            for j in (i + 1)..<agentList.count {
                let a = agentList[i], b = agentList[j]
                guard a.currentGoal.type == .idle, b.currentGoal.type == .idle else { continue }
                if a.position.distance(to: b.position) < 80 && a.needs.social > 0.3 && b.needs.social > 0.3 {
                    if Double.random(in: 0...1) < 0.08 {
                        a.currentGoal = SimGoal(type: .socialize, targetAgent: b.id)
                    }
                }
            }
        }
    }

    // MARK: - External Actions

    /// Drop food at a position (Alon feeding from web)
    public func dropFood(at position: Vec2) {
        guard foods.count < 8 else { return }
        let food = SimulationLoop.turkishFoods.randomElement()!
        foods.append(SimFood(id: UUID(), position: position, emoji: food.emoji, name: food.name, isBeingEaten: false, dropTime: Date()))
    }

    /// Approve a request
    public func approveRequest(_ requestID: UUID) {
        guard let idx = requests.firstIndex(where: { $0.id == requestID && $0.status == "pending" }) else { return }
        requests[idx].status = "approved"
        let request = requests[idx]

        if request.type == "food" {
            // Drop food near the agent
            if let agent = agents[request.from] {
                dropFood(at: Vec2(x: agent.position.x + Double.random(in: -30...30), y: agent.position.y + 30))
            }
        } else if request.type == "buildPermission" {
            // Place structure
            if let agent = agents[request.from] {
                let type = SimulationLoop.buildPreferences[request.from]?.randomElement() ?? "מבנה"
                structures.append(SimStructure(id: UUID(), type: type, position: Vec2(
                    x: agent.position.x + Double.random(in: -50...50),
                    y: agent.position.y + Double.random(in: -30...30)
                ), builder: request.from, buildDate: Date()))
                agent.needs.creativity = max(0, agent.needs.creativity - 0.5)
                speak(agent, text: "!בניתי \(type)! 🔨", duration: 3)
                events.append(SimEvent(type: "build_complete", agentID: agent.id, message: "\(agent.name) בנה \(type)", timestamp: Date()))
            }
        }

        if let agent = agents[request.from] {
            speak(agent, text: "!תודה אלון! 🎉", duration: 3)
        }
    }

    /// Deny a request
    public func denyRequest(_ requestID: UUID) {
        guard let idx = requests.firstIndex(where: { $0.id == requestID && $0.status == "pending" }) else { return }
        requests[idx].status = "denied"
        let request = requests[idx]
        if let agent = agents[request.from] {
            let sad = ["😢 חבל...", "בסדר... 😔", "אולי בפעם הבאה 🙏"]
            speak(agent, text: sad.randomElement()!, duration: 3)
        }
    }

    // MARK: - Snapshot Generation

    private func generateSnapshot() -> SimulationSnapshot {
        let hour = Calendar.current.component(.hour, from: Date())
        let period: String
        switch hour {
        case 6..<8: period = "morning"
        case 8..<17: period = "day"
        case 17..<20: period = "evening"
        default: period = "night"
        }

        let badgeColors: [SimAgentID: String] = [.eyal: "#3366EE", .yael: "#E55AA0", .ido: "#33BB44", .roni: "#FF8811"]
        let moodEmojis: [SimAgentMood: String] = [.happy: "😊", .content: "🙂", .bored: "😐", .hungry: "🤤", .social: "🗣️", .creative: "🎨", .tired: "😴", .excited: "🤩"]

        let agentSnapshots = agents.values.map { agent in
            SimulationSnapshot.AgentSnapshot(
                id: agent.id.rawValue,
                name: agent.name,
                role: agent.role,
                position: agent.position,
                state: agent.currentGoal.type.rawValue,
                mood: agent.mood.rawValue,
                moodEmoji: moodEmojis[agent.mood] ?? "🙂",
                currentGoal: agent.currentGoal.detail ?? agent.currentGoal.type.rawValue,
                currentSpeech: agent.currentSpeech,
                facingLeft: false,
                badgeColor: badgeColors[agent.id] ?? "#888",
                needs: [
                    "hunger": agent.needs.hunger,
                    "social": agent.needs.social,
                    "creativity": agent.needs.creativity,
                    "workDrive": agent.needs.workDrive,
                    "rest": agent.needs.rest,
                ]
            )
        }

        let structureSnapshots = structures.map { s in
            SimulationSnapshot.StructureSnapshot(
                id: s.id.uuidString,
                type: s.type,
                position: s.position,
                builder: s.builder.rawValue,
                buildDate: s.buildDate.timeIntervalSince1970
            )
        }

        let foodSnapshots = foods.map { f in
            SimulationSnapshot.FoodSnapshot(position: f.position, emoji: f.emoji, name: f.name, isBeingEaten: f.isBeingEaten)
        }

        let houseSnapshots = houses.map { h in
            SimulationSnapshot.HouseSnapshot(
                id: h.id.rawValue, name: h.name, emoji: h.emoji,
                position: h.position, roofColor: h.roofColor, wallColor: h.wallColor,
                isActive: h.isActive, fileCount: h.fileCount, activeTasks: h.activeTasks
            )
        }

        let pendingReqs = requests.filter { $0.status == "pending" }.map { r in
            let name = agents[r.from]?.name ?? r.from.rawValue
            return SimulationSnapshot.RequestSnapshot(
                id: r.id.uuidString, from: r.from.rawValue, fromName: name,
                message: r.message, type: r.type, timestamp: r.timestamp.timeIntervalSince1970
            )
        }

        let recentEvts = events.suffix(10).map { e in
            SimulationSnapshot.EventSnapshot(
                type: e.type, agentID: e.agentID.rawValue,
                message: e.message, timestamp: e.timestamp.timeIntervalSince1970
            )
        }

        return SimulationSnapshot(
            tick: tick, timestamp: Date().timeIntervalSince1970,
            dayPeriod: period, agents: agentSnapshots,
            structures: structureSnapshots, foods: foodSnapshots,
            houses: houseSnapshots, recentEvents: recentEvts,
            pendingRequests: pendingReqs
        )
    }

    // MARK: - State Save/Load

    public struct SavedState: Codable {
        var agents: [SimAgent]
        var structures: [SimStructure]
        var tick: UInt64
    }

    public func saveState() -> Data? {
        let saved = SavedState(agents: Array(agents.values), structures: structures, tick: tick)
        return try? JSONEncoder().encode(saved)
    }

    public func loadState(from data: Data) {
        guard let saved = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        for agent in saved.agents {
            agents[agent.id] = agent
        }
        structures = saved.structures
        tick = saved.tick
    }
}
