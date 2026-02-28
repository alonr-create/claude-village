import SpriteKit
import SwiftUI

class VillageScene: SKScene {
    weak var appStateRef: AppState?
    let villageCamera = VillageCamera()
    var houseNodes: [ProjectID: HouseNode] = [:]
    var crabNodes: [AgentID: CrabAgentNode] = [:]
    var pathNodes: [SKShapeNode] = []
    private var dayNightOverlay: SKSpriteNode?
    private(set) var behaviorManager: AgentBehaviorManager?
    var foodNodes: [FoodNode] = []
    var structureNodes: [SKNode] = []

    // Speech system — Turkish food themed!
    private static let thankYouPhrases = [
        "!וואו! דונר! 😍",
        "!באקלווה! חיים טובים 🍬",
        "!קבב! הכי טעים 🍖",
        "!תודה אלון! יאמי 😋",
        "!מנטי! כמו בטורקיה 🥟",
        "!אתה הבוס הכי טוב 💕",
        "!לחמג׳ון! ממממ 🫓",
        "!פידה חמה! מעולה 🫕",
        "!שף טורקי מספר 1! 👨‍🍳",
        "!חיים טובים בכפר 🏡",
    ]

    private static let requestPhrases = [
        "!רוצה דונר 🥙",
        "?יש לחמג׳ון 🫓",
        "!צריך באקלווה דחוף 🍬",
        "?אלון, קבב בבקשה 🙏",
        "רעבבבב... איסקנדר! 😩",
        "?מישהו הזמין מנטי 🥟",
        "!מגיע לנו פידה חמה 🫕",
        "...העבודה קשה, צריך צ׳אי 🫖",
        "!כופתה! כופתה 🧆",
        "?אלון... רעב פה 🥺",
    ]

    private var didSetup = false

    override func didMove(to view: SKView) {
        // Guard against SwiftUI re-presenting the scene (didMove called twice)
        guard !didSetup else { return }
        didSetup = true

        backgroundColor = NSColor(red: 0.28, green: 0.55, blue: 0.25, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Setup camera
        villageCamera.position = .zero
        addChild(villageCamera)
        camera = villageCamera

        // Build the village
        setupGround()
        setupPaths()
        setupHouses()
        setupCrabs()
        setupFountain()
        setupDecorations()
        setupDayNightOverlay()

        // Start agent behavior system
        behaviorManager = AgentBehaviorManager(scene: self)
        behaviorManager?.start()

        // Start random speech (crabs ask for food/water)
        startRandomSpeech()

        // Start ambient village sounds (birds, water, wind)
        VillageAudio.shared.startAmbient()
    }

    // MARK: - Ground

    private func setupGround() {
        // Grass background
        let ground = SKSpriteNode(color: NSColor(red: 0.28, green: 0.55, blue: 0.25, alpha: 1.0),
                                  size: VillageLayout.sceneSize)
        ground.position = .zero
        ground.zPosition = -10
        addChild(ground)

        // Add some grass texture variation
        for _ in 0..<80 {
            let grassPatch = SKShapeNode(circleOfRadius: CGFloat.random(in: 15...40))
            grassPatch.fillColor = NSColor(red: CGFloat.random(in: 0.24...0.32),
                                           green: CGFloat.random(in: 0.50...0.60),
                                           blue: CGFloat.random(in: 0.20...0.30),
                                           alpha: 0.5)
            grassPatch.strokeColor = .clear
            grassPatch.position = CGPoint(
                x: CGFloat.random(in: -800...800),
                y: CGFloat.random(in: -600...600)
            )
            grassPatch.zPosition = -9
            addChild(grassPatch)
        }
    }

    // MARK: - Paths/Roads

    private func setupPaths() {
        for road in VillageLayout.roadPaths {
            let fromPos = VillageLayout.position(for: road.from)
            let toPos = VillageLayout.position(for: road.to)

            let path = CGMutablePath()
            // Curved road through center area
            let midX = (fromPos.x + toPos.x) / 2
            let midY = (fromPos.y + toPos.y) / 2
            let controlX = midX + CGFloat.random(in: -30...30)
            let controlY = midY + CGFloat.random(in: -30...30)

            path.move(to: fromPos)
            path.addQuadCurve(to: toPos, control: CGPoint(x: controlX, y: controlY))

            let roadNode = SKShapeNode(path: path)
            roadNode.strokeColor = NSColor(red: 0.55, green: 0.45, blue: 0.32, alpha: 0.7)
            roadNode.lineWidth = 12
            roadNode.lineCap = .round
            roadNode.zPosition = -5

            // Road border
            let borderNode = SKShapeNode(path: path)
            borderNode.strokeColor = NSColor(red: 0.45, green: 0.35, blue: 0.22, alpha: 0.4)
            borderNode.lineWidth = 16
            borderNode.lineCap = .round
            borderNode.zPosition = -6

            addChild(borderNode)
            addChild(roadNode)
            pathNodes.append(roadNode)
        }
    }

    // MARK: - Houses

    private func setupHouses() {
        for layout in VillageLayout.houses {
            let project = ProjectDefinition.all.first(where: { $0.id == layout.project })!
            let house = HouseNode(project: project)
            house.position = layout.position
            house.zPosition = 10
            addChild(house)
            houseNodes[layout.project] = house
        }
    }

    // MARK: - Crabs

    private func setupCrabs() {
        for agent in AgentDefinition.all {
            let crab = CrabAgentNode(agent: agent)
            // Start each crab near a house
            let startHouse = VillageLayout.houses[AgentDefinition.all.firstIndex(where: { $0.id == agent.id })! % VillageLayout.houses.count]
            crab.position = CGPoint(
                x: startHouse.position.x + CGFloat.random(in: -40...40),
                y: startHouse.position.y - 70
            )
            crab.zPosition = 15
            addChild(crab)
            crabNodes[agent.id] = crab
            crab.startIdleAnimation()
        }
    }

    // MARK: - Fountain

    private func setupFountain() {
        let fountain = SKNode()
        fountain.position = VillageLayout.villageCenter
        fountain.zPosition = 5

        // Base circle
        let base = SKShapeNode(circleOfRadius: 30)
        base.fillColor = NSColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 0.8)
        base.strokeColor = NSColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1.0)
        base.lineWidth = 3
        fountain.addChild(base)

        // Inner water circle
        let water = SKShapeNode(circleOfRadius: 22)
        water.fillColor = NSColor(red: 0.3, green: 0.6, blue: 0.85, alpha: 0.7)
        water.strokeColor = .clear
        fountain.addChild(water)

        // Water shimmer animation
        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 1.5),
            SKAction.fadeAlpha(to: 0.8, duration: 1.5)
        ])
        water.run(SKAction.repeatForever(shimmer))

        // Center pillar
        let pillar = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 2)
        pillar.fillColor = NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        pillar.strokeColor = .clear
        fountain.addChild(pillar)

        // Water droplet particles (simple circles that rise and fall)
        let dropletTimer = SKAction.sequence([
            SKAction.run { [weak fountain] in
                guard let fountain = fountain else { return }
                let droplet = SKShapeNode(circleOfRadius: 2)
                droplet.fillColor = NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.8)
                droplet.strokeColor = .clear
                droplet.position = CGPoint(x: CGFloat.random(in: -3...3), y: 0)
                fountain.addChild(droplet)

                let rise = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: 20, duration: 0.5)
                let fall = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: -25, duration: 0.4)
                let fade = SKAction.fadeOut(withDuration: 0.3)
                droplet.run(SKAction.sequence([rise, fall, fade, SKAction.removeFromParent()]))
            },
            SKAction.wait(forDuration: 0.3, withRange: 0.2)
        ])
        fountain.run(SKAction.repeatForever(dropletTimer))

        addChild(fountain)
    }

    // MARK: - Decorations

    private func setupDecorations() {
        // Trees scattered around the village
        let treePositions: [CGPoint] = [
            CGPoint(x: -600, y: 350), CGPoint(x: -550, y: -350),
            CGPoint(x: 600, y: 350), CGPoint(x: 550, y: -350),
            CGPoint(x: -200, y: 500), CGPoint(x: 200, y: 500),
            CGPoint(x: -200, y: -500), CGPoint(x: 200, y: -500),
            CGPoint(x: -700, y: 0), CGPoint(x: 700, y: 0),
            CGPoint(x: 0, y: 600), CGPoint(x: 0, y: -600),
        ]

        for pos in treePositions {
            let tree = createTree(at: pos)
            addChild(tree)
        }

        // Flowers near houses
        for layout in VillageLayout.houses {
            for _ in 0..<5 {
                let flower = createFlower()
                flower.position = CGPoint(
                    x: layout.position.x + CGFloat.random(in: -80...80),
                    y: layout.position.y + CGFloat.random(in: -70...(-50))
                )
                flower.zPosition = 1
                addChild(flower)
            }
        }
    }

    private func createTree(at position: CGPoint) -> SKNode {
        let tree = SKNode()
        tree.position = position
        tree.zPosition = 3

        // Trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: 20))
        trunk.fillColor = NSColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 1.0)
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: -5)
        tree.addChild(trunk)

        // Canopy
        let canopySize = CGFloat.random(in: 18...28)
        let canopy = SKShapeNode(circleOfRadius: canopySize)
        canopy.fillColor = NSColor(red: CGFloat.random(in: 0.15...0.30),
                                   green: CGFloat.random(in: 0.45...0.65),
                                   blue: CGFloat.random(in: 0.10...0.25),
                                   alpha: 1.0)
        canopy.strokeColor = NSColor(red: 0.1, green: 0.35, blue: 0.1, alpha: 0.5)
        canopy.lineWidth = 1
        canopy.position = CGPoint(x: 0, y: 15)
        tree.addChild(canopy)

        // Gentle sway animation
        let sway = SKAction.sequence([
            SKAction.rotate(byAngle: 0.03, duration: 2.0),
            SKAction.rotate(byAngle: -0.06, duration: 4.0),
            SKAction.rotate(byAngle: 0.03, duration: 2.0),
        ])
        tree.run(SKAction.repeatForever(sway))

        return tree
    }

    private func createFlower() -> SKNode {
        let flower = SKNode()
        let colors: [NSColor] = [
            .systemRed, .systemYellow, .systemPink, .systemOrange, .white
        ]
        let color = colors.randomElement()!
        let petal = SKShapeNode(circleOfRadius: 3)
        petal.fillColor = color
        petal.strokeColor = .clear
        flower.addChild(petal)

        let center = SKShapeNode(circleOfRadius: 1.5)
        center.fillColor = .systemYellow
        center.strokeColor = .clear
        flower.addChild(center)

        return flower
    }

    // MARK: - Day/Night

    private func setupDayNightOverlay() {
        let overlay = SKSpriteNode(color: .clear, size: CGSize(width: 3000, height: 3000))
        overlay.position = .zero
        overlay.zPosition = 50
        overlay.alpha = 0
        addChild(overlay)
        dayNightOverlay = overlay
        updateDayNight()
    }

    private func updateDayNight() {
        guard let overlay = dayNightOverlay else { return }
        let hour = Calendar.current.component(.hour, from: Date())

        let (color, alpha): (NSColor, CGFloat)
        switch hour {
        case 6..<8:   (color, alpha) = (NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1), 0.1)
        case 8..<17:  (color, alpha) = (.clear, 0.0)
        case 17..<19: (color, alpha) = (NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1), 0.12)
        case 19..<22: (color, alpha) = (NSColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1), 0.25)
        default:      (color, alpha) = (NSColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1), 0.35)
        }

        overlay.color = color
        overlay.run(SKAction.fadeAlpha(to: alpha, duration: 2.0))

        // Toggle house window lights
        let isNight = hour >= 19 || hour < 6
        for (_, house) in houseNodes {
            house.setWindowLights(on: isNight)
        }

        // Schedule next update in 5 minutes
        run(SKAction.sequence([
            SKAction.wait(forDuration: 300),
            SKAction.run { [weak self] in self?.updateDayNight() }
        ]))
    }

    // MARK: - Mouse Events

    private var isDragging = false
    private var dragStartLocation: CGPoint = .zero

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStartLocation = event.location(in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        // Move camera by the delta (inverted because moving camera = moving world opposite)
        let dx = event.deltaX
        let dy = event.deltaY
        let currentScale = villageCamera.xScale
        villageCamera.position.x -= dx * currentScale
        villageCamera.position.y += dy * currentScale  // SpriteKit Y is inverted vs screen
    }

    override func mouseUp(with event: NSEvent) {
        // Only handle click if we didn't drag
        if isDragging { return }

        let location = event.location(in: self)

        // Check if clicked on a crab
        for (agentID, crab) in crabNodes {
            if crab.contains(location) || crab.frame.insetBy(dx: -10, dy: -10).contains(location) {
                Task { @MainActor in
                    appStateRef?.selectAgent(agentID)
                }
                villageCamera.focusOn(point: crab.position)
                return
            }
        }

        // Check if clicked on a house
        for (projectID, house) in houseNodes {
            if house.frame.contains(location) {
                Task { @MainActor in
                    appStateRef?.selectProject(projectID)
                }
                villageCamera.focusOn(point: house.position)
                return
            }
        }

        // Clicked on empty space — drop food and send nearest crab to eat it
        Task { @MainActor in
            appStateRef?.clearSelection()
        }
        dropFood(at: location)
    }

    // MARK: - Food System

    private func dropFood(at location: CGPoint) {
        // Max 8 food items on screen at once
        foodNodes.removeAll { $0.parent == nil }
        guard foodNodes.count < 8 else { return }

        let food = FoodNode()
        food.position = location
        food.zPosition = 12
        addChild(food)
        foodNodes.append(food)
        food.startDespawnTimer(seconds: 30)

        // Find the nearest idle/wandering crab and send it to the food
        sendNearestCrabToFood(food)
    }

    /// Send a specific crab or the nearest one to eat food
    func sendNearestCrabToFood(_ food: FoodNode, specificCrab: CrabAgentNode? = nil) {
        let crab: CrabAgentNode

        if let specific = specificCrab {
            crab = specific
        } else {
            // Find closest crab that isn't already going to food
            var bestCrab: CrabAgentNode?
            var bestDist: CGFloat = .greatestFiniteMagnitude

            for (_, c) in crabNodes {
                if c.action(forKey: "walkToFood") != nil { continue }
                let dist = hypot(c.position.x - food.position.x, c.position.y - food.position.y)
                if dist < bestDist {
                    bestDist = dist
                    bestCrab = c
                }
            }

            guard let found = bestCrab else { return }
            crab = found
        }

        // Stop current actions and walk to food
        crab.removeAction(forKey: "walking")
        crab.startWalkAnimation()
        crab.faceToward(food.position.x)

        // Walk speed: ~120 pts/sec
        let dist = hypot(crab.position.x - food.position.x, crab.position.y - food.position.y)
        let duration = max(0.3, Double(dist) / 120.0)

        let walkAction = SKAction.move(to: food.position, duration: duration)
        walkAction.timingMode = .easeInEaseOut

        crab.run(SKAction.sequence([
            walkAction,
            SKAction.run { [weak self, weak crab, weak food] in
                guard let food = food, let crab = crab else { return }
                guard !food.isBeingEaten else {
                    // Food already eaten by another crab — go back to idle
                    crab.startIdleAnimation()
                    return
                }
                // Eat it!
                food.getEaten(by: crab)
                // Happy crab celebration + thank you
                crab.celebrate()
                let thanks = VillageScene.thankYouPhrases.randomElement()!
                crab.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.5),
                    SKAction.run { crab.say(thanks, duration: 3.0) }
                ]))
                // Satisfy hunger in agent state
                if let agentState = self?.behaviorManager?.agentStates[crab.agent.id] {
                    agentState.satisfy(\.hunger, by: 0.6)
                }
                // Clean up
                self?.foodNodes.removeAll { $0 === food }
            }
        ]), withKey: "walkToFood")
    }

    // MARK: - Random Speech (food/water requests)

    private func startRandomSpeech() {
        let speechLoop = SKAction.sequence([
            SKAction.wait(forDuration: TimeInterval.random(in: 600...1200)),  // 10-20 minutes
            SKAction.run { [weak self] in
                self?.randomCrabSpeaks()
            },
        ])
        run(SKAction.repeatForever(speechLoop), withKey: "randomSpeech")
    }

    private func randomCrabSpeaks() {
        // Pick a random crab that isn't busy eating
        let available = crabNodes.values.filter { $0.action(forKey: "walkToFood") == nil }
        guard let crab = available.randomElement() else { return }

        let phrase = VillageScene.requestPhrases.randomElement()!
        crab.say(phrase, duration: 4.0)
    }

    override func scrollWheel(with event: NSEvent) {
        let dY = event.scrollingDeltaY
        let dX = event.scrollingDeltaX

        // Skip zero-delta events
        guard abs(dY) > 0.001 || abs(dX) > 0.001 else { return }

        // Modifier keys always zoom
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            villageCamera.handleZoom(delta: dY)
            return
        }

        // Trackpad has precise deltas AND a non-zero phase
        // Mouse wheel: phase is always 0 (NSEvent.Phase = [])
        // Magic Mouse also reports precise but with phase
        let isTrackpad = event.hasPreciseScrollingDeltas && (event.phase != [] || event.momentumPhase != [])

        if isTrackpad {
            // Trackpad: two-finger scroll → pan
            villageCamera.handlePan(deltaX: dX, deltaY: dY)
        } else {
            // Mouse wheel (discrete ticks or precise without phase) → zoom
            villageCamera.handleZoom(delta: dY)
        }
    }

    override func magnify(with event: NSEvent) {
        // Trackpad pinch → zoom
        villageCamera.handleMagnify(scale: event.magnification)
    }

    // MARK: - Request Handling

    /// Called when Alon approves a request from the UI
    func handleApprovedRequest(_ request: AgentRequest) {
        guard let crab = crabNodes[request.from] else { return }

        switch request.type {
        case .food:
            // Drop food near the requesting agent
            let foodPos = CGPoint(
                x: crab.position.x + CGFloat.random(in: -30...30),
                y: crab.position.y + CGFloat.random(in: 20...40)
            )
            dropFood(at: foodPos)
            behaviorManager?.handleFoodApproval(for: request.from)
        case .buildPermission:
            // Extract structure type from message and start building
            let type = extractBuildType(from: request.message)
            behaviorManager?.handleBuildApproval(for: request.from, structureType: type)
            // Actually place a structure near the agent
            placeStructure(type: type, near: crab.position, builder: request.from)
        default:
            // Generic approval — agent celebrates
            crab.celebrate()
            crab.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.run { crab.say("!תודה אלון! 🎉", duration: 3.0) }
            ]))
        }
    }

    /// Called when Alon denies a request
    func handleDeniedRequest(_ request: AgentRequest) {
        guard let crab = crabNodes[request.from] else { return }
        let sadPhrases = ["😢 חבל...", "בסדר... 😔", "אולי בפעם הבאה 🙏", "הבנתי... 😐"]
        crab.say(sadPhrases.randomElement()!, duration: 3.0)
    }

    private func extractBuildType(from message: String) -> String {
        let types = ["שלט", "ספסל", "גדר", "פנס", "גן פרחים", "גשר", "באר", "דרך", "לוח מודעות", "עמדת בדיקה"]
        for type in types {
            if message.contains(type) { return type }
        }
        return "מבנה"
    }

    /// Place a structure in the village (from build approval)
    private func placeStructure(type: String, near position: CGPoint, builder: AgentID) {
        let structurePos = CGPoint(
            x: position.x + CGFloat.random(in: -50...50),
            y: position.y + CGFloat.random(in: -30...30)
        )

        let node = StructureNode(type: type, builder: builder)
        node.position = structurePos
        node.zPosition = 8
        addChild(node)
        structureNodes.append(node)

        // Build animation on the crab
        if let crab = crabNodes[builder] {
            crab.startBuildAnimation()
            crab.run(SKAction.sequence([
                SKAction.wait(forDuration: 3.0),
                SKAction.run {
                    crab.celebrate()
                    crab.say("!בניתי \(type)! 🔨", duration: 3.0)
                }
            ]))
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "+", "=":
            villageCamera.zoomIn()
        case "-", "_":
            villageCamera.zoomOut()
        case "0":
            // Reset zoom
            villageCamera.handleMagnify(scale: 0)
            villageCamera.focusOn(point: .zero)
        default:
            super.keyDown(with: event)
        }
    }
}
