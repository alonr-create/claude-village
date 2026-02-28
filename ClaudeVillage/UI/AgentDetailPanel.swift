import SwiftUI

struct AgentDetailPanel: View {
    let agentID: AgentID
    @ObservedObject var appState: AppState

    private var agent: AgentDefinition {
        AgentDefinition.find(agentID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with agent badge color
            HStack {
                // Crab emoji with badge color circle
                ZStack {
                    Circle()
                        .fill(Color(nsColor: agent.badgeColor))
                        .frame(width: 44, height: 44)
                    Text("🦀")
                        .font(.title2)
                }

                VStack(alignment: .leading) {
                    Text(agent.nameHebrew)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(agent.role.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button(action: { appState.clearSelection() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: agent.badgeColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Personality
            VStack(alignment: .leading, spacing: 6) {
                Text("אישיות")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("״\(agent.personality)״")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(.primary)
                    .italic()
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            // Current status
            VStack(alignment: .leading, spacing: 6) {
                Text("סטטוס")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let assignment = appState.agentAssignments[agentID] {
                    let project = ProjectDefinition.find(assignment)
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("עובד ב-\(project.nameHebrew)")
                            .font(.system(size: 13))
                    }
                } else {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("פנוי")
                            .font(.system(size: 13))
                    }
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            // Keywords this agent responds to
            VStack(alignment: .leading, spacing: 6) {
                Text("מתמחה ב:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 4) {
                    ForEach(agent.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: agent.badgeColor).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }
}

// Simple flow layout for keyword tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
