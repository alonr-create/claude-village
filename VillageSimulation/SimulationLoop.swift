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
    // v2.0: velocity for client-side prediction
    public var velocity: Vec2 = Vec2(x: 0, y: 0)
    public var currentSpeed: Double = 0

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
    public let icon: String  // v3.0: icon name
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
    public let icon: String  // v3.0: icon name
    public let position: Vec2
    public let roofColor: String
    public let wallColor: String
    public var isActive: Bool
    public var fileCount: Int
    public var activeTasks: Int
}

// MARK: - Multi-line Conversation System

public struct SimConversation: Codable, Sendable {
    public let agentA: SimAgentID
    public let agentB: SimAgentID
    public let lines: [(speaker: SimAgentID, text: String)]
    public var currentLine: Int = 0
    public var lineTimer: Double = 0  // seconds until next line

    enum CodingKeys: String, CodingKey {
        case agentA, agentB, linesSpeakers, linesTexts, currentLine, lineTimer
    }

    public init(agentA: SimAgentID, agentB: SimAgentID, lines: [(SimAgentID, String)]) {
        self.agentA = agentA
        self.agentB = agentB
        self.lines = lines
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        agentA = try c.decode(SimAgentID.self, forKey: .agentA)
        agentB = try c.decode(SimAgentID.self, forKey: .agentB)
        let speakers = try c.decode([SimAgentID].self, forKey: .linesSpeakers)
        let texts = try c.decode([String].self, forKey: .linesTexts)
        lines = zip(speakers, texts).map { ($0, $1) }
        currentLine = try c.decode(Int.self, forKey: .currentLine)
        lineTimer = try c.decode(Double.self, forKey: .lineTimer)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(agentA, forKey: .agentA)
        try c.encode(agentB, forKey: .agentB)
        try c.encode(lines.map { $0.0 }, forKey: .linesSpeakers)
        try c.encode(lines.map { $0.1 }, forKey: .linesTexts)
        try c.encode(currentLine, forKey: .currentLine)
        try c.encode(lineTimer, forKey: .lineTimer)
    }

    public var isFinished: Bool { currentLine >= lines.count }
}

/// The core headless simulation — no rendering, pure logic
public class SimulationLoop: @unchecked Sendable {
    public var agents: [SimAgentID: SimAgent] = [:]
    public var structures: [SimStructure] = []
    public var foods: [SimFood] = []
    public var requests: [SimRequest] = []
    public var events: [SimEvent] = []
    public var houses: [SimHouse] = []
    public var activeConversations: [SimConversation] = []
    public var tick: UInt64 = 0
    private var lastTickTime = Date()
    private var lastAlonCallout: Date = Date.distantPast

    // v3.0: Presence tracking & auto-management
    public var lastPresencePing: Date = Date()
    public var isAlonPresent: Bool { Date().timeIntervalSince(lastPresencePing) < 30 }
    private var autoManagedCount: Int = 0
    private var eventsWhileAway: [String] = []  // summary for when Alon returns
    private var tickAtLastConnect: UInt64 = 0

    // Turkish foods
    static let turkishFoods: [(emoji: String, icon: String, name: String)] = [
        ("🥙", "doner", "דונר"), ("🍖", "iskender", "איסקנדר"), ("🥟", "manti", "מנטי"), ("🫓", "lahmacun", "לחמג׳ון"),
        ("🍢", "shish-kebab", "שיש קבב"), ("🧆", "kofta", "כופתה"), ("🫕", "pide", "פידה"), ("🍚", "pilaf", "פילאף"),
        ("🍬", "baklava", "באקלווה"), ("🫖", "chai", "צ׳אי"), ("☕", "turkish-coffee", "קפה טורקי"),
    ]

    // Conversation openers (single-line, used as fallback)
    public static let conversationOpeners: [SimAgentID: [String]] = [
        .eyal: ["היי! יש לי תוכנית חדשה 📋", "בואו נסדר את הפרויקטים", "מה המצב עם הדדליינים?"],
        .yael: ["ראיתי עיצוב מדהים! 🎨", "צריך לשפר את ה-UI", "יש לי רעיון לאנימציה חדשה ✨"],
        .ido: ["בדקתי את הביצועים 🔧", "יש בעיית אבטחה", "כתבתי API חדש"],
        .roni: ["מצאתי באג! 🐛", "הטסטים נכשלו שוב...", "בדקתי את הפיצ׳ר החדש — יש בעיות"],
    ]

    // Multi-line conversation templates
    public static let conversationTemplates: [((SimAgentID, SimAgentID), [(SimAgentID, String)])] = [
        ((.eyal, .yael), [
            (.eyal, "יעל, מה דעתך על העיצוב החדש? 🎨"),
            (.yael, "אני חושבת שצריך יותר צבע"),
            (.eyal, "מסכים. בואי נוסיף גרדיאנט"),
            (.yael, "יופי! אני מתחילה על זה עכשיו ✨"),
        ]),
        ((.eyal, .ido), [
            (.eyal, "עידו, מה המצב עם ה-API?"),
            (.ido, "כמעט סיימתי. יש בעיית ביצועים קטנה 🔧"),
            (.eyal, "כמה זמן לתקן?"),
            (.ido, "תן לי עוד כמה דקות, אני על זה"),
            (.eyal, "מצוין, סומך עליך 👍"),
        ]),
        ((.eyal, .roni), [
            (.eyal, "רוני, מה יצא מהבדיקות?"),
            (.roni, "מצאתי 3 באגים 🐛"),
            (.eyal, "רציני? תדרכי את עידו"),
            (.roni, "כבר שלחתי לו, הוא על זה"),
        ]),
        ((.yael, .ido), [
            (.yael, "עידו, הממשק צריך שיפור"),
            (.ido, "מה צריך לשנות?"),
            (.yael, "הכפתורים קטנים מדי, והצבעים דהויים 🎨"),
            (.ido, "אני אתקן את ה-CSS"),
            (.yael, "תודה! גם תוסיף אנימציה ✨"),
        ]),
        ((.yael, .roni), [
            (.yael, "רוני, בואי נבדוק את העיצוב החדש ביחד"),
            (.roni, "יאללה! אני פותחת את האפליקציה 📱"),
            (.yael, "מה דעתך?"),
            (.roni, "יפה! אבל יש באג בצד ימין 🐛"),
            (.yael, "אופס, אני מתקנת"),
            (.roni, "עכשיו מושלם! 🎉"),
        ]),
        ((.ido, .roni), [
            (.ido, "רוני, מצאתי באג ב-API"),
            (.roni, "שוב? תראה לי 🔍"),
            (.ido, "ה-response חוזר null"),
            (.roni, "אה, אני יודעת למה. תן לי דקה 🛠️"),
            (.ido, "את הכי טובה! 😎"),
        ]),
        ((.roni, .eyal), [
            (.roni, "אייל, יש לי עדכון על הבדיקות"),
            (.eyal, "ספרי"),
            (.roni, "הכל עובד חוץ מהתשלומים 💳"),
            (.eyal, "עידו, שמעת? תטפל בזה"),
        ]),
        ((.yael, .eyal), [
            (.yael, "אייל, עיצבתי לוגו חדש! 🎨"),
            (.eyal, "וואו, תראי"),
            (.yael, "הנה, מה אתה חושב?"),
            (.eyal, "מדהים! נעלה את זה מחר ✨"),
        ]),
        ((.ido, .eyal), [
            (.ido, "אייל, סיימתי את ה-backend!"),
            (.eyal, "יופי! כל הטסטים עוברים?"),
            (.ido, "95% עוברים, יש 2 שצריכים תיקון קטן"),
            (.eyal, "תסיים את זה ונעלה לפרודקשן 🚀"),
        ]),
        ((.roni, .ido), [
            (.roni, "עידו, הגרסה החדשה קורסת בנייד 📱"),
            (.ido, "מה?! איפה בדיוק?"),
            (.roni, "בדף ההרשמה, כשלוחצים שלח"),
            (.ido, "מצאתי — בעיית זיכרון. מתקן עכשיו 🔧"),
            (.roni, "תודה, אני בודקת שוב אחרי"),
        ]),
    ]

    // Callouts to Alon
    public static let alonCallouts: [SimAgentID: [String]] = [
        .eyal: ["אלון, הכפר גדל! 🏡", "אלון, יש לנו פרויקט חדש!", "אלון, מה אתה חושב?"],
        .yael: ["אלון, זרוק לנו אוכל! 🥙", "אלון, תראה מה עיצבתי! ✨", "אלון, הכפר יפה היום 🌅"],
        .ido: ["אלון, ה-server רץ מעולה 🖥️", "אלון, צריך עוד קפה! ☕", "אלון, מה לעבוד עליו?"],
        .roni: ["אלון, הכל עובד! ✅", "אלון, בוא תבדוק את הכפר 🔍", "אלון, יש לנו חדשות! 📢"],
    ]

    // Build types per personality
    static let buildPreferences: [SimAgentID: [String]] = [
        .eyal: ["שלט", "ספסל", "לוח מודעות"],
        .yael: ["גן פרחים", "פנס", "גדר דקורטיבית"],
        .ido: ["גשר", "באר", "דרך"],
        .roni: ["ספסל תצפית", "גדר", "עמדת בדיקה"],
    ]

    // Need decay rates per agent (per minute)
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
            SimHouse(id: .matzpen, name: "מצפן לעושר", emoji: "🧭", icon: "compass", position: Vec2(x: -400, y: 200), roofColor: "#D4AF37", wallColor: "#1C0B2E", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .dekel, name: "דקל לפרישה", emoji: "🌴", icon: "palm-tree", position: Vec2(x: -400, y: -200), roofColor: "#1A6FC4", wallColor: "#0D2248", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .alonDev, name: "Alon.dev", emoji: "💻", icon: "computer", position: Vec2(x: 400, y: 200), roofColor: "#8B5CF6", wallColor: "#0A0E1A", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .aliza, name: "עליזה המפרסמת", emoji: "📣", icon: "megaphone", position: Vec2(x: 400, y: -200), roofColor: "#DD3333", wallColor: "#4A0E0E", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .boker, name: "הודעת בוקר", emoji: "🌅", icon: "sunrise", position: Vec2(x: 0, y: 400), roofColor: "#10B981", wallColor: "#1F2937", isActive: false, fileCount: 0, activeTasks: 0),
            SimHouse(id: .games, name: "אפליקציות ומשחקים", emoji: "🎮", icon: "gamepad", position: Vec2(x: 0, y: -400), roofColor: "#F59E0B", wallColor: "#1F2937", isActive: false, fileCount: 0, activeTasks: 0),
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

    // MARK: - Main Tick (call every 500ms)

    public func doTick() -> SimulationSnapshot {
        let now = Date()
        let deltaSeconds = now.timeIntervalSince(lastTickTime)
        let deltaMinutes = deltaSeconds / 60.0
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

        // 3. Expire food (45 second timeout)
        foods.removeAll { now.timeIntervalSince($0.dropTime) > 45 && !$0.isBeingEaten }

        // 4. Advance active conversations
        advanceConversations(deltaSeconds: deltaSeconds)

        // 5. Decide & act for each agent
        for (_, agent) in agents {
            // Skip agents in active conversation
            if isInConversation(agent.id) { continue }

            if agent.currentGoal.type == .idle || shouldReEvaluate(agent) {
                decideGoal(for: agent)
            }
            executeGoal(for: agent, deltaSeconds: deltaSeconds)
        }

        // 6. Check for spontaneous conversations (15% chance, range 120)
        checkConversations()

        // 7. Callout to Alon every 30-60 seconds
        if now.timeIntervalSince(lastAlonCallout) > Double.random(in: 30...60) {
            calloutToAlon()
            lastAlonCallout = now
        }

        // 8. Update velocities for all agents
        updateVelocities()

        // 9. Auto-manage requests when Alon is away (Eyal manages)
        if !isAlonPresent {
            autoManageRequests()
        }

        // 10. Trim events
        if events.count > 50 { events = Array(events.suffix(50)) }

        return generateSnapshot()
    }

    // MARK: - Auto-Management (Eyal takes over)

    private func autoManageRequests() {
        let pending = requests.filter { $0.status == "pending" && Date().timeIntervalSince($0.timestamp) > 15 }
        guard !pending.isEmpty, let eyal = agents[.eyal] else { return }

        for req in pending {
            let reqName = agents[req.from]?.name ?? req.from.rawValue
            let shouldApprove: Bool
            switch req.type {
            case "food", "buildPermission":
                shouldApprove = true
            default:
                shouldApprove = Double.random(in: 0...1) < 0.7
            }

            if shouldApprove {
                approveRequest(req.id)
                speak(eyal, text: "אני מאשר — \(reqName), קדימה! 📋", duration: 4)
                eventsWhileAway.append("אייל אישר בקשה של \(reqName)")
            } else {
                denyRequest(req.id)
                speak(eyal, text: "לא הפעם, \(reqName)... 😅", duration: 3)
                eventsWhileAway.append("אייל דחה בקשה של \(reqName)")
            }
            autoManagedCount += 1
        }
    }

    // MARK: - Presence & Return Summary

    public func pingPresence() {
        lastPresencePing = Date()
    }

    public func generateReturnSummary(lastTick: UInt64) -> String? {
        let ticksDiff = tick > lastTick ? tick - lastTick : 0
        guard ticksDiff > 10 else { return nil }  // only if away for meaningful time

        let minutesAway = Int(Double(ticksDiff) * 0.5 / 60)  // 500ms per tick
        var parts: [String] = []
        parts.append("היית בחוץ \(max(1, minutesAway)) דקות")

        // Count conversations, structures, managed requests
        let recentConvs = events.filter { $0.type == "conversation" }.count
        let recentBuilds = events.filter { $0.type == "build" }.count
        if recentConvs > 0 { parts.append("היו \(recentConvs) שיחות") }
        if recentBuilds > 0 { parts.append("נבנו \(recentBuilds) מבנים") }
        if autoManagedCount > 0 { parts.append("אייל ניהל \(autoManagedCount) בקשות") }

        // Reset counters
        autoManagedCount = 0
        eventsWhileAway = []
        tickAtLastConnect = tick

        return parts.joined(separator: ", ")
    }

    /// Make an agent speak (public for server use)
    public func speak(_ agent: SimAgent, text: String, duration: Double) {
        agent.currentSpeech = text
        agent.speechExpiry = Date().addingTimeInterval(duration)
    }

    // MARK: - Conversation System

    private func isInConversation(_ agentID: SimAgentID) -> Bool {
        activeConversations.contains { ($0.agentA == agentID || $0.agentB == agentID) && !$0.isFinished }
    }

    private func advanceConversations(deltaSeconds: Double) {
        for i in (0..<activeConversations.count).reversed() {
            activeConversations[i].lineTimer -= deltaSeconds
            if activeConversations[i].lineTimer <= 0 {
                // Show next line
                if activeConversations[i].currentLine < activeConversations[i].lines.count {
                    let line = activeConversations[i].lines[activeConversations[i].currentLine]
                    if let agent = agents[line.0] {
                        speak(agent, text: line.1, duration: 3.0)
                    }
                    activeConversations[i].currentLine += 1
                    activeConversations[i].lineTimer = 3.0  // 3 seconds per line
                }
            }
            // Remove finished conversations
            if activeConversations[i].isFinished {
                let conv = activeConversations[i]
                // Reduce social needs for both participants
                agents[conv.agentA]?.needs.social = max(0, (agents[conv.agentA]?.needs.social ?? 0) - 0.5)
                agents[conv.agentB]?.needs.social = max(0, (agents[conv.agentB]?.needs.social ?? 0) - 0.4)
                agents[conv.agentA]?.currentGoal = SimGoal(type: .idle)
                agents[conv.agentB]?.currentGoal = SimGoal(type: .idle)
                events.append(SimEvent(type: "conversation", agentID: conv.agentA,
                    message: "\(agents[conv.agentA]?.name ?? "") ו\(agents[conv.agentB]?.name ?? "") דיברו", timestamp: Date()))
                activeConversations.remove(at: i)
            }
        }
    }

    private func startConversation(between a: SimAgent, and b: SimAgent) {
        // Find a matching template
        let pair1 = (a.id, b.id)
        let pair2 = (b.id, a.id)

        var template: [(SimAgentID, String)]?
        for (pair, lines) in SimulationLoop.conversationTemplates {
            if pair == pair1 || pair == pair2 {
                template = lines
                break
            }
        }

        let lines: [(SimAgentID, String)]
        if let t = template {
            lines = t
        } else {
            // Fallback: generate a simple 3-line conversation
            let openerA = SimulationLoop.conversationOpeners[a.id]?.randomElement() ?? "שלום!"
            let openerB = SimulationLoop.conversationOpeners[b.id]?.randomElement() ?? "היי!"
            lines = [
                (a.id, openerA),
                (b.id, openerB),
                (a.id, "בוא נדבר על זה אחר כך 👋"),
            ]
        }

        var conv = SimConversation(agentA: a.id, agentB: b.id, lines: lines)
        // Show first line immediately
        if let firstLine = lines.first, let speaker = agents[firstLine.0] {
            speak(speaker, text: firstLine.1, duration: 3.0)
            conv.currentLine = 1
            conv.lineTimer = 3.0
        }
        activeConversations.append(conv)

        // Set both agents to socialize mode (they'll face each other)
        a.currentGoal = SimGoal(type: .socialize, targetAgent: b.id)
        b.currentGoal = SimGoal(type: .socialize, targetAgent: a.id)
    }

    private func calloutToAlon() {
        let idleAgents = agents.values.filter { $0.currentGoal.type == .idle && $0.currentSpeech == nil }
        guard let agent = idleAgents.randomElement() else { return }
        let callouts = SimulationLoop.alonCallouts[agent.id] ?? ["אלון! 👋"]
        speak(agent, text: callouts.randomElement()!, duration: 4)
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
        case .work: return Double.random(in: 0...1) < 0.05  // lower chance per 500ms tick
        case .eat: return foods.filter({ !$0.isBeingEaten }).isEmpty
        case .socialize: return Double.random(in: 0...1) < 0.02
        case .build: return Double.random(in: 0...1) < 0.03
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

        // Fun request (2% chance per 500ms tick ≈ same as 5% per 2s tick)
        if Double.random(in: 0...1) < 0.02 {
            let funReqs = ["אלון, מגיע לי חופשה! 🏖️", "אלון, אפשר העלאה? 💰", "אלון, צריך ריהוט חדש לכפר! 🪑"]
            candidates.append((SimGoal(type: .request, detail: funReqs.randomElement()!), 0.3))
        }

        // Pick highest utility with randomness
        guard !candidates.isEmpty else { return }
        let sorted = candidates.sorted { $0.1 > $1.1 }
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

    // MARK: - Goal Execution

    private func executeGoal(for agent: SimAgent, deltaSeconds: Double) {
        switch agent.currentGoal.type {
        case .eat:
            if let food = foods.filter({ !$0.isBeingEaten }).min(by: {
                agent.position.distance(to: $0.position) < agent.position.distance(to: $1.position)
            }) {
                moveToward(agent, target: food.position, speed: 160, dt: deltaSeconds)
                if agent.position.distance(to: food.position) < 15 {
                    if let idx = foods.firstIndex(where: { $0.id == food.id }) {
                        foods[idx].isBeingEaten = true
                        agent.needs.hunger = max(0, agent.needs.hunger - 0.6)
                        let thanks = ["!וואו! דונר! 😍", "!באקלווה! חיים טובים 🍬", "!קבב! הכי טעים 🍖", "!תודה אלון! יאמי 😋"]
                        speak(agent, text: thanks.randomElement()!, duration: 3)
                        events.append(SimEvent(type: "eat", agentID: agent.id, message: "\(agent.name) אכל \(food.name)", timestamp: Date()))
                        foods.remove(at: idx)
                    }
                    agent.currentGoal = SimGoal(type: .idle)
                }
            } else {
                agent.currentGoal = SimGoal(type: .idle)
            }

        case .socialize:
            if let targetID = agent.currentGoal.targetAgent, let target = agents[targetID] {
                moveToward(agent, target: target.position, speed: 100, dt: deltaSeconds)
                if agent.position.distance(to: target.position) < 60 {
                    // If not already in a conversation, start one
                    if !isInConversation(agent.id) && !isInConversation(targetID) {
                        startConversation(between: agent, and: target)
                    }
                }
            } else {
                agent.currentGoal = SimGoal(type: .idle)
            }

        case .work:
            if let target = agent.currentGoal.target {
                moveToward(agent, target: target, speed: 100, dt: deltaSeconds)
                if agent.position.distance(to: target) < 50 {
                    agent.needs.workDrive = max(0, agent.needs.workDrive - 0.005 * deltaSeconds * 60)
                    agent.needs.rest += 0.001 * deltaSeconds * 60
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
                moveToward(agent, target: target, speed: 50, dt: deltaSeconds)
                if agent.position.distance(to: target) < 30 {
                    agent.needs.rest = max(0, agent.needs.rest - 0.008 * deltaSeconds * 60)
                    if Double.random(in: 0...1) < 0.008 {  // adjusted for 500ms ticks
                        speak(agent, text: "💤", duration: 2)
                    }
                }
            }

        case .explore:
            if let target = agent.currentGoal.target {
                moveToward(agent, target: target, speed: 80, dt: deltaSeconds)
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

    // MARK: - Movement

    private func moveToward(_ agent: SimAgent, target: Vec2, speed: Double, dt: Double) {
        let dx = target.x - agent.position.x
        let dy = target.y - agent.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist > 1 else {
            agent.velocity = Vec2(x: 0, y: 0)
            agent.currentSpeed = 0
            return
        }
        // speed = points per second, dt = seconds since last tick
        let step = min(speed * dt, dist)
        let nx = dx / dist
        let ny = dy / dist
        agent.position.x += nx * step
        agent.position.y += ny * step
        agent.velocity = Vec2(x: nx * speed, y: ny * speed)
        agent.currentSpeed = speed
    }

    private func updateVelocities() {
        // Clear velocity for agents not moving
        for (_, agent) in agents {
            if agent.currentGoal.type == .idle {
                agent.velocity = Vec2(x: 0, y: 0)
                agent.currentSpeed = 0
            }
        }
    }

    private func checkConversations() {
        let agentList = Array(agents.values)
        for i in 0..<agentList.count {
            for j in (i + 1)..<agentList.count {
                let a = agentList[i], b = agentList[j]
                guard a.currentGoal.type == .idle, b.currentGoal.type == .idle else { continue }
                guard !isInConversation(a.id), !isInConversation(b.id) else { continue }
                if a.position.distance(to: b.position) < 120 && a.needs.social > 0.25 && b.needs.social > 0.25 {
                    if Double.random(in: 0...1) < 0.04 {  // ~15% per 2 seconds at 500ms ticks
                        startConversation(between: a, and: b)
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
        foods.append(SimFood(id: UUID(), position: position, emoji: food.emoji, icon: food.icon, name: food.name, isBeingEaten: false, dropTime: Date()))

        // v2.0: Immediately alert nearby idle agents
        for (_, agent) in agents {
            if agent.currentGoal.type == .idle && agent.position.distance(to: position) < 300 {
                agent.currentGoal = SimGoal(type: .eat)
            }
        }
        // Nearest idle agent announces food
        if let nearest = agents.values
            .filter({ $0.currentGoal.type == .eat })
            .min(by: { $0.position.distance(to: position) < $1.position.distance(to: position) }) {
            speak(nearest, text: "!אוכל! בואו 🥙", duration: 2)
        }
    }

    /// Approve a request
    public func approveRequest(_ requestID: UUID) {
        guard let idx = requests.firstIndex(where: { $0.id == requestID && $0.status == "pending" }) else { return }
        requests[idx].status = "approved"
        let request = requests[idx]

        if request.type == "food" {
            if let agent = agents[request.from] {
                dropFood(at: Vec2(x: agent.position.x + Double.random(in: -30...30), y: agent.position.y + 30))
            }
        } else if request.type == "buildPermission" {
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

    public func generateSnapshot() -> SimulationSnapshot {
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
        let moodIcons: [SimAgentMood: String] = [.happy: "mood-happy", .content: "mood-content", .bored: "mood-bored", .hungry: "mood-hungry", .social: "mood-social", .creative: "mood-creative", .tired: "mood-tired", .excited: "mood-excited"]

        let agentSnapshots = agents.values.map { agent in
            // Compute TTS hash server-side (UTF-8 FNV-1a) so client doesn't need to recompute
            var speechHash: String? = nil
            if let speech = agent.currentSpeech {
                speechHash = Self.ttsHash(text: speech, agentName: agent.name)
            }

            return SimulationSnapshot.AgentSnapshot(
                id: agent.id.rawValue,
                name: agent.name,
                role: agent.role,
                position: agent.position,
                state: agent.currentGoal.type.rawValue,
                mood: agent.mood.rawValue,
                moodEmoji: moodEmojis[agent.mood] ?? "🙂",
                moodIcon: moodIcons[agent.mood] ?? "mood-content",
                currentGoal: agent.currentGoal.detail ?? agent.currentGoal.type.rawValue,
                currentSpeech: agent.currentSpeech,
                speechHash: speechHash,
                facingLeft: agent.velocity.x < 0,
                badgeColor: badgeColors[agent.id] ?? "#888",
                needs: [
                    "hunger": agent.needs.hunger,
                    "social": agent.needs.social,
                    "creativity": agent.needs.creativity,
                    "workDrive": agent.needs.workDrive,
                    "rest": agent.needs.rest,
                ],
                velocityX: agent.velocity.x,
                velocityY: agent.velocity.y,
                moveTarget: agent.currentGoal.target,
                moveSpeed: agent.currentSpeed
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
            SimulationSnapshot.FoodSnapshot(position: f.position, emoji: f.emoji, icon: f.icon, name: f.name, isBeingEaten: f.isBeingEaten)
        }

        let houseSnapshots = houses.map { h in
            SimulationSnapshot.HouseSnapshot(
                id: h.id.rawValue, name: h.name, emoji: h.emoji, icon: h.icon,
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

    // MARK: - TTS Hash (matches TTSCache.hashKey — FNV-1a over UTF-8)

    /// Compute FNV-1a hash of stripped text + agent name, matching TTSCache.hashKey exactly
    public static func ttsHash(text: String, agentName: String) -> String {
        // Strip emoji (same logic as TTSCache.stripEmoji)
        let cleanText = String(text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmoji && scalar.value > 0x23F)
        })
        let input = cleanText + "|" + agentName
        var hash: UInt32 = 2166136261
        for byte in input.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return String(hash, radix: 16)
    }
}
