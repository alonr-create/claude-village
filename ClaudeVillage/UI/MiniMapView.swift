import SwiftUI

struct MiniMapView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.5))

            // Mini houses
            GeometryReader { geo in
                let scaleX = geo.size.width / VillageLayout.sceneSize.width
                let scaleY = geo.size.height / VillageLayout.sceneSize.height
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2

                ForEach(VillageLayout.houses, id: \.project) { layout in
                    let project = ProjectDefinition.find(layout.project)
                    Circle()
                        .fill(Color(nsColor: project.roofColor))
                        .frame(width: 8, height: 8)
                        .position(
                            x: centerX + layout.position.x * scaleX,
                            y: centerY - layout.position.y * scaleY // flip Y
                        )
                }

                // Camera viewport indicator
                let cameraPos = appState.villageScene.villageCamera.position
                let cameraScale = appState.villageScene.villageCamera.xScale
                let viewWidth = 300 * cameraScale * scaleX
                let viewHeight = 200 * cameraScale * scaleY

                Rectangle()
                    .stroke(.white.opacity(0.6), lineWidth: 1)
                    .frame(width: max(viewWidth, 20), height: max(viewHeight, 14))
                    .position(
                        x: centerX + cameraPos.x * scaleX,
                        y: centerY - cameraPos.y * scaleY
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}
