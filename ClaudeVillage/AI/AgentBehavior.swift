import SpriteKit

/// Manages agent behavior in the village — decides when agents move, work, idle
@MainActor
class AgentBehaviorManager {
    private weak var scene: VillageScene?
    private let scheduler = AgentScheduler()
    private var updateTimer: Timer?
    private var wanderTimers: [AgentID: Timer] = [:]

    init(scene: VillageScene) {
        self.scene = scene
    }

    func start() {
        // Initial evaluation
        evaluate()

        // Re-evaluate every 15 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.evaluate()
        }

        // Start random wandering for idle agents
        for agent in AgentDefinition.all {
            scheduleWander(for: agent.id)
        }
    }

    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        for (_, timer) in wanderTimers {
            timer.invalidate()
        }
        wanderTimers.removeAll()
    }

    private func evaluate() {
        guard let scene = scene else { return }

        let result = scheduler.evaluate()

        // Update AppState
        Task { @MainActor in
            scene.appStateRef?.projectStatuses = result.projectStatuses
            scene.appStateRef?.activeTodos = result.activeTodos
            scene.appStateRef?.agentAssignments = result.agentAssignments
        }

        // Update house visuals
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

        // Move agents to assigned projects
        for (agentID, projectID) in result.agentAssignments {
            guard let crab = scene.crabNodes[agentID] else { continue }
            let targetPos = VillageLayout.position(for: projectID)
            let offsetTarget = CGPoint(
                x: targetPos.x + CGFloat.random(in: -30...30),
                y: targetPos.y - 60 + CGFloat.random(in: -10...10)
            )

            // Only move if not already near the target
            let distance = hypot(crab.position.x - offsetTarget.x, crab.position.y - offsetTarget.y)
            if distance > 50 {
                let duration = TimeInterval(distance / 80) // Speed: 80 pts/sec
                crab.walkTo(point: offsetTarget, duration: duration) {
                    crab.startWorkAnimation()
                    // Show speech bubble with current task
                    if let todos = result.activeTodos.values.flatMap({ $0 }).first(where: { $0.isInProgress }) {
                        crab.say(todos.activeForm, duration: 4.0)
                    }
                }
            }
        }
    }

    private func scheduleWander(for agentID: AgentID) {
        let delay = TimeInterval.random(in: 20...45)
        wanderTimers[agentID] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.wanderAgent(agentID)
            self?.scheduleWander(for: agentID) // Schedule next wander
        }
    }

    private func wanderAgent(_ agentID: AgentID) {
        guard let scene = scene,
              let crab = scene.crabNodes[agentID] else { return }

        // Only wander if agent is idle (not assigned)
        guard scene.appStateRef?.agentAssignments[agentID] == nil else { return }

        // Pick a random house to visit
        let randomHouse = VillageLayout.houses.randomElement()!
        let target = CGPoint(
            x: randomHouse.position.x + CGFloat.random(in: -40...40),
            y: randomHouse.position.y - 60 + CGFloat.random(in: -10...10)
        )

        let distance = hypot(crab.position.x - target.x, crab.position.y - target.y)
        let duration = TimeInterval(distance / 60)

        // Random speech
        let idleChatter = [
            "מה קורה פה?",
            "הכל שקט...",
            "☕ הפסקת קפה",
            "מחפש משימות",
            "בודק את הקוד",
            "יש מה לעשות?",
        ]

        crab.walkTo(point: target, duration: duration) {
            crab.startIdleAnimation()
            if Bool.random() { // 50% chance to say something
                crab.say(idleChatter.randomElement()!, duration: 3.0)
            }
        }
    }
}
