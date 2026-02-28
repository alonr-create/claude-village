import SwiftUI

/// Panel showing agent requests to Alon — approve or deny
struct RequestPanel: View {
    @ObservedObject var requestSystem: RequestSystem
    var onApprove: ((AgentRequest) -> Void)?
    var onDeny: ((AgentRequest) -> Void)?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Header
            HStack {
                if !requestSystem.pendingRequests.isEmpty {
                    Text("\(requestSystem.pendingRequests.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                Text("בקשות מהצוות")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)

            if requestSystem.pendingRequests.isEmpty {
                Text("אין בקשות ממתינות")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(requestSystem.pendingRequests) { request in
                            RequestRow(request: request, onApprove: {
                                if let approved = requestSystem.approve(request.id) {
                                    onApprove?(approved)
                                }
                            }, onDeny: {
                                if let denied = requestSystem.deny(request.id) {
                                    onDeny?(denied)
                                }
                            })
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            // Recent history
            if !requestSystem.historyRequests.suffix(3).isEmpty {
                Divider().background(Color.white.opacity(0.2))
                Text("היסטוריה")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                ForEach(requestSystem.historyRequests.suffix(3)) { request in
                    HStack(spacing: 6) {
                        Text(request.status == .approved ? "V" : "X")
                            .font(.system(size: 10))
                            .foregroundColor(request.status == .approved ? .green : .red)
                        Text(AgentDefinition.find(request.from).nameHebrew)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(request.message.prefix(25) + (request.message.count > 25 ? "..." : ""))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.75))
        .cornerRadius(12)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Single request row with approve/deny buttons
struct RequestRow: View {
    let request: AgentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Deny button
            Button(action: onDeny) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            // Approve button
            Button(action: onApprove) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.8))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 2) {
                // Agent name + badge
                HStack(spacing: 4) {
                    VillageIconView(request.type.iconName, size: 12, fallback: request.type.emoji)
                    Text(AgentDefinition.find(request.from).nameHebrew)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(agentColor)
                }

                // Message
                Text(request.message)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }

    private var agentColor: Color {
        let def = AgentDefinition.find(request.from)
        return Color(def.badgeColor)
    }
}

extension AgentRequest.RequestType {
    var emoji: String {
        switch self {
        case .food: return "🍖"
        case .buildPermission: return "🔨"
        case .tool: return "🔧"
        case .vacation: return "🏖️"
        case .raise: return "💰"
        case .general: return "💬"
        }
    }

    var iconName: String {
        switch self {
        case .food: return "req-food"
        case .buildPermission: return "req-build"
        case .tool: return "req-tool"
        case .vacation: return "req-vacation"
        case .raise: return "req-raise"
        case .general: return "req-general"
        }
    }
}
