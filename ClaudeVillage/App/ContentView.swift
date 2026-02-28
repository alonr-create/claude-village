import SwiftUI
import SpriteKit

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            // SpriteKit village scene via native SKView (supports all mouse events)
            VillageSKView(scene: appState.villageScene)
                .ignoresSafeArea()

            // Top status bar — allowsHitTesting(false) so scroll events pass through to SKView
            VStack {
                StatusBar(appState: appState)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }
            .allowsHitTesting(false)

            // Right panel: detail view (slides in) — only blocks hits when visible
            HStack {
                Spacer()
                if let selected = appState.selectedItem {
                    DetailPanelContainer(item: selected, appState: appState)
                        .frame(width: 320)
                        .transition(.move(edge: .trailing))
                        .animation(.easeInOut(duration: 0.3), value: appState.selectedItem != nil)
                }
            }

            // Bottom-left: minimap
            VStack {
                Spacer()
                HStack {
                    MiniMapView(appState: appState)
                        .frame(width: 180, height: 120)
                        .padding(12)
                    Spacer()
                }
            }
            .allowsHitTesting(false)

            // Bottom-right: request panel (only when requests exist)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RequestPanel(
                        requestSystem: appState.requestSystem,
                        onApprove: { request in
                            appState.villageScene.handleApprovedRequest(request)
                        },
                        onDeny: { request in
                            appState.villageScene.handleDeniedRequest(request)
                        }
                    )
                    .frame(width: 280)
                    .padding(12)
                }
            }
        }
        .background(Color(nsColor: NSColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)))
    }
}

// Custom SKView subclass that ensures scrollWheel events reach the scene
class VillageScrollSKView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        // Forward directly to the scene
        scene?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        scene?.magnify(with: event)
    }

    override func keyDown(with event: NSEvent) {
        scene?.keyDown(with: event)
    }
}

// NSViewRepresentable wrapper for SKView — passes ALL mouse/scroll events to the scene
struct VillageSKView: NSViewRepresentable {
    let scene: VillageScene

    func makeNSView(context: Context) -> VillageScrollSKView {
        let skView = VillageScrollSKView()
        skView.presentScene(scene)
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.allowsTransparency = true
        return skView
    }

    func updateNSView(_ nsView: VillageScrollSKView, context: Context) {}
}

// Placeholder for detail panel container
struct DetailPanelContainer: View {
    let item: SelectedItem
    @ObservedObject var appState: AppState

    var body: some View {
        VStack {
            switch item {
            case .project(let id):
                ProjectDetailPanel(projectID: id, appState: appState)
            case .agent(let id):
                AgentDetailPanel(agentID: id, appState: appState)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .padding(.trailing, 12)
        .padding(.vertical, 60)
    }
}
