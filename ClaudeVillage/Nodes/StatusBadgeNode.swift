import SpriteKit

class StatusBadgeNode: SKNode {
    private let badgeBG: SKShapeNode
    private let label: SKLabelNode

    init(text: String, color: NSColor) {
        badgeBG = SKShapeNode(rectOf: CGSize(width: CGFloat(text.count) * 7 + 12, height: 16), cornerRadius: 8)
        badgeBG.fillColor = color
        badgeBG.strokeColor = .white
        badgeBG.lineWidth = 1

        label = SKLabelNode(text: text)
        label.fontName = "Arial Hebrew"
        label.fontSize = 9
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        super.init()
        zPosition = 30
        addChild(badgeBG)
        addChild(label)

        // Float animation
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 1.0),
            SKAction.moveBy(x: 0, y: -3, duration: 1.0),
        ])
        run(SKAction.repeatForever(float))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
