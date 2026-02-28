import Foundation

struct SessionSummary {
    let sessionID: String
    let projectPath: String?
    let lastActivity: Date
    let agentCount: Int

    var projectID: ProjectID? {
        guard let path = projectPath else { return nil }
        for project in ProjectDefinition.all {
            if path.contains(project.folderName) {
                return project.id
            }
        }
        return nil
    }
}

class SessionDataProvider {
    private let basePath: String

    init() {
        // The path with Hebrew characters
        basePath = NSHomeDirectory() + "/.claude/projects"
    }

    /// Scan recent sessions and determine which projects they belong to
    func scanRecentSessions(limit: Int = 20) -> [SessionSummary] {
        let fm = FileManager.default

        // Find the project directory (it has a mangled name)
        guard let projectDirs = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var sessions: [SessionSummary] = []

        for projectDir in projectDirs {
            let projectPath = basePath + "/" + projectDir
            guard let entries = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }

            // Look for session JSONL files
            let jsonlFiles = entries.filter { $0.hasSuffix(".jsonl") }

            for jsonlFile in jsonlFiles {
                let fullPath = projectPath + "/" + jsonlFile
                let sessionID = jsonlFile.replacingOccurrences(of: ".jsonl", with: "")

                // Get modification date
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }

                // Read first few bytes to find cwd
                let cwdPath = extractCWD(fromFile: fullPath)

                // Count subagents
                let subagentDir = projectPath + "/" + sessionID + "/subagents"
                let agentCount = (try? fm.contentsOfDirectory(atPath: subagentDir))?.count ?? 0

                sessions.append(SessionSummary(
                    sessionID: sessionID,
                    projectPath: cwdPath,
                    lastActivity: modDate,
                    agentCount: agentCount
                ))
            }
        }

        // Sort by most recent and limit
        return sessions
            .sorted { $0.lastActivity > $1.lastActivity }
            .prefix(limit)
            .map { $0 }
    }

    private func extractCWD(fromFile path: String) -> String? {
        // Read just the first 2KB to find cwd field
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        let data = handle.readData(ofLength: 2048)
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        // Look for "cwd" in JSONL
        if let range = text.range(of: "\"cwd\":\"") {
            let start = range.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                return String(text[start..<end])
            }
        }

        return nil
    }
}
