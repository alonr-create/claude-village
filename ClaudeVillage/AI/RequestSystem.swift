import Foundation

/// A request from an agent to Alon
struct AgentRequest: Codable, Identifiable {
    let id: UUID
    let from: AgentID
    let message: String
    let type: RequestType
    let timestamp: Date
    var status: RequestStatus

    init(from: AgentID, message: String, type: RequestType) {
        self.id = UUID()
        self.from = from
        self.message = message
        self.type = type
        self.timestamp = Date()
        self.status = .pending
    }

    enum RequestType: String, Codable {
        case food
        case buildPermission
        case tool
        case vacation
        case raise
        case general
    }

    enum RequestStatus: String, Codable {
        case pending
        case approved
        case denied
    }
}

/// Manages agent requests to Alon
@MainActor
class RequestSystem: ObservableObject {
    @Published var pendingRequests: [AgentRequest] = []
    @Published var historyRequests: [AgentRequest] = []

    /// Agent submits a new request
    func submitRequest(from agentID: AgentID, message: String, type: AgentRequest.RequestType) {
        let request = AgentRequest(from: agentID, message: message, type: type)
        pendingRequests.append(request)

        // Keep history bounded
        if pendingRequests.count > 20 {
            // Auto-deny oldest
            if var oldest = pendingRequests.first {
                oldest.status = .denied
                historyRequests.append(oldest)
                pendingRequests.removeFirst()
            }
        }
    }

    /// Alon approves a request
    func approve(_ requestID: UUID) -> AgentRequest? {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestID }) else { return nil }
        var request = pendingRequests.remove(at: index)
        request.status = .approved
        historyRequests.append(request)
        trimHistory()
        return request
    }

    /// Alon denies a request
    func deny(_ requestID: UUID) -> AgentRequest? {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestID }) else { return nil }
        var request = pendingRequests.remove(at: index)
        request.status = .denied
        historyRequests.append(request)
        trimHistory()
        return request
    }

    private func trimHistory() {
        if historyRequests.count > 50 {
            historyRequests = Array(historyRequests.suffix(50))
        }
    }

    /// Categorize request type from message text
    static func categorize(_ message: String) -> AgentRequest.RequestType {
        let lower = message.lowercased()
        if lower.contains("אוכל") || lower.contains("רעב") || lower.contains("דונר")
            || lower.contains("קבב") || lower.contains("לחמג׳ון") || lower.contains("באקלווה") {
            return .food
        }
        if lower.contains("בנייה") || lower.contains("לבנות") || lower.contains("גדר")
            || lower.contains("גשר") || lower.contains("ספסל") {
            return .buildPermission
        }
        if lower.contains("כלי") || lower.contains("tool") { return .tool }
        if lower.contains("חופשה") || lower.contains("vacation") { return .vacation }
        if lower.contains("העלאה") || lower.contains("שכר") { return .raise }
        return .general
    }
}
