import SpriteKit

/// Manages agent behavior in the village — autonomous decision-making, communication, building
@MainActor
class AgentBehaviorManager {
    private weak var scene: VillageScene?
    private let scheduler = AgentScheduler()
    private let decisionEngine = DecisionEngine()
    let communicationSystem = CommunicationSystem()
    private var updateTimer: Timer?
    private var lastTickTime: Date = Date()

    // Agent states — the core of autonomous behavior
    private(set) var agentStates: [AgentID: AgentState] = [:]

    init(scene: VillageScene) {
        self.scene = scene
        initializeAgentStates()
    }

    private func initializeAgentStates() {
        for (i, agent) in AgentDefinition.all.enumerated() {
            let startHouse = VillageLayout.houses[i % VillageLayout.houses.count]
            let pos = CGPoint(
                x: startHouse.position.x + CGFloat.random(in: -40...40),
                y: startHouse.position.y - 70
            )
            agentStates[agent.id] = AgentState(agentID: agent.id, position: pos)
        }
    }

    func start() {
        lastTickTime = Date()
        evaluate()

        // Re-evaluate every 5 seconds (faster for autonomous behavior)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
    }

    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func evaluate() {
        guard let scene = scene else { return }

        let now = Date()
        let deltaMinutes = now.timeIntervalSince(lastTickTime) / 60.0
        lastTickTime = now

        // 1. Get external data (Claude todos + sessions)
        let result = scheduler.evaluate()

        // 2. Update AppState with project info
        Task { @MainActor in
            scene.appStateRef?.projectStatuses = result.projectStatuses
            scene.appStateRef?.activeTodos = result.activeTodos
            scene.appStateRef?.agentAssignments = result.agentAssignments
        }

        // 3. Update house visuals
        for (projectID, house) in scene.houseNodes {
            let isActive = result.activeProjects.contains(projectID)
            house.setActive(isActive)
            if isActive {
                house.startChimneySmoke()
                house.setStatus(color: .systemGreen)
            } else {
                house.stopChimneySmoke()
                let status = result.projectStatuses[projectID]
                let hoursSince = Date().timeIntervalSince(status?.lastModified ?? .distantPast) / 3600
                if hoursSince < 24 {
                    house.setStatus(color: .systemYellow)
                } else {
                    house.setStatus(color: .systemGray)
                }
            }
        }

        // 4. Decay agent needs
        for (_, state) in agentStates {
            state.decayNeeds(deltaMinutes: deltaMinutes)
        }

        // 5. Check for spontaneous conversations
        checkForConversations()

        // 6. Run decision engine for each agent
        let foodAvailable = scene.foodNodes.contains(where: { !$0.isBeingEaten })
        let structureCount = scene.structureNodes.count

        for (_, state) in agentStates {
            if shouldReEvaluate(state) {
                let newGoal = decisionEngine.decideBestGoal(
                    for: state,
                    otherAgents: Array(agentStates.values),
                    availableFood: foodAvailable,
                    activeProjects: result.activeProjects,
                    placedStructures: structureCount
                )
                state.currentGoal = newGoal
            }
            executeGoal(for: state)
        }

        // 7. Update AppState with agent states
        Task { @MainActor in
            scene.appStateRef?.agentStates = agentStates
        }
    }

    private func shouldReEvaluate(_ state: AgentState) -> Bool {
        guard let crab = scene?.crabNodes[state.agentID] else { return true }

        switch state.currentGoal {
        case .idle:
            return true
        case .explore:
            return crab.action(forKey: "walking") == nil
        case .work:
            return Double.random(in: 0...1) < 0.15  // ~15% chance per tick
        case .eat:
            return !(scene?.foodNodes.contains(where: { !$0.isBeingEaten }) ?? false)
        case .socialize:
            return crab.action(forKey: "walking") == nil
                && crab.childNode(withName: "//speechBubble") == nil
        case .build:
            return crab.action(forKey: "walking") == nil
                && crab.action(forKey: "building") == nil
        case .rest:
            return state.needs.rest < 0.2
        case .requestFromAlon:
            return true
        }
    }

    private func executeGoal(for state: AgentState) {
        guard let scene = scene,
              let crab = scene.crabNodes[state.agentID] else { return }

        switch state.currentGoal {
        case .eat:
            executeEat(state: state, crab: crab, scene: scene)
        case .socialize(let with):
            executeSocialize(state: state, with: with, crab: crab, scene: scene)
        case .work(let at):
            executeWork(state: state, at: at, crab: crab)
        case .build(let type):
            executeBuild(state: state, type: type, crab: crab, scene: scene)
        case .rest(let at):
            executeRest(state: state, at: at, crab: crab)
        case .explore:
            executeExplore(state: state, crab: crab)
        case .requestFromAlon(let message):
            executeRequest(state: state, message: message, crab: crab, scene: scene)
        case .idle:
            if crab.action(forKey: "walking") == nil {
                crab.startIdleAnimation()
            }
        }
    }

    // MARK: - Goal Execution

    private func executeEat(state: AgentState, crab: CrabAgentNode, scene: VillageScene) {
        if crab.action(forKey: "walkToFood") != nil { return }

        guard let food = scene.foodNodes.filter({ !$0.isBeingEaten }).min(by: {
            hypot($0.position.x - crab.position.x, $0.position.y - crab.position.y) <
            hypot($1.position.x - crab.position.x, $1.position.y - crab.position.y)
        }) else {
            state.currentGoal = .idle
            return
        }

        scene.sendNearestCrabToFood(food, specificCrab: crab)
    }

    private func executeSocialize(state: AgentState, with targetID: AgentID, crab: CrabAgentNode, scene: VillageScene) {
        guard let targetCrab = scene.crabNodes[targetID],
              let targetState = agentStates[targetID] else {
            state.currentGoal = .idle
            return
        }

        let distance = hypot(crab.position.x - targetCrab.position.x, crab.position.y - targetCrab.position.y)

        if distance > 60 && crab.action(forKey: "walking") == nil {
            let target = CGPoint(
                x: targetCrab.position.x + CGFloat.random(in: -20...20),
                y: targetCrab.position.y + CGFloat.random(in: -20...20)
            )
            let duration = TimeInterval(distance / 80)
            crab.walkTo(point: target, duration: duration) {}
            state.position = target
        } else if distance <= 60 && crab.action(forKey: "walking") == nil
                    && crab.childNode(withName: "//speechBubble") == nil {
            let messages = communicationSystem.generateConversation(between: state, and: targetState)
            showConversation(messages, scene: scene)
            state.satisfy(\.social, by: 0.4)
            targetState.satisfy(\.social, by: 0.4)
            state.currentGoal = .idle
            targetState.currentGoal = .idle
        }
    }

    private func executeWork(state: AgentState, at projectID: ProjectID, crab: CrabAgentNode) {
        let targetPos = VillageLayout.position(for: projectID)
        let offsetTarget = CGPoint(
            x: targetPos.x + CGFloat.random(in: -30...30),
            y: targetPos.y - 60 + CGFloat.random(in: -10...10)
        )

        let distance = hypot(crab.position.x - offsetTarget.x, crab.position.y - offsetTarget.y)
        if distance > 50 && crab.action(forKey: "walking") == nil {
            let duration = TimeInterval(distance / 80)
            crab.walkTo(point: offsetTarget, duration: duration) {
                crab.startWorkAnimation()
                state.position = offsetTarget
            }
        } else if crab.action(forKey: "walking") == nil {
            crab.startWorkAnimation()
            state.satisfy(\.workDrive, by: 0.02)
            state.needs.rest += 0.005
            state.needs.clamp()
        }
    }

    private func executeBuild(state: AgentState, type: String, crab: CrabAgentNode, scene: VillageScene) {
        if crab.action(forKey: "building") == nil && crab.action(forKey: "walking") == nil {
            let message = "\(AgentDefinition.find(state.agentID).nameHebrew) רוצה לבנות \(type) בכפר"
            Task { @MainActor in
                scene.appStateRef?.requestSystem.submitRequest(
                    from: state.agentID,
                    message: message,
                    type: .buildPermission
                )
            }
            crab.say("רוצה לבנות \(type)... 🔨", duration: 3.0)
            state.currentGoal = .idle
        }
    }

    private func executeRest(state: AgentState, at target: CGPoint, crab: CrabAgentNode) {
        let distance = hypot(crab.position.x - target.x, crab.position.y - target.y)
        if distance > 30 && crab.action(forKey: "walking") == nil {
            let duration = TimeInterval(distance / 60)
            crab.walkTo(point: target, duration: duration) {
                crab.startIdleAnimation()
                state.position = target
            }
        } else {
            state.satisfy(\.rest, by: 0.03)
            if Double.random(in: 0...1) < 0.05 {
                crab.say("💤", duration: 2.0)
            }
        }
    }

    private func executeExplore(state: AgentState, crab: CrabAgentNode) {
        if crab.action(forKey: "walking") == nil {
            let randomHouse = VillageLayout.houses.randomElement()!
            let target = CGPoint(
                x: randomHouse.position.x + CGFloat.random(in: -60...60),
                y: randomHouse.position.y - 60 + CGFloat.random(in: -30...30)
            )
            let distance = hypot(crab.position.x - target.x, crab.position.y - target.y)
            let duration = TimeInterval(distance / 60)

            crab.walkTo(point: target, duration: duration) {
                crab.startIdleAnimation()
                state.position = target
                if Bool.random() {
                    let chatter = [
                        "מה קורה פה?", "הכל שקט...", "☕ הפסקת צ׳אי",
                        "מחפש משימות", "בודק את הכפר", "יש מה לעשות?",
                        "נוף יפה! 🏡", "הכפר גדל! 🌱",
                    ]
                    crab.say(chatter.randomElement()!, duration: 3.0)
                }
            }
        }
    }

    private func executeRequest(state: AgentState, message: String, crab: CrabAgentNode, scene: VillageScene) {
        let type = RequestSystem.categorize(message)
        Task { @MainActor in
            scene.appStateRef?.requestSystem.submitRequest(from: state.agentID, message: message, type: type)
        }
        crab.say(message, duration: 4.0)
        state.currentGoal = .idle
    }

    // MARK: - Conversations

    private func checkForConversations() {
        let agents = Array(agentStates.values)
        for i in 0..<agents.count {
            for j in (i + 1)..<agents.count {
                let a = agents[i], b = agents[j]
                guard case .idle = a.currentGoal, case .idle = b.currentGoal else { continue }

                let dist = hypot(a.position.x - b.position.x, a.position.y - b.position.y)
                if dist < 80 && a.needs.social > 0.3 && b.needs.social > 0.3 {
                    if Double.random(in: 0...1) < 0.1 {
                        a.currentGoal = .socialize(with: b.agentID)
                    }
                }
            }
        }
    }

    private func showConversation(_ messages: [AgentMessage], scene: VillageScene) {
        var delay: TimeInterval = 0
        for message in messages {
            guard let crab = scene.crabNodes[message.from] else { continue }
            let msg = message.content
            scene.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { crab.say(msg, duration: 3.0) }
            ]))
            delay += 3.5
        }
    }

    /// Called when Alon approves a food request
    func handleFoodApproval(for agentID: AgentID) {
        guard let state = agentStates[agentID] else { return }
        state.satisfy(\.hunger, by: 0.3)
    }

    /// Called when a build request is approved
    func handleBuildApproval(for agentID: AgentID, structureType: String) {
        guard let state = agentStates[agentID] else { return }
        state.currentGoal = .build(type: structureType)
        state.satisfy(\.creativity, by: 0.5)
    }
}
