import Foundation

class TodoDataProvider {
    private let todosPath: String
    private var cache: [String: (date: Date, items: [TodoItem])] = [:]

    init() {
        todosPath = NSHomeDirectory() + "/.claude/todos"
    }

    /// Scan all todo files and return active ones grouped by session ID
    func scan() -> [String: [TodoItem]] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: todosPath) else { return [:] }

        var result: [String: [TodoItem]] = [:]

        for file in files where file.hasSuffix(".json") {
            let fullPath = todosPath + "/" + file
            let sessionID = file.replacingOccurrences(of: ".json", with: "")

            // Check cache
            if let cached = cache[file],
               let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let modDate = attrs[.modificationDate] as? Date,
               cached.date >= modDate {
                if !cached.items.isEmpty {
                    result[sessionID] = cached.items
                }
                continue
            }

            // Parse file
            guard let data = fm.contents(atPath: fullPath) else { continue }
            guard let items = try? JSONDecoder().decode([TodoItem].self, from: data) else { continue }

            let modDate = (try? fm.attributesOfItem(atPath: fullPath))?[.modificationDate] as? Date ?? Date()
            cache[file] = (date: modDate, items: items)

            if !items.isEmpty {
                result[sessionID] = items
            }
        }

        return result
    }

    /// Get all in-progress tasks across all sessions
    func inProgressTasks() -> [(sessionID: String, task: TodoItem)] {
        let allTodos = scan()
        var tasks: [(String, TodoItem)] = []
        for (session, items) in allTodos {
            for item in items where item.isInProgress {
                tasks.append((session, item))
            }
        }
        return tasks
    }
}
