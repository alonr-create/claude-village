import AppKit

enum AgentID: String, CaseIterable, Hashable {
    case eyal = "eyal"
    case yael = "yael"
    case ido  = "ido"
    case roni = "roni"
}

enum AgentRole: String {
    case productManager = "מנהל מוצר"
    case frontendDesigner = "מעצבת + פרונט"
    case backendArchitect = "באק-אנד + ארכיטקט"
    case qaTester = "בודקת איכות"
}

struct AgentDefinition {
    let id: AgentID
    let nameHebrew: String
    let nameEnglish: String
    let role: AgentRole
    let badgeColor: NSColor
    let bodyColor: NSColor
    let personality: String
    let keywords: [String] // Keywords for task assignment

    static let all: [AgentDefinition] = [
        AgentDefinition(
            id: .eyal,
            nameHebrew: "אייל",
            nameEnglish: "Eyal",
            role: .productManager,
            badgeColor: NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1), // Blue
            bodyColor: NSColor(red: 0.85, green: 0.35, blue: 0.20, alpha: 1), // Crab orange-red
            personality: "אחראי, מסודר, רואה תמונה גדולה",
            keywords: ["readme", "plan", "manage", "todo", "package", "structure", "organize", "document"]
        ),
        AgentDefinition(
            id: .yael,
            nameHebrew: "יעל",
            nameEnglish: "Yael",
            role: .frontendDesigner,
            badgeColor: NSColor(red: 0.9, green: 0.35, blue: 0.6, alpha: 1), // Pink
            bodyColor: NSColor(red: 0.90, green: 0.40, blue: 0.25, alpha: 1), // Slightly lighter crab
            personality: "פרפקציוניסטית, ויזואלית, רגישה ל-UX",
            keywords: ["design", "css", "style", "layout", "component", "ui", "frontend", "color", "font", "animation", "responsive"]
        ),
        AgentDefinition(
            id: .ido,
            nameHebrew: "עידו",
            nameEnglish: "Ido",
            role: .backendArchitect,
            badgeColor: NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1), // Green
            bodyColor: NSColor(red: 0.80, green: 0.30, blue: 0.15, alpha: 1), // Darker crab
            personality: "פרגמטי, אובססיבי לאבטחה וביצועים",
            keywords: ["api", "server", "database", "backend", "deploy", "docker", "railway", "python", "script", "env", "security", "performance"]
        ),
        AgentDefinition(
            id: .roni,
            nameHebrew: "רוני",
            nameEnglish: "Roni",
            role: .qaTester,
            badgeColor: NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1), // Orange
            bodyColor: NSColor(red: 0.88, green: 0.38, blue: 0.22, alpha: 1), // Medium crab
            personality: "סקפטית, יסודית, אוהבת לשבור דברים",
            keywords: ["test", "qa", "bug", "fix", "verify", "check", "validate", "error", "debug"]
        ),
    ]

    static func find(_ id: AgentID) -> AgentDefinition {
        all.first(where: { $0.id == id })!
    }

    static func assignRole(for text: String) -> AgentID {
        let lower = text.lowercased()
        // Check each agent's keywords
        var bestMatch: (AgentID, Int) = (.eyal, 0)
        for agent in all {
            let matchCount = agent.keywords.filter { lower.contains($0) }.count
            if matchCount > bestMatch.1 {
                bestMatch = (agent.id, matchCount)
            }
        }
        return bestMatch.0
    }
}
