import SpriteKit

class HouseNode: SKNode {
    let project: ProjectDefinition
    private var windowLightNodes: [SKShapeNode] = []
    private var glowNode: SKShapeNode?
    private var statusLight: SKShapeNode?
    private var chimneySmoke: SKNode?

    init(project: ProjectDefinition) {
        self.project = project
        super.init()
        self.name = "house_\(project.id.rawValue)"
        buildHouse()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func buildHouse() {
        let houseWidth: CGFloat = 130
        let houseHeight: CGFloat = 70
        let roofHeight: CGFloat = 45

        // Shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: houseWidth + 8, height: houseHeight + 4), cornerRadius: 4)
        shadow.fillColor = NSColor.black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 4, y: -4)
        shadow.zPosition = -1
        addChild(shadow)

        // House body (walls)
        let walls = SKShapeNode(rectOf: CGSize(width: houseWidth, height: houseHeight), cornerRadius: 3)
        walls.fillColor = project.wallColor
        walls.strokeColor = project.wallColor.blended(withFraction: 0.3, of: .white) ?? project.wallColor
        walls.lineWidth = 2
        walls.zPosition = 0
        addChild(walls)

        // Roof (triangle)
        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -houseWidth / 2 - 8, y: houseHeight / 2))
        roofPath.addLine(to: CGPoint(x: 0, y: houseHeight / 2 + roofHeight))
        roofPath.addLine(to: CGPoint(x: houseWidth / 2 + 8, y: houseHeight / 2))
        roofPath.closeSubpath()

        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = project.roofColor
        roof.strokeColor = project.roofColor.blended(withFraction: 0.4, of: .black) ?? project.roofColor
        roof.lineWidth = 2
        roof.zPosition = 1
        addChild(roof)

        // Door
        let door = SKShapeNode(rectOf: CGSize(width: 18, height: 28), cornerRadius: 9)
        door.fillColor = project.roofColor.blended(withFraction: 0.5, of: .black) ?? .brown
        door.strokeColor = project.roofColor.blended(withFraction: 0.7, of: .black) ?? .darkGray
        door.lineWidth = 1.5
        door.position = CGPoint(x: 0, y: -houseHeight / 2 + 14)
        door.zPosition = 1
        addChild(door)

        // Door handle
        let handle = SKShapeNode(circleOfRadius: 2)
        handle.fillColor = project.accentColor
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 5, y: -houseHeight / 2 + 14)
        handle.zPosition = 2
        addChild(handle)

        // Windows (2 on each side)
        let windowPositions: [CGPoint] = [
            CGPoint(x: -35, y: 10),
            CGPoint(x: 35, y: 10),
            CGPoint(x: -35, y: -10),
            CGPoint(x: 35, y: -10),
        ]

        for pos in windowPositions {
            let window = SKShapeNode(rectOf: CGSize(width: 18, height: 16), cornerRadius: 2)
            window.fillColor = NSColor(red: 0.6, green: 0.75, blue: 0.9, alpha: 0.7)
            window.strokeColor = project.wallColor.blended(withFraction: 0.5, of: .white) ?? .gray
            window.lineWidth = 1.5
            window.position = pos
            window.zPosition = 1
            addChild(window)

            // Window light (hidden by default, shown at night)
            let light = SKShapeNode(rectOf: CGSize(width: 16, height: 14), cornerRadius: 1)
            light.fillColor = NSColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.8)
            light.strokeColor = .clear
            light.position = pos
            light.zPosition = 1.5
            light.alpha = 0
            addChild(light)
            windowLightNodes.append(light)
        }

        // Chimney
        let chimney = SKShapeNode(rectOf: CGSize(width: 12, height: 20))
        chimney.fillColor = project.wallColor.blended(withFraction: 0.3, of: .red) ?? .gray
        chimney.strokeColor = .clear
        chimney.position = CGPoint(x: 30, y: houseHeight / 2 + roofHeight - 15)
        chimney.zPosition = 0.5
        addChild(chimney)

        // Name sign
        let signBG = SKShapeNode(rectOf: CGSize(width: 100, height: 22), cornerRadius: 6)
        signBG.fillColor = NSColor.white.withAlphaComponent(0.85)
        signBG.strokeColor = project.roofColor
        signBG.lineWidth = 1.5
        signBG.position = CGPoint(x: 0, y: -houseHeight / 2 - 20)
        signBG.zPosition = 2
        addChild(signBG)

        let nameLabel = SKLabelNode(text: project.nameHebrew)
        nameLabel.fontName = "Arial Hebrew"
        nameLabel.fontSize = 12
        nameLabel.fontColor = project.wallColor
        nameLabel.position = CGPoint(x: 0, y: -houseHeight / 2 - 25)
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .center
        nameLabel.zPosition = 3
        addChild(nameLabel)

        // Emoji badge
        let emojiLabel = SKLabelNode(text: project.emoji)
        emojiLabel.fontSize = 20
        emojiLabel.position = CGPoint(x: 0, y: houseHeight / 2 + roofHeight + 10)
        emojiLabel.zPosition = 3
        addChild(emojiLabel)

        // Activity glow (hidden by default)
        let glow = SKShapeNode(rectOf: CGSize(width: houseWidth + 20, height: houseHeight + roofHeight + 20), cornerRadius: 10)
        glow.fillColor = project.accentColor.withAlphaComponent(0.15)
        glow.strokeColor = project.accentColor.withAlphaComponent(0.4)
        glow.lineWidth = 2
        glow.position = CGPoint(x: 0, y: roofHeight / 2)
        glow.zPosition = -0.5
        glow.alpha = 0
        addChild(glow)
        glowNode = glow

        // Status light (top-right corner)
        let status = SKShapeNode(circleOfRadius: 5)
        status.fillColor = .systemGray
        status.strokeColor = .white
        status.lineWidth = 1.5
        status.position = CGPoint(x: houseWidth / 2 + 5, y: houseHeight / 2 + roofHeight - 5)
        status.zPosition = 4
        addChild(status)
        statusLight = status
    }

    // MARK: - Public Methods

    func setWindowLights(on: Bool) {
        let targetAlpha: CGFloat = on ? 0.8 : 0
        for light in windowLightNodes {
            light.run(SKAction.fadeAlpha(to: targetAlpha, duration: 1.0))
        }
    }

    func setActive(_ active: Bool) {
        guard let glow = glowNode else { return }
        if active {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 1.0),
                SKAction.fadeAlpha(to: 0.2, duration: 1.0),
            ])
            glow.run(SKAction.repeatForever(pulse), withKey: "pulse")
        } else {
            glow.removeAction(forKey: "pulse")
            glow.run(SKAction.fadeAlpha(to: 0, duration: 0.5))
        }
    }

    func setStatus(color: NSColor) {
        statusLight?.fillColor = color
    }

    func startChimneySmoke() {
        guard chimneySmoke == nil else { return }
        let smokeNode = SKNode()
        smokeNode.position = CGPoint(x: 30, y: 70 / 2 + 45 - 5 + 10)
        smokeNode.zPosition = 20

        let emitSmoke = SKAction.sequence([
            SKAction.run { [weak smokeNode] in
                guard let smokeNode = smokeNode else { return }
                let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
                puff.fillColor = NSColor.gray.withAlphaComponent(0.4)
                puff.strokeColor = .clear
                smokeNode.addChild(puff)

                let drift = SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -8...8), y: 30, duration: 2.0),
                    SKAction.fadeOut(withDuration: 2.0),
                    SKAction.scale(to: 2.0, duration: 2.0),
                ])
                puff.run(SKAction.sequence([drift, SKAction.removeFromParent()]))
            },
            SKAction.wait(forDuration: 0.5, withRange: 0.3)
        ])

        smokeNode.run(SKAction.repeatForever(emitSmoke), withKey: "smoke")
        addChild(smokeNode)
        chimneySmoke = smokeNode
    }

    func stopChimneySmoke() {
        chimneySmoke?.removeAllActions()
        chimneySmoke?.removeFromParent()
        chimneySmoke = nil
    }
}
