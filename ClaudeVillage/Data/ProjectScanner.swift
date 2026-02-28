import Foundation

class ProjectScanner {
    /// Scan a project folder and return its status
    func scan(project: ProjectDefinition) -> ProjectStatus {
        let fm = FileManager.default
        let path = project.folderPath

        // Last modification date
        let lastModified: Date
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let date = attrs[.modificationDate] as? Date {
            lastModified = date
        } else {
            lastModified = .distantPast
        }

        // File count (top level only for performance)
        let fileCount = (try? fm.contentsOfDirectory(atPath: path))?.count ?? 0

        // Check for .ai_team directory
        let hasAiTeam = fm.fileExists(atPath: path + "/.ai_team")

        // Check for CLAUDE.md
        _ = fm.fileExists(atPath: path + "/CLAUDE.md")

        return ProjectStatus(
            lastModified: lastModified,
            fileCount: fileCount,
            hasAiTeam: hasAiTeam,
            activeTaskCount: 0,
            techStack: project.techStack
        )
    }

    /// Scan all projects
    func scanAll() -> [ProjectID: ProjectStatus] {
        var statuses: [ProjectID: ProjectStatus] = [:]
        for project in ProjectDefinition.all {
            statuses[project.id] = scan(project: project)
        }
        return statuses
    }
}
