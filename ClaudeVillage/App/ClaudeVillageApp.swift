import SwiftUI
import SpriteKit

@main
struct ClaudeVillageApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Claude Village") {
            ContentView(appState: appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
