import Foundation

/// Utility-based AI decision engine — picks the best goal for each agent
class DecisionEngine {
    /// Evaluate all possible goals and pick the one with highest utility
    func decideBestGoal(
        for state: AgentState,
        otherAgents: [AgentState],
        availableFood: Bool,
        activeProjects: Set<ProjectID>,
        placedStructures: Int
    ) -> AgentGoal {
        var candidates: [(goal: AgentGoal, utility: Double)] = []
        let agent = AgentDefinition.find(state.agentID)

        // --- Eating ---
        if availableFood {
            candidates.append((.eat, state.needs.hunger * 0.95))
        } else if state.needs.hunger > 0.7 {
            // No food available but very hungry — request from Alon
            let foods = ["דונר 🥙", "לחמג׳ון 🫓", "באקלווה 🍬", "קבב 🍢", "מנטי 🥟"]
            let request = "אלון, אני רעב! אפשר \(foods.randomElement()!)?"
            candidates.append((.requestFromAlon(message: request), state.needs.hunger * 0.7))
        }

        // --- Socializing ---
        for other in otherAgents where other.agentID != state.agentID {
            let distance = hypot(state.position.x - other.position.x, state.position.y - other.position.y)
            let proximityBonus = max(0, 1.0 - distance / 500.0) * 0.2

            // Don't socialize with someone already socializing
            if case .socialize = other.currentGoal { continue }

            let utility = state.needs.social * 0.8 + proximityBonus
            candidates.append((.socialize(with: other.agentID), utility))
        }

        // --- Building ---
        if state.needs.creativity > 0.4 {
            let buildType = chooseBuildType(for: state, structuresCount: placedStructures)
            let utility = state.needs.creativity * 0.85
            candidates.append((.build(type: buildType), utility))
        }

        // --- Working ---
        if !activeProjects.isEmpty {
            let project = activeProjects.randomElement()!
            let utility = state.needs.workDrive * 0.8
            candidates.append((.work(at: project), utility))
        } else {
            // No active projects — pick a random one to "maintain"
            let project = ProjectID.allCases.randomElement()!
            let utility = state.needs.workDrive * 0.5
            candidates.append((.work(at: project), utility))
        }

        // --- Resting ---
        if state.needs.rest > 0.5 {
            let restSpot = CGPoint(
                x: CGFloat.random(in: -200...200),
                y: CGFloat.random(in: -200...200)
            )
            candidates.append((.rest(at: restSpot), state.needs.rest * 0.75))
        }

        // --- Exploring ---
        candidates.append((.explore, max(0.1, 1.0 - state.needs.rest) * 0.3))

        // --- Fun requests ---
        if Double.random(in: 0...1) < 0.05 {
            let funRequests = [
                "אלון, מגיע לי חופשה! 🏖️",
                "אלון, אפשר העלאה? 💰",
                "אלון, אפשר עוד כלים? 🔧",
                "אלון, צריך ריהוט חדש לכפר! 🪑",
                "אלון, אפשר לשתול עצים? 🌳",
            ]
            candidates.append((.requestFromAlon(message: funRequests.randomElement()!), 0.3))
        }

        // Pick highest utility with temperature-based randomness
        return weightedChoice(candidates, temperature: 0.15)
    }

    /// Choose a build type based on agent personality and village needs
    private func chooseBuildType(for state: AgentState, structuresCount: Int) -> String {
        let agent = AgentDefinition.find(state.agentID)

        let options: [(type: String, weight: Double)]
        switch state.agentID {
        case .eyal:
            // Product manager: signs, benches for meetings
            options = [("שלט", 0.3), ("ספסל", 0.3), ("לוח מודעות", 0.2), ("גדר", 0.1), ("פנס", 0.1)]
        case .yael:
            // Designer: gardens, decorative fences, lamps
            options = [("גן פרחים", 0.3), ("פנס", 0.25), ("גדר דקורטיבית", 0.2), ("ספסל", 0.15), ("ארון תצוגה", 0.1)]
        case .ido:
            // Backend: bridges, wells, roads (infrastructure)
            options = [("גשר", 0.3), ("באר", 0.25), ("דרך", 0.2), ("גדר", 0.15), ("שלט", 0.1)]
        case .roni:
            // QA: observation benches, fences (testing areas)
            options = [("ספסל תצפית", 0.3), ("גדר", 0.25), ("שלט", 0.2), ("פנס", 0.15), ("עמדת בדיקה", 0.1)]
        }

        // Weighted random selection
        let total = options.reduce(0.0) { $0 + $1.weight }
        var r = Double.random(in: 0..<total)
        for option in options {
            r -= option.weight
            if r <= 0 { return option.type }
        }
        return options.first!.type
    }

    /// Weighted random choice with temperature
    private func weightedChoice(_ candidates: [(goal: AgentGoal, utility: Double)], temperature: Double) -> AgentGoal {
        guard !candidates.isEmpty else { return .idle }

        // Apply temperature (higher = more random)
        let adjusted = candidates.map { (goal: $0.goal, utility: pow($0.utility + 0.01, 1.0 / max(0.01, temperature))) }
        let total = adjusted.reduce(0.0) { $0 + $1.utility }

        guard total > 0 else { return candidates.randomElement()!.goal }

        var r = Double.random(in: 0..<total)
        for item in adjusted {
            r -= item.utility
            if r <= 0 { return item.goal }
        }
        return adjusted.last!.goal
    }
}
