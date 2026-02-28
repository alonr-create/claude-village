import SwiftUI

struct StatusBar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // App title
            HStack(spacing: 8) {
                VillageIconView("crab", size: 24, fallback: "🦀")
                Text("Claude Village")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Stats
            HStack(spacing: 12) {
                StatBadge(iconName: "house", fallback: "🏠", count: 6, label: "בתים")
                StatBadge(iconName: "crab", fallback: "🦀", count: 4, label: "סוכנים")

                let activeTasks = appState.activeTodos.values.flatMap { $0 }.filter { $0.isInProgress }.count
                StatBadge(iconName: "lightning", fallback: "⚡", count: activeTasks, label: "משימות")
            }

            // Mobile URL
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(appState.webServer.localURL, forType: .string)
            }) {
                HStack(spacing: 4) {
                    VillageIconView("mobile", size: 14, fallback: "📱")
                    Text(appState.webServer.localURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("לחץ להעתקת כתובת הנייד")

            // Time indicator
            HStack(spacing: 4) {
                let period = DayNightHelper.currentPeriod()
                VillageIconView(periodIconName(period), size: 16, fallback: periodEmoji(period))
                Text(periodText(period))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func periodIconName(_ period: DayPeriod) -> String {
        switch period {
        case .dawn:    return "dawn"
        case .day:     return "day"
        case .sunset:  return "sunset"
        case .evening: return "evening"
        case .night:   return "night"
        }
    }

    private func periodEmoji(_ period: DayPeriod) -> String {
        switch period {
        case .dawn:    return "🌅"
        case .day:     return "☀️"
        case .sunset:  return "🌇"
        case .evening: return "🌆"
        case .night:   return "🌙"
        }
    }

    private func periodText(_ period: DayPeriod) -> String {
        switch period {
        case .dawn:    return "שחר"
        case .day:     return "יום"
        case .sunset:  return "שקיעה"
        case .evening: return "ערב"
        case .night:   return "לילה"
        }
    }
}

struct StatBadge: View {
    let iconName: String
    let fallback: String
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            VillageIconView(iconName, size: 14, fallback: fallback)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }
}
