import AppKit

enum ProjectID: String, CaseIterable, Hashable {
    case matzpenLeosher     = "matzpen"
    case dekelLeprisha      = "dekel"
    case alonDev            = "alon-dev"
    case alizaHamefarsement = "aliza"
    case hodaatBoker        = "boker"
    case appGames           = "games"
}

struct ProjectDefinition {
    let id: ProjectID
    let nameHebrew: String
    let nameEnglish: String
    let folderName: String
    let roofColor: NSColor
    let wallColor: NSColor
    let accentColor: NSColor
    let techStack: String
    let liveURL: String?
    let emoji: String

    var folderPath: String {
        let base = NSHomeDirectory() + "/קלוד עבודות/"
        return base + folderName
    }

    static let all: [ProjectDefinition] = [
        ProjectDefinition(
            id: .matzpenLeosher,
            nameHebrew: "מצפן לעושר",
            nameEnglish: "Wealthy Mindset",
            folderName: "מצפן-לעושר",
            roofColor: NSColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1), // #D4AF37
            wallColor: NSColor(red: 0.11, green: 0.04, blue: 0.18, alpha: 1), // #1C0B2E
            accentColor: NSColor(red: 0.94, green: 0.75, blue: 0.25, alpha: 1), // #F0C040
            techStack: "HTML/CSS/JS, Vercel",
            liveURL: "https://wealthy-mindset.vercel.app",
            emoji: "🧭"
        ),
        ProjectDefinition(
            id: .dekelLeprisha,
            nameHebrew: "דקל לפרישה",
            nameEnglish: "Dekel Retirement",
            folderName: "דקל לפרישה",
            roofColor: NSColor(red: 0.10, green: 0.44, blue: 0.77, alpha: 1), // #1a6fc4
            wallColor: NSColor(red: 0.05, green: 0.13, blue: 0.28, alpha: 1), // #0d2248
            accentColor: NSColor(red: 0.36, green: 0.77, blue: 0.94, alpha: 1), // #5bc4f0
            techStack: "HTML/CSS/JS, Python, Monday.com",
            liveURL: nil,
            emoji: "🌴"
        ),
        ProjectDefinition(
            id: .alonDev,
            nameHebrew: "Alon.dev",
            nameEnglish: "Alon.dev",
            folderName: "alon-dev",
            roofColor: NSColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1), // #8B5CF6
            wallColor: NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1), // #0A0E1A
            accentColor: NSColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1), // #06B6D4
            techStack: "HTML/CSS/JS, Vercel, Serverless",
            liveURL: "https://alon-dev.vercel.app",
            emoji: "💻"
        ),
        ProjectDefinition(
            id: .alizaHamefarsement,
            nameHebrew: "עליזה המפרסמת",
            nameEnglish: "Aliza Marketing",
            folderName: "עליזה-המפרסמת",
            roofColor: NSColor(red: 0.87, green: 0.20, blue: 0.20, alpha: 1), // #dd3333
            wallColor: NSColor(red: 0.29, green: 0.05, blue: 0.05, alpha: 1), // #4a0e0e
            accentColor: NSColor(red: 1.0, green: 0.40, blue: 0.40, alpha: 1), // #ff6666
            techStack: "Node.js, Express, SQLite, Docker",
            liveURL: "https://aliza-web-production.up.railway.app",
            emoji: "📣"
        ),
        ProjectDefinition(
            id: .hodaatBoker,
            nameHebrew: "הודעת בוקר",
            nameEnglish: "Morning Message",
            folderName: "הודעת-בוקר",
            roofColor: NSColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1), // #10B981
            wallColor: NSColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1), // #1F2937
            accentColor: NSColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1),
            techStack: "Python, Telegram Bot",
            liveURL: nil,
            emoji: "🌅"
        ),
        ProjectDefinition(
            id: .appGames,
            nameHebrew: "אפליקציות ומשחקים",
            nameEnglish: "Apps & Games",
            folderName: "אפליקציות-משחקים",
            roofColor: NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1), // #F59E0B
            wallColor: NSColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1), // #1F2937
            accentColor: NSColor(red: 1.0, green: 0.75, blue: 0.20, alpha: 1),
            techStack: "Capacitor, iOS, Swift",
            liveURL: nil,
            emoji: "🎮"
        ),
    ]

    static func find(_ id: ProjectID) -> ProjectDefinition {
        all.first(where: { $0.id == id })!
    }
}
