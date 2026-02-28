import SpriteKit

class SpeechBubbleNode: SKNode {

    init(text: String, maxWidth: CGFloat = 120) {
        super.init()
        self.zPosition = 25
        buildBubble(text: text, maxWidth: maxWidth)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func buildBubble(text: String, maxWidth: CGFloat) {
        // Label first to measure
        let label = SKLabelNode(text: text)
        label.fontName = "Arial Hebrew"
        label.fontSize = 10
        label.fontColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = maxWidth - 16
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        let textWidth = min(label.frame.width + 16, maxWidth)
        let textHeight = max(label.frame.height + 12, 24)

        // Bubble background
        let bubblePath = CGMutablePath()
        let cornerRadius: CGFloat = 8
        let tailSize: CGFloat = 6
        let rect = CGRect(x: -textWidth / 2, y: 0, width: textWidth, height: textHeight)

        // Rounded rect
        bubblePath.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        // Tail (little triangle pointing down)
        bubblePath.move(to: CGPoint(x: -tailSize, y: 0))
        bubblePath.addLine(to: CGPoint(x: 0, y: -tailSize))
        bubblePath.addLine(to: CGPoint(x: tailSize, y: 0))

        let bg = SKShapeNode(path: bubblePath)
        bg.fillColor = .white
        bg.strokeColor = NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        bg.lineWidth = 1
        addChild(bg)

        label.position = CGPoint(x: 0, y: textHeight / 2)
        addChild(label)
    }

    static func show(above node: SKNode, text: String, duration: TimeInterval = 3.0) {
        let bubble = SpeechBubbleNode(text: text)
        bubble.position = CGPoint(x: 0, y: 22)
        bubble.alpha = 0
        bubble.setScale(0.5)
        node.addChild(bubble)

        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2),
        ])
        let stay = SKAction.wait(forDuration: duration)
        let disappear = SKAction.group([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.scale(to: 0.8, duration: 0.3),
        ])

        bubble.run(SKAction.sequence([appear, stay, disappear, SKAction.removeFromParent()]))
    }
}
