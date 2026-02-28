import Foundation

struct TodoItem: Codable {
    let content: String
    let status: String
    let activeForm: String

    var isInProgress: Bool { status == "in_progress" }
    var isCompleted: Bool { status == "completed" }
    var isPending: Bool { status == "pending" }
}
