import SpriteKit

class FoodNode: SKNode {
    private var foodEmoji: SKLabelNode!
    private var foodSprite: SKSpriteNode?
    private var glowRing: SKShapeNode!
    var isBeingEaten = false

    override init() {
        super.init()
        self.name = "food"
        buildFood()
        dropAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// Turkish food items — the crabs' favorite cuisine!
    static let turkishFoods: [(emoji: String, icon: String, name: String)] = [
        ("🥙", "doner", "דונר"),
        ("🍖", "iskender", "איסקנדר"),
        ("🥟", "manti", "מנטי"),
        ("🫓", "lahmacun", "לחמג׳ון"),
        ("🍢", "shish-kebab", "שיש קבב"),
        ("🧆", "kofta", "כופתה"),
        ("🫕", "pide", "פידה"),
        ("🍚", "pilaf", "פילאף"),
        ("🍬", "baklava", "באקלווה"),
        ("🫖", "chai", "צ׳אי"),
        ("☕", "turkish-coffee", "קפה טורקי"),
    ]

    private(set) var foodName: String = ""

    private func buildFood() {
        // Random Turkish food — the crabs love it!
        let chosen = FoodNode.turkishFoods.randomElement()!
        foodName = chosen.name

        // Glow ring (pulsing circle under the food)
        glowRing = SKShapeNode(circleOfRadius: 14)
        glowRing.fillColor = NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.3)
        glowRing.strokeColor = NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.6)
        glowRing.lineWidth = 1.5
        glowRing.zPosition = 0
        addChild(glowRing)

        // Pulsing glow
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.8),
            SKAction.scale(to: 0.9, duration: 0.8),
        ])
        glowRing.run(SKAction.repeatForever(pulse))

        // Food icon (with emoji fallback)
        if let texture = VillageIcons.texture(chosen.icon) {
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 24, height: 24))
            sprite.zPosition = 1
            addChild(sprite)
            foodEmoji = SKLabelNode(text: "")  // placeholder for animation reference
            foodEmoji.zPosition = -99
            addChild(foodEmoji)
            // Use sprite for animations instead of foodEmoji
            foodSprite = sprite
        } else {
            foodEmoji = SKLabelNode(text: chosen.emoji)
            foodEmoji.fontSize = 20
            foodEmoji.verticalAlignmentMode = .center
            foodEmoji.horizontalAlignmentMode = .center
            foodEmoji.zPosition = 1
            addChild(foodEmoji)
        }

        // Food name label (small Hebrew text below emoji)
        let nameLabel = SKLabelNode(text: chosen.name)
        nameLabel.fontSize = 7
        nameLabel.fontName = "Arial Hebrew"
        nameLabel.fontColor = NSColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.9)
        nameLabel.verticalAlignmentMode = .top
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -14)
        nameLabel.zPosition = 1
        addChild(nameLabel)

        // Gentle hover (food + label together)
        let hover = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 1.0),
            SKAction.moveBy(x: 0, y: -3, duration: 1.0),
        ])
        let animTarget: SKNode = foodSprite ?? foodEmoji
        animTarget.run(SKAction.repeatForever(hover))
        nameLabel.run(SKAction.repeatForever(hover))
    }

    /// Drop-from-sky animation when food is placed
    private func dropAnimation() {
        let animTarget: SKNode = foodSprite ?? foodEmoji
        let startY: CGFloat = 60
        animTarget.position.y += startY
        animTarget.alpha = 0
        glowRing.alpha = 0
        glowRing.setScale(0.1)

        // Food drops down
        let drop = SKAction.group([
            SKAction.moveBy(x: 0, y: -startY, duration: 0.35),
            SKAction.fadeIn(withDuration: 0.2),
        ])
        drop.timingMode = .easeIn
        animTarget.run(drop)

        // Bounce on landing
        let bounce = SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
            SKAction.moveBy(x: 0, y: 8, duration: 0.12),
            SKAction.moveBy(x: 0, y: -8, duration: 0.1),
            SKAction.moveBy(x: 0, y: 4, duration: 0.08),
            SKAction.moveBy(x: 0, y: -4, duration: 0.06),
        ])
        animTarget.run(bounce)

        // Glow ring appears after landing
        glowRing.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3),
            ])
        ]))

        // Spawn some particles on impact
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
            SKAction.run { [weak self] in self?.spawnImpactParticles() }
        ]))
    }

    private func spawnImpactParticles() {
        for _ in 0..<6 {
            let particle = SKShapeNode(circleOfRadius: 1.5)
            particle.fillColor = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.8)
            particle.strokeColor = .clear
            particle.zPosition = 2
            addChild(particle)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 10...20)
            let fly = SKAction.group([
                SKAction.move(to: CGPoint(x: cos(angle) * dist, y: sin(angle) * dist), duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3),
            ])
            particle.run(SKAction.sequence([fly, SKAction.removeFromParent()]))
        }
    }

    /// Called when a crab reaches the food — eating animation then removal
    func getEaten(by crab: CrabAgentNode) {
        guard !isBeingEaten else { return }
        isBeingEaten = true

        // Stop hovering
        let animTarget: SKNode = foodSprite ?? foodEmoji
        animTarget.removeAllActions()
        glowRing.removeAllActions()

        // Shrink + nom nom particles
        let shrink = SKAction.group([
            SKAction.scale(to: 0.0, duration: 0.4),
            SKAction.fadeOut(withDuration: 0.4),
        ])

        // Glow ring fades
        glowRing.run(SKAction.fadeOut(withDuration: 0.3))

        // Yummy particles
        for i in 0..<5 {
            let crumb: SKNode
            if let tex = VillageIcons.texture("sparkle") {
                crumb = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
            } else {
                let label = SKLabelNode(text: "✨")
                label.fontSize = 10
                crumb = label
            }
            crumb.position = .zero
            crumb.zPosition = 3
            addChild(crumb)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 8...16)
            let delay = Double(i) * 0.06
            let fly = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.move(to: CGPoint(x: cos(angle) * dist, y: sin(angle) * dist + 10), duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.35),
                    SKAction.scale(to: 0.3, duration: 0.35),
                ]),
                SKAction.removeFromParent()
            ])
            crumb.run(fly)
        }

        animTarget.run(SKAction.sequence([
            shrink,
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in self?.removeFromParent() }
        ]))
    }

    /// Auto-despawn after timeout (food goes stale)
    func startDespawnTimer(seconds: TimeInterval = 30) {
        run(SKAction.sequence([
            SKAction.wait(forDuration: seconds),
            SKAction.run { [weak self] in
                guard let self = self, !self.isBeingEaten else { return }
                // Fade away
                let fadeOut = SKAction.group([
                    SKAction.fadeOut(withDuration: 1.0),
                    SKAction.scale(to: 0.5, duration: 1.0),
                ])
                self.run(SKAction.sequence([fadeOut, SKAction.removeFromParent()]))
            }
        ]), withKey: "despawn")
    }
}
