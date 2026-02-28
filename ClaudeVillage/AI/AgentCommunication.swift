import Foundation

/// A message between two agents
struct AgentMessage: Codable, Identifiable {
    let id: UUID
    let from: AgentID
    let to: AgentID
    let content: String
    let timestamp: Date

    init(from: AgentID, to: AgentID, content: String) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.content = content
        self.timestamp = Date()
    }
}

/// Manages agent-to-agent conversations
class CommunicationSystem {
    private(set) var conversationLog: [AgentMessage] = []

    /// Two agents have a short conversation (returns 2-4 messages)
    func generateConversation(between a: AgentState, and b: AgentState) -> [AgentMessage] {
        let agentA = AgentDefinition.find(a.agentID)
        let agentB = AgentDefinition.find(b.agentID)

        var messages: [AgentMessage] = []

        // Opening — agent A starts based on personality
        let opener = randomOpener(for: a)
        messages.append(AgentMessage(from: a.agentID, to: b.agentID, content: opener))

        // Response — agent B responds based on personality
        let response = randomResponse(for: b, to: opener)
        messages.append(AgentMessage(from: b.agentID, to: a.agentID, content: response))

        // 50% chance of a third message
        if Bool.random() {
            let followUp = randomFollowUp(for: a)
            messages.append(AgentMessage(from: a.agentID, to: b.agentID, content: followUp))

            // 50% chance of a fourth message
            if Bool.random() {
                let ending = randomEnding(for: b)
                messages.append(AgentMessage(from: b.agentID, to: a.agentID, content: ending))
            }
        }

        // Record in log
        conversationLog.append(contentsOf: messages)
        trimLog()

        // Update agent memories
        let topic = categorize(opener)
        a.memory.recentConversations.append(ConversationMemory(withAgent: b.agentID, topic: topic, time: Date()))
        b.memory.recentConversations.append(ConversationMemory(withAgent: a.agentID, topic: topic, time: Date()))
        a.memory.trim()
        b.memory.trim()

        return messages
    }

    private func randomOpener(for state: AgentState) -> String {
        switch state.agentID {
        case .eyal:
            return [
                "היי! יש לי תוכנית חדשה 📋",
                "בואו נסדר את הפרויקטים",
                "חשבתי על שיפור לתהליך העבודה",
                "יש עדכון חשוב לצוות",
                "מה המצב עם הדדליינים?",
                "צריך לארגן ישיבה 🗓️",
            ].randomElement()!
        case .yael:
            return [
                "ראיתי עיצוב מדהים! 🎨",
                "צריך לשפר את ה-UI של הכפר",
                "מה דעתכם על צבעים חדשים?",
                "הגדר הזו לא מספיק יפה...",
                "יש לי רעיון לאנימציה חדשה ✨",
                "הלוגו צריך רענון!",
            ].randomElement()!
        case .ido:
            return [
                "בדקתי את הביצועים של השרת 🔧",
                "יש בעיית אבטחה שצריך לטפל בה",
                "הדטה-בייס צריך אופטימיזציה",
                "כתבתי API חדש",
                "ה-Docker image גדול מדי...",
                "צריך לעדכן dependencies",
            ].randomElement()!
        case .roni:
            return [
                "מצאתי באג! 🐛",
                "הטסטים נכשלו שוב...",
                "בדקתי את הפיצ׳ר החדש — יש בעיות",
                "מישהו שבר את הקוד? 🤔",
                "צריך עוד טסטים למודול הזה",
                "יש regression בגרסה האחרונה",
            ].randomElement()!
        }
    }

    private func randomResponse(for state: AgentState, to opener: String) -> String {
        switch state.agentID {
        case .eyal:
            return ["מעניין, בוא נתכנן את זה", "אני אוסיף את זה ל-TODO", "טוב, צריך לתעדף", "מסכים, אני אנהל את זה"].randomElement()!
        case .yael:
            return ["כן! אני אעצב את זה", "אפשר לשפר את זה ויזואלית", "יש לי רעיון לעיצוב!", "הצבעים צריכים להיות יותר חמים"].randomElement()!
        case .ido:
            return ["אני אבדוק את הביצועים", "צריך לבדוק את האבטחה קודם", "אפשר לעשות את זה ב-backend", "אני אכתוב סקריפט לזה"].randomElement()!
        case .roni:
            return ["צריך לבדוק את זה לעומק", "אני אכתוב טסטים", "מצאתי כבר 3 בעיות!", "בוא נבדוק edge cases"].randomElement()!
        }
    }

    private func randomFollowUp(for state: AgentState) -> String {
        switch state.agentID {
        case .eyal: return ["מצוין, נתקדם!", "אני אעדכן את ה-README", "בוא נדבר על זה בישיבה"].randomElement()!
        case .yael: return ["אני אכין mockup!", "הפונט הזה לא מתאים...", "צריך padding נוסף"].randomElement()!
        case .ido: return ["אני אדפלי את זה היום", "צריך env var חדש", "אני אעשה PR"].randomElement()!
        case .roni: return ["תקנו את זה ואבדוק שוב", "אני כותבת דוח באגים", "זה fail קריטי!"].randomElement()!
        }
    }

    private func randomEnding(for state: AgentState) -> String {
        return ["👍", "סבבה!", "יאללה!", "תודה!", "מושלם 💪", "בהצלחה!"].randomElement()!
    }

    private func categorize(_ text: String) -> String {
        if text.contains("עיצוב") || text.contains("UI") || text.contains("צבע") { return "עיצוב" }
        if text.contains("באג") || text.contains("טסט") || text.contains("בדיקה") { return "QA" }
        if text.contains("שרת") || text.contains("API") || text.contains("Docker") { return "תשתיות" }
        if text.contains("תוכנית") || text.contains("פרויקט") || text.contains("ישיבה") { return "ניהול" }
        return "כללי"
    }

    private func trimLog() {
        if conversationLog.count > 100 {
            conversationLog = Array(conversationLog.suffix(100))
        }
    }
}
