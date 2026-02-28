import SpriteKit

/// Simple waypoint-based pathfinding through the village center
struct AgentPathfinding {
    /// Generate waypoints from one position to another through roads
    static func waypoints(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let distance = hypot(start.x - end.x, start.y - end.y)

        // If close enough, go directly
        if distance < 100 {
            return [end]
        }

        // Route through village center with some randomness
        let midPoint = CGPoint(
            x: CGFloat.random(in: -30...30),
            y: CGFloat.random(in: -30...30)
        )

        return [midPoint, end]
    }
}
