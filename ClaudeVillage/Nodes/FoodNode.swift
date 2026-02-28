import SpriteKit

class FoodNode: SKNode {
    private var foodEmoji: SKLabelNode!
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

    private func buildFood() {
        // Random food type — sea creatures love these
        let foods = ["🐟", "🦐", "🐠", "🍣", "🦑", "🐡", "🦞"]
        let chosen = foods.randomElement()!

        // Glow ring (pulsing circle under the food)
        glowRing = SKShapeNode(circleOfRadius: 12)
        glowRing.fillColor = NSColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.3)
        glowRing.strokeColor = NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.6)
        glowRing.lineWidth = 1.5
        glowRing.zPosition = 0
        addChild(glowRing)

        // Pulsing glow
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.8),
            SKAction.scale(to: 0.9, duration: 0.8),
        ])
        glowRing.run(SKAction.repeatForever(pulse))

        // Food emoji
        foodEmoji = SKLabelNode(text: chosen)
        foodEmoji.fontSize = 18
        foodEmoji.verticalAlignmentMode = .center
        foodEmoji.horizontalAlignmentMode = .center
        foodEmoji.zPosition = 1
        addChild(foodEmoji)

        // Gentle hover
        let hover = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 1.0),
            SKAction.moveBy(x: 0, y: -3, duration: 1.0),
        ])
        foodEmoji.run(SKAction.repeatForever(hover))
    }

    /// Drop-from-sky animation when food is placed
    private func dropAnimation() {
        let startY: CGFloat = 60
        foodEmoji.position.y += startY
        foodEmoji.alpha = 0
        glowRing.alpha = 0
        glowRing.setScale(0.1)

        // Food drops down
        let drop = SKAction.group([
            SKAction.moveBy(x: 0, y: -startY, duration: 0.35),
            SKAction.fadeIn(withDuration: 0.2),
        ])
        drop.timingMode = .easeIn
        foodEmoji.run(drop)

        // Bounce on landing
        let bounce = SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
            SKAction.moveBy(x: 0, y: 8, duration: 0.12),
            SKAction.moveBy(x: 0, y: -8, duration: 0.1),
            SKAction.moveBy(x: 0, y: 4, duration: 0.08),
            SKAction.moveBy(x: 0, y: -4, duration: 0.06),
        ])
        foodEmoji.run(bounce)

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
        foodEmoji.removeAllActions()
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
            let crumb = SKLabelNode(text: "✨")
            crumb.fontSize = 10
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

        foodEmoji.run(SKAction.sequence([
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
