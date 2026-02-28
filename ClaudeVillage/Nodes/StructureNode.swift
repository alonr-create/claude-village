import SpriteKit

/// A structure built by an agent in the village
class StructureNode: SKNode {
    let structureType: String
    let builder: AgentID

    init(type: String, builder: AgentID) {
        self.structureType = type
        self.builder = builder
        super.init()
        self.name = "structure_\(type)"
        buildVisual()
        appearAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func buildVisual() {
        switch structureType {
        case "שלט":       buildSign()
        case "ספסל", "ספסל תצפית": buildBench()
        case "גדר", "גדר דקורטיבית": buildFence()
        case "פנס":       buildLamp()
        case "גן פרחים":  buildGarden()
        case "גשר":       buildBridge()
        case "באר":       buildWell()
        case "דרך":       buildPath()
        case "לוח מודעות": buildNoticeBoard()
        case "עמדת בדיקה": buildTestStation()
        default:          buildGeneric()
        }

        // Builder tag (small label)
        let tag = SKLabelNode(text: AgentDefinition.find(builder).nameHebrew)
        tag.fontSize = 6
        tag.fontName = "Arial Hebrew"
        tag.fontColor = NSColor.white.withAlphaComponent(0.6)
        tag.position = CGPoint(x: 0, y: -18)
        tag.horizontalAlignmentMode = .center
        tag.zPosition = 3
        addChild(tag)

        // Hammer icon next to builder name
        if let tex = VillageIcons.texture("hammer") {
            let hammerSprite = SKSpriteNode(texture: tex, size: CGSize(width: 8, height: 8))
            hammerSprite.position = CGPoint(x: tag.frame.width / 2 + 6, y: -17)
            hammerSprite.zPosition = 3
            addChild(hammerSprite)
        } else {
            let hammer = SKLabelNode(text: "🔨")
            hammer.fontSize = 5
            hammer.position = CGPoint(x: tag.frame.width / 2 + 6, y: -19)
            hammer.zPosition = 3
            addChild(hammer)
        }
    }

    // MARK: - Structure Visuals

    private func buildSign() {
        // Wooden post
        let post = SKShapeNode(rectOf: CGSize(width: 3, height: 18))
        post.fillColor = NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        post.strokeColor = .clear
        post.position = CGPoint(x: 0, y: -4)
        addChild(post)

        // Sign board
        let board = SKShapeNode(rectOf: CGSize(width: 22, height: 10), cornerRadius: 2)
        board.fillColor = NSColor(red: 0.6, green: 0.45, blue: 0.25, alpha: 1)
        board.strokeColor = NSColor(red: 0.4, green: 0.3, blue: 0.15, alpha: 1)
        board.lineWidth = 1
        board.position = CGPoint(x: 0, y: 8)
        addChild(board)

        // Sign icon
        if let tex = VillageIcons.texture("notice-board") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
            sprite.position = CGPoint(x: 0, y: 6)
            addChild(sprite)
        } else {
            let text = SKLabelNode(text: "📌")
            text.fontSize = 8
            text.position = CGPoint(x: 0, y: 5)
            addChild(text)
        }
    }

    private func buildBench() {
        // Seat
        let seat = SKShapeNode(rectOf: CGSize(width: 24, height: 4), cornerRadius: 1)
        seat.fillColor = NSColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
        seat.strokeColor = NSColor(red: 0.4, green: 0.28, blue: 0.15, alpha: 1)
        seat.lineWidth = 1
        seat.position = CGPoint(x: 0, y: 2)
        addChild(seat)

        // Legs
        for xOff: CGFloat in [-8, 8] {
            let leg = SKShapeNode(rectOf: CGSize(width: 3, height: 6))
            leg.fillColor = NSColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 1)
            leg.strokeColor = .clear
            leg.position = CGPoint(x: xOff, y: -3)
            addChild(leg)
        }

        // Backrest
        let back = SKShapeNode(rectOf: CGSize(width: 22, height: 2), cornerRadius: 1)
        back.fillColor = NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        back.strokeColor = .clear
        back.position = CGPoint(x: 0, y: 7)
        addChild(back)
    }

    private func buildFence() {
        let fenceWidth: CGFloat = 30
        let posts = 4

        for i in 0..<posts {
            let x = -fenceWidth / 2 + CGFloat(i) * fenceWidth / CGFloat(posts - 1)
            let post = SKShapeNode(rectOf: CGSize(width: 3, height: 14))
            post.fillColor = NSColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1)
            post.strokeColor = .clear
            post.position = CGPoint(x: x, y: 0)
            addChild(post)
        }

        // Horizontal rails
        for y: CGFloat in [-2, 3] {
            let rail = SKShapeNode(rectOf: CGSize(width: fenceWidth, height: 2))
            rail.fillColor = NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 0.9)
            rail.strokeColor = .clear
            rail.position = CGPoint(x: 0, y: y)
            addChild(rail)
        }
    }

    private func buildLamp() {
        // Pole
        let pole = SKShapeNode(rectOf: CGSize(width: 2, height: 22))
        pole.fillColor = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        pole.strokeColor = .clear
        pole.position = CGPoint(x: 0, y: 0)
        addChild(pole)

        // Lamp head
        let lamp = SKShapeNode(circleOfRadius: 5)
        lamp.fillColor = NSColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.9)
        lamp.strokeColor = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        lamp.lineWidth = 1
        lamp.position = CGPoint(x: 0, y: 13)
        addChild(lamp)

        // Glow effect
        let glow = SKShapeNode(circleOfRadius: 12)
        glow.fillColor = NSColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.15)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 13)
        glow.zPosition = -1
        addChild(glow)

        // Pulse glow
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.08, duration: 1.5),
            SKAction.fadeAlpha(to: 0.2, duration: 1.5),
        ])
        glow.run(SKAction.repeatForever(pulse))
    }

    private func buildGarden() {
        // Soil circle
        let soil = SKShapeNode(circleOfRadius: 12)
        soil.fillColor = NSColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 0.8)
        soil.strokeColor = NSColor(red: 0.25, green: 0.18, blue: 0.1, alpha: 0.6)
        soil.lineWidth = 1
        soil.position = .zero
        addChild(soil)

        // Flowers
        let colors: [NSColor] = [.systemRed, .systemPink, .systemYellow, .systemOrange, .white]
        for _ in 0..<6 {
            let flower = SKShapeNode(circleOfRadius: 2.5)
            flower.fillColor = colors.randomElement()!
            flower.strokeColor = .clear
            flower.position = CGPoint(
                x: CGFloat.random(in: -8...8),
                y: CGFloat.random(in: -8...8)
            )
            flower.zPosition = 1
            addChild(flower)

            // Center
            let center = SKShapeNode(circleOfRadius: 1)
            center.fillColor = .systemYellow
            center.strokeColor = .clear
            center.position = flower.position
            center.zPosition = 2
            addChild(center)
        }
    }

    private func buildBridge() {
        // Bridge planks
        let bridgeW: CGFloat = 28
        let bridgeH: CGFloat = 10

        let base = SKShapeNode(rectOf: CGSize(width: bridgeW, height: bridgeH), cornerRadius: 2)
        base.fillColor = NSColor(red: 0.5, green: 0.38, blue: 0.22, alpha: 1)
        base.strokeColor = NSColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
        base.lineWidth = 1.5
        addChild(base)

        // Railings
        for xOff: CGFloat in [-bridgeW / 2, bridgeW / 2] {
            let railing = SKShapeNode(rectOf: CGSize(width: 2, height: 14))
            railing.fillColor = NSColor(red: 0.4, green: 0.3, blue: 0.18, alpha: 1)
            railing.strokeColor = .clear
            railing.position = CGPoint(x: xOff, y: 3)
            addChild(railing)
        }

        // Bridge icon
        if let tex = VillageIcons.texture("bridge") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 10, height: 10))
            sprite.position = CGPoint(x: 0, y: -2)
            addChild(sprite)
        } else {
            let emoji = SKLabelNode(text: "🌉")
            emoji.fontSize = 6
            emoji.position = CGPoint(x: 0, y: -2)
            addChild(emoji)
        }
    }

    private func buildWell() {
        // Base circle
        let base = SKShapeNode(circleOfRadius: 8)
        base.fillColor = NSColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        base.strokeColor = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        base.lineWidth = 2
        addChild(base)

        // Water inside
        let water = SKShapeNode(circleOfRadius: 5)
        water.fillColor = NSColor(red: 0.3, green: 0.55, blue: 0.8, alpha: 0.7)
        water.strokeColor = .clear
        addChild(water)

        // Roof support
        let support = SKShapeNode(rectOf: CGSize(width: 2, height: 12))
        support.fillColor = NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        support.strokeColor = .clear
        support.position = CGPoint(x: 0, y: 10)
        addChild(support)
    }

    private func buildPath() {
        // Short road segment
        let path = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 3)
        path.fillColor = NSColor(red: 0.55, green: 0.45, blue: 0.32, alpha: 0.8)
        path.strokeColor = NSColor(red: 0.45, green: 0.35, blue: 0.22, alpha: 0.5)
        path.lineWidth = 1
        addChild(path)
    }

    private func buildNoticeBoard() {
        // Board
        let board = SKShapeNode(rectOf: CGSize(width: 18, height: 14), cornerRadius: 1)
        board.fillColor = NSColor(red: 0.6, green: 0.5, blue: 0.35, alpha: 1)
        board.strokeColor = NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1)
        board.lineWidth = 1
        board.position = CGPoint(x: 0, y: 6)
        addChild(board)

        // Posts
        for x: CGFloat in [-7, 7] {
            let post = SKShapeNode(rectOf: CGSize(width: 2, height: 16))
            post.fillColor = NSColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 1)
            post.strokeColor = .clear
            post.position = CGPoint(x: x, y: -2)
            addChild(post)
        }

        // Notes icon
        if let tex = VillageIcons.texture("clipboard") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
            sprite.position = CGPoint(x: 0, y: 4)
            addChild(sprite)
        } else {
            let note = SKLabelNode(text: "📋")
            note.fontSize = 8
            note.position = CGPoint(x: 0, y: 3)
            addChild(note)
        }
    }

    private func buildTestStation() {
        // Desk
        let desk = SKShapeNode(rectOf: CGSize(width: 20, height: 8), cornerRadius: 1)
        desk.fillColor = NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)
        desk.strokeColor = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        desk.lineWidth = 1
        addChild(desk)

        // Computer icon
        if let tex = VillageIcons.texture("computer-screen") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 14, height: 14))
            sprite.position = CGPoint(x: 0, y: 8)
            addChild(sprite)
        } else {
            let screen = SKLabelNode(text: "🖥️")
            screen.fontSize = 10
            screen.position = CGPoint(x: 0, y: 8)
            addChild(screen)
        }

        // Bug icon
        if let tex = VillageIcons.texture("bug") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 10, height: 10))
            sprite.position = CGPoint(x: 8, y: -2)
            addChild(sprite)
        } else {
            let bug = SKLabelNode(text: "🐛")
            bug.fontSize = 6
            bug.position = CGPoint(x: 8, y: -2)
            addChild(bug)
        }
    }

    private func buildGeneric() {
        let block = SKShapeNode(rectOf: CGSize(width: 16, height: 16), cornerRadius: 3)
        block.fillColor = NSColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1)
        block.strokeColor = NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1)
        block.lineWidth = 1
        addChild(block)

        if let tex = VillageIcons.texture("construction") {
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
            sprite.position = CGPoint(x: 0, y: -4)
            addChild(sprite)
        } else {
            let emoji = SKLabelNode(text: "🏗️")
            emoji.fontSize = 10
            emoji.position = CGPoint(x: 0, y: -4)
            addChild(emoji)
        }
    }

    // MARK: - Appear Animation

    private func appearAnimation() {
        setScale(0.0)
        alpha = 0

        // Construction site first (wooden frame)
        let frame = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
        frame.strokeColor = NSColor(red: 0.6, green: 0.45, blue: 0.25, alpha: 0.8)
        frame.fillColor = .clear
        frame.lineWidth = 2
        frame.name = "constructionFrame"
        addChild(frame)

        // Hammer particles
        let hammerAction = SKAction.repeat(SKAction.sequence([
            SKAction.run { [weak self] in
                let spark: SKNode
                if let tex = VillageIcons.texture("sparkle") {
                    spark = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
                } else {
                    let label = SKLabelNode(text: "⚡")
                    label.fontSize = 8
                    spark = label
                }
                spark.position = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -5...10))
                spark.zPosition = 5
                self?.addChild(spark)
                spark.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: 10, duration: 0.3),
                        SKAction.fadeOut(withDuration: 0.3),
                    ]),
                    SKAction.removeFromParent()
                ]))
            },
            SKAction.wait(forDuration: 0.3),
        ]), count: 8)

        // Build sequence
        run(SKAction.sequence([
            // Phase 1: construction frame appears
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.3),
                SKAction.scale(to: 0.5, duration: 0.3),
            ]),
            // Phase 2: building in progress
            hammerAction,
            // Phase 3: final structure appears
            SKAction.run { [weak self] in
                self?.childNode(withName: "constructionFrame")?.removeFromParent()
            },
            SKAction.scale(to: 1.0, duration: 0.3),
        ]))
    }
}
