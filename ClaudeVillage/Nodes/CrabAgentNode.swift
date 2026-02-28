import SpriteKit

enum CrabState {
    case idle
    case walking(to: ProjectID)
    case working(at: ProjectID)
    case celebrating
}

class CrabAgentNode: SKNode {
    let agent: AgentDefinition
    var currentState: CrabState = .idle
    private var bodyNode: SKShapeNode!
    private var leftClaw: SKShapeNode!
    private var rightClaw: SKShapeNode!
    private var legs: [SKShapeNode] = []
    private var badge: SKShapeNode!
    private var nameLabel: SKLabelNode!
    private var nameBG: SKShapeNode!
    private var eyeLeft: SKShapeNode!
    private var eyeRight: SKShapeNode!
    private var isFlipped = false

    init(agent: AgentDefinition) {
        self.agent = agent
        super.init()
        self.name = "crab_\(agent.id.rawValue)"
        buildCrab()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func buildCrab() {
        let bodyWidth: CGFloat = 28
        let bodyHeight: CGFloat = 20

        // Body (oval)
        bodyNode = SKShapeNode(ellipseOf: CGSize(width: bodyWidth, height: bodyHeight))
        bodyNode.fillColor = agent.bodyColor
        bodyNode.strokeColor = agent.bodyColor.blended(withFraction: 0.3, of: .black) ?? agent.bodyColor
        bodyNode.lineWidth = 1.5
        bodyNode.zPosition = 1
        addChild(bodyNode)

        // Legs (3 per side)
        for side in [-1.0, 1.0] {
            for i in 0..<3 {
                let leg = SKShapeNode(rectOf: CGSize(width: 8, height: 3), cornerRadius: 1.5)
                leg.fillColor = agent.bodyColor.blended(withFraction: 0.2, of: .black) ?? agent.bodyColor
                leg.strokeColor = .clear
                let xOffset = CGFloat(side) * (bodyWidth / 2 + 2)
                let yOffset = CGFloat(i - 1) * 6
                leg.position = CGPoint(x: xOffset, y: yOffset)
                leg.zPosition = 0
                addChild(leg)
                legs.append(leg)
            }
        }

        // Left claw
        leftClaw = createClaw()
        leftClaw.position = CGPoint(x: -bodyWidth / 2 - 6, y: bodyHeight / 2 - 2)
        leftClaw.zPosition = 2
        addChild(leftClaw)

        // Right claw
        rightClaw = createClaw()
        rightClaw.position = CGPoint(x: bodyWidth / 2 + 6, y: bodyHeight / 2 - 2)
        rightClaw.xScale = -1
        rightClaw.zPosition = 2
        addChild(rightClaw)

        // Eyes (two stalks)
        eyeLeft = createEye()
        eyeLeft.position = CGPoint(x: -6, y: bodyHeight / 2 + 4)
        eyeLeft.zPosition = 3
        addChild(eyeLeft)

        eyeRight = createEye()
        eyeRight.position = CGPoint(x: 6, y: bodyHeight / 2 + 4)
        eyeRight.zPosition = 3
        addChild(eyeRight)

        // Role badge (colored circle on body)
        badge = SKShapeNode(circleOfRadius: 5)
        badge.fillColor = agent.badgeColor
        badge.strokeColor = .white
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: 0, y: 0)
        badge.zPosition = 4
        addChild(badge)

        // Role initial on badge
        let initial = SKLabelNode(text: String(agent.nameHebrew.prefix(1)))
        initial.fontName = "Arial Hebrew Bold"
        initial.fontSize = 7
        initial.fontColor = .white
        initial.position = CGPoint(x: 0, y: -3)
        initial.zPosition = 5
        addChild(initial)

        // Name label below
        nameLabel = SKLabelNode(text: agent.nameHebrew)
        nameLabel.fontName = "Arial Hebrew"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -bodyHeight / 2 - 14)
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.zPosition = 5

        // Name background
        nameBG = SKShapeNode(rectOf: CGSize(width: 36, height: 14), cornerRadius: 4)
        nameBG.fillColor = agent.badgeColor.withAlphaComponent(0.7)
        nameBG.strokeColor = .clear
        nameBG.position = CGPoint(x: 0, y: -bodyHeight / 2 - 11)
        nameBG.zPosition = 4.5
        addChild(nameBG)
        addChild(nameLabel)
    }

    private func createClaw() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 6))
        path.addLine(to: CGPoint(x: -2, y: 3))
        path.addLine(to: CGPoint(x: -6, y: -1))
        path.closeSubpath()

        let claw = SKShapeNode(path: path)
        claw.fillColor = agent.bodyColor.blended(withFraction: 0.1, of: .red) ?? agent.bodyColor
        claw.strokeColor = agent.bodyColor.blended(withFraction: 0.3, of: .black) ?? .darkGray
        claw.lineWidth = 1
        return claw
    }

    private func createEye() -> SKShapeNode {
        let eyeGroup = SKShapeNode()

        // Stalk
        let stalk = SKShapeNode(rectOf: CGSize(width: 2, height: 6))
        stalk.fillColor = agent.bodyColor
        stalk.strokeColor = .clear
        stalk.position = CGPoint(x: 0, y: 0)
        eyeGroup.addChild(stalk)

        // Eye ball
        let ball = SKShapeNode(circleOfRadius: 3)
        ball.fillColor = .white
        ball.strokeColor = .darkGray
        ball.lineWidth = 0.5
        ball.position = CGPoint(x: 0, y: 4)
        eyeGroup.addChild(ball)

        // Pupil
        let pupil = SKShapeNode(circleOfRadius: 1.5)
        pupil.fillColor = .black
        pupil.strokeColor = .clear
        pupil.position = CGPoint(x: 0, y: 4)
        eyeGroup.addChild(pupil)

        return eyeGroup
    }

    // MARK: - Animations

    func startIdleAnimation() {
        // Body bob
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.8),
            SKAction.moveBy(x: 0, y: -2, duration: 0.8),
        ])
        bodyNode.run(SKAction.repeatForever(bob), withKey: "idle_bob")

        // Claw open/close
        let clawOpen = SKAction.rotate(byAngle: 0.15, duration: 1.2)
        let clawClose = SKAction.rotate(byAngle: -0.15, duration: 1.2)
        let clawAnim = SKAction.sequence([clawOpen, clawClose])
        leftClaw.run(SKAction.repeatForever(clawAnim), withKey: "idle_claw")
        rightClaw.run(SKAction.repeatForever(SKAction.sequence([clawClose, clawOpen])), withKey: "idle_claw")

        // Eye blink occasionally
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: 3.0, withRange: 2.0),
            SKAction.scaleY(to: 0.1, duration: 0.1),
            SKAction.scaleY(to: 1.0, duration: 0.1),
        ])
        eyeLeft.run(SKAction.repeatForever(blink), withKey: "blink")
        eyeRight.run(SKAction.repeatForever(blink), withKey: "blink")
    }

    func startWalkAnimation() {
        stopAllAnimations()

        // Leg wiggle
        for (i, leg) in legs.enumerated() {
            let delay = Double(i) * 0.1
            let wiggle = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.rotate(byAngle: 0.3, duration: 0.15),
                    SKAction.rotate(byAngle: -0.3, duration: 0.15),
                ]))
            ])
            leg.run(wiggle, withKey: "walk_leg")
        }

        // Body sway
        let sway = SKAction.sequence([
            SKAction.rotate(byAngle: 0.05, duration: 0.2),
            SKAction.rotate(byAngle: -0.1, duration: 0.4),
            SKAction.rotate(byAngle: 0.05, duration: 0.2),
        ])
        bodyNode.run(SKAction.repeatForever(sway), withKey: "walk_sway")
    }

    func startWorkAnimation() {
        stopAllAnimations()

        // Rapid claw movement (typing!)
        let rapidClaw = SKAction.sequence([
            SKAction.rotate(byAngle: 0.2, duration: 0.1),
            SKAction.rotate(byAngle: -0.2, duration: 0.1),
        ])
        leftClaw.run(SKAction.repeatForever(rapidClaw), withKey: "work_claw")
        rightClaw.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(byAngle: -0.2, duration: 0.12),
            SKAction.rotate(byAngle: 0.2, duration: 0.12),
        ])), withKey: "work_claw")

        // Badge pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5),
        ])
        badge.run(SKAction.repeatForever(pulse), withKey: "work_badge")

        // Small focus bob
        let focus = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 1, duration: 0.5),
            SKAction.moveBy(x: 0, y: -1, duration: 0.5),
        ])
        bodyNode.run(SKAction.repeatForever(focus), withKey: "work_bob")
    }

    func celebrate() {
        stopAllAnimations()

        // Jump up and sparkle
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 20, duration: 0.2),
            SKAction.moveBy(x: 0, y: -20, duration: 0.2),
            SKAction.moveBy(x: 0, y: 12, duration: 0.15),
            SKAction.moveBy(x: 0, y: -12, duration: 0.15),
        ])
        run(jump)

        // Sparkle particles
        for _ in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 2)
            spark.fillColor = agent.badgeColor
            spark.strokeColor = .clear
            spark.position = .zero
            spark.zPosition = 20
            addChild(spark)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist: CGFloat = 25
            let fly = SKAction.group([
                SKAction.move(to: CGPoint(x: cos(angle) * dist, y: sin(angle) * dist), duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.scale(to: 0.1, duration: 0.4),
            ])
            spark.run(SKAction.sequence([fly, SKAction.removeFromParent()]))
        }

        // Return to idle after celebration
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in self?.startIdleAnimation() }
        ]))
    }

    // MARK: - Facing Direction

    /// Flip crab to face a direction, keeping name/badge readable
    func faceToward(_ targetX: CGFloat) {
        let shouldFlip = targetX < position.x
        if shouldFlip != isFlipped {
            isFlipped = shouldFlip
            xScale = shouldFlip ? -abs(xScale) : abs(xScale)
            // Counter-flip labels so they stay readable
            let counterScale: CGFloat = shouldFlip ? -1 : 1
            nameLabel.xScale = counterScale
            nameBG.xScale = counterScale
        }
    }

    func walkTo(point: CGPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        startWalkAnimation()
        faceToward(point.x)

        let move = SKAction.move(to: point, duration: duration)
        move.timingMode = .easeInEaseOut

        run(SKAction.sequence([move, SKAction.run {
            completion()
        }]), withKey: "walking")
    }

    // MARK: - Speech

    /// Say something in a speech bubble + speak it aloud
    func say(_ text: String, duration: TimeInterval = 3.0) {
        // Don't overlap bubbles
        if childNode(withName: "//speechBubble") != nil { return }

        // Speak aloud with this agent's unique voice
        VillageAudio.shared.speak(text, agentID: agent.id)

        let bubble = SpeechBubbleNode(text: text)
        bubble.name = "speechBubble"
        // Position above the crab
        // Counter-flip xScale so text is always readable (parent is flipped when isFlipped)
        bubble.position = CGPoint(x: 0, y: 22)
        bubble.alpha = 0
        bubble.yScale = 0.5
        bubble.xScale = isFlipped ? -0.5 : 0.5
        addChild(bubble)

        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.scaleY(to: 1.0, duration: 0.2),
            SKAction.scaleX(to: isFlipped ? -1.0 : 1.0, duration: 0.2),
        ])
        let stay = SKAction.wait(forDuration: duration)
        let disappear = SKAction.group([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.scaleY(to: 0.8, duration: 0.3),
            SKAction.scaleX(to: isFlipped ? -0.8 : 0.8, duration: 0.3),
        ])

        bubble.run(SKAction.sequence([appear, stay, disappear, SKAction.removeFromParent()]))
    }

    private func stopAllAnimations() {
        bodyNode.removeAllActions()
        leftClaw.removeAllActions()
        rightClaw.removeAllActions()
        badge.removeAllActions()
        eyeLeft.removeAllActions()
        eyeRight.removeAllActions()
        for leg in legs {
            leg.removeAllActions()
            leg.zRotation = 0
        }
        bodyNode.position = .zero
        bodyNode.zRotation = 0
        leftClaw.zRotation = 0
        rightClaw.zRotation = 0
        badge.setScale(1.0)
    }
}
