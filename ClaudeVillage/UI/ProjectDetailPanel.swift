import SwiftUI

struct ProjectDetailPanel: View {
    let projectID: ProjectID
    @ObservedObject var appState: AppState

    private var project: ProjectDefinition {
        ProjectDefinition.find(projectID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with project color
            HStack {
                Text(project.emoji)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(project.nameHebrew)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(project.nameEnglish)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button(action: { appState.clearSelection() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: project.roofColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info section
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "סטאק", value: project.techStack)
                InfoRow(label: "תיקייה", value: project.folderName)

                if let url = project.liveURL {
                    InfoRow(label: "URL", value: url)
                }

                if let status = appState.projectStatuses[projectID] {
                    InfoRow(label: "קבצים", value: "\(status.fileCount)")
                    InfoRow(label: "משימות פעילות", value: "\(status.activeTaskCount)")
                    InfoRow(label: "עדכון אחרון", value: timeAgo(status.lastModified))
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            // Actions
            VStack(spacing: 8) {
                ActionButton(title: "פתח ב-Finder", icon: "folder", color: project.roofColor) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: project.folderPath))
                }
                ActionButton(title: "פתח טרמינל", icon: "terminal", color: project.roofColor) {
                    openTerminal(at: project.folderPath)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60)) דקות" }
        if interval < 86400 { return "\(Int(interval / 3600)) שעות" }
        return "\(Int(interval / 86400)) ימים"
    }

    private func openTerminal(at path: String) {
        let script = "tell application \"Terminal\" to do script \"cd '\(path)'\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: NSColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: color).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
