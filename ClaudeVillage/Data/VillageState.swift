import Foundation

/// Serialized structure placement
struct PlacedStructure: Codable, Identifiable {
    let id: UUID
    let type: String
    let position: CGPoint
    let builder: AgentID
    let buildDate: Date
}

/// Complete village state — everything needed to save/restore
struct VillageState: Codable {
    var agents: [AgentID: AgentState]
    var structures: [PlacedStructure]
    var conversationLog: [AgentMessage]
    var requests: [AgentRequest]
    var simulationTick: UInt64
    var lastSaveDate: Date
    var version: Int = 1

    init() {
        agents = [:]
        structures = []
        conversationLog = []
        requests = []
        simulationTick = 0
        lastSaveDate = Date()
    }
}
