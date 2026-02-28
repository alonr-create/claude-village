import SwiftUI
import SpriteKit
import Combine

enum SelectedItem: Equatable {
    case project(ProjectID)
    case agent(AgentID)
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedItem: SelectedItem?
    @Published var projectStatuses: [ProjectID: ProjectStatus] = [:]
    @Published var activeTodos: [String: [TodoItem]] = [:]
    @Published var agentAssignments: [AgentID: ProjectID] = [:]
    @Published var agentStates: [AgentID: AgentState] = [:]

    let villageScene: VillageScene
    let webServer = VillageWebServer()
    let requestSystem = RequestSystem()

    init() {
        let scene = VillageScene(size: CGSize(width: 2000, height: 1500))
        scene.scaleMode = .resizeFill
        self.villageScene = scene

        // Give the scene a reference back to us
        scene.appStateRef = self

        // Start web server for mobile access
        webServer.start()
        print("📱 Mobile viewer: \(webServer.localURL)")
    }

    func selectProject(_ id: ProjectID) {
        withAnimation {
            selectedItem = .project(id)
        }
    }

    func selectAgent(_ id: AgentID) {
        withAnimation {
            selectedItem = .agent(id)
        }
    }

    func clearSelection() {
        withAnimation {
            selectedItem = nil
        }
    }
}

struct ProjectStatus {
    var lastModified: Date
    var fileCount: Int
    var hasAiTeam: Bool
    var activeTaskCount: Int
    var techStack: String
}
