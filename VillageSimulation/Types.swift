import Foundation

/// Simple 2D vector — replaces CGPoint for cross-platform compatibility
public struct Vec2: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to other: Vec2) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Simple color (r,g,b,a) — replaces NSColor for cross-platform
public struct VillageColor: Codable, Sendable {
    public let r: Double, g: Double, b: Double, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Simulation Enums (pure Swift, no AppKit)

public enum SimAgentID: String, Codable, CaseIterable, Hashable, Sendable {
    case eyal, yael, ido, roni
}

public enum SimProjectID: String, Codable, CaseIterable, Hashable, Sendable {
    case matzpen, dekel, alonDev = "alon-dev", aliza, boker, games
}

public enum SimAgentMood: String, Codable, Sendable {
    case happy, content, bored, hungry, social, creative, tired, excited
}

public enum SimAgentGoalType: String, Codable, Sendable {
    case eat, socialize, work, build, rest, explore, request, idle
}
