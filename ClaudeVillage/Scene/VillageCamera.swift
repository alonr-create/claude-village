import SpriteKit

class VillageCamera: SKCameraNode {
    private(set) var currentScale: CGFloat = 1.0

    // MARK: - Pan (two-finger trackpad drag)

    func handlePan(deltaX: CGFloat, deltaY: CGFloat) {
        let moveX = deltaX * currentScale * 1.5
        let moveY = -deltaY * currentScale * 1.5
        position.x -= moveX
        position.y -= moveY
        clampPosition()
    }

    // MARK: - Zoom

    func handleZoom(delta: CGFloat) {
        // delta is ~1.0 per mouse wheel tick
        // Positive delta = scroll up = zoom IN (scale gets smaller)
        // Use a strong factor so even single ticks are noticeable
        let zoomSpeed: CGFloat = 0.15
        let factor = 1.0 - delta * zoomSpeed
        let newScale = currentScale * factor
        applyScale(newScale)
    }

    func handleMagnify(scale: CGFloat) {
        let newScale = currentScale / (1.0 + scale * 0.5)
        applyScale(newScale)
    }

    func zoomIn() {
        applyScale(currentScale * 0.85, animated: true)
    }

    func zoomOut() {
        applyScale(currentScale * 1.18, animated: true)
    }

    // MARK: - Focus

    func focusOn(point: CGPoint, duration: TimeInterval = 0.5) {
        let moveAction = SKAction.move(to: point, duration: duration)
        moveAction.timingMode = .easeInEaseOut
        run(moveAction)
    }

    // MARK: - Private

    private func applyScale(_ newScale: CGFloat, animated: Bool = false) {
        currentScale = max(VillageLayout.minZoom, min(VillageLayout.maxZoom, newScale))
        if animated {
            run(SKAction.scale(to: currentScale, duration: 0.15))
        } else {
            setScale(currentScale)
        }
        clampPosition()
    }

    private func clampPosition() {
        let halfWidth = VillageLayout.sceneSize.width * 0.5
        let halfHeight = VillageLayout.sceneSize.height * 0.5
        position.x = max(-halfWidth, min(halfWidth, position.x))
        position.y = max(-halfHeight, min(halfHeight, position.y))
    }
}
