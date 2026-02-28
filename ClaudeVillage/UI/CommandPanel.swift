import SwiftUI

struct CommandPanel: View {
    @ObservedObject var appState: AppState
    @Binding var isVisible: Bool
    @State private var commandText: String = ""
    @State private var selectedProject: ProjectID = .alonDev

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "command")
                Text("מרכז שליטה")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Project picker
            Picker("פרויקט", selection: $selectedProject) {
                ForEach(ProjectDefinition.all, id: \.id) { project in
                    Text("\(project.emoji) \(project.nameHebrew)").tag(project.id)
                }
            }
            .pickerStyle(.segmented)

            // Command input
            HStack {
                TextField("הקלד פקודה...", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { executeCommand() }

                Button("שלח") { executeCommand() }
                    .buttonStyle(.borderedProminent)
                    .disabled(commandText.isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .frame(width: 400)
    }

    private func executeCommand() {
        guard !commandText.isEmpty else { return }
        let project = ProjectDefinition.find(selectedProject)
        let path = project.folderPath

        // Open terminal with claude command
        let script = """
        tell application "Terminal"
            do script "cd '\(path)' && claude '\(commandText.replacingOccurrences(of: "'", with: "\\'"))'"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }

        commandText = ""
        isVisible = false
    }
}
