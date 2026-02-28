import Foundation

class AgentScheduler {
    private let todoProvider = TodoDataProvider()
    private let sessionProvider = SessionDataProvider()
    private let projectScanner = ProjectScanner()

    struct SchedulerResult {
        var agentAssignments: [AgentID: ProjectID]
        var projectStatuses: [ProjectID: ProjectStatus]
        var activeTodos: [String: [TodoItem]]
        var activeProjects: Set<ProjectID>
    }

    func evaluate() -> SchedulerResult {
        // 1. Get all todos
        let allTodos = todoProvider.scan()
        let inProgress = todoProvider.inProgressTasks()

        // 2. Get recent sessions
        let sessions = sessionProvider.scanRecentSessions(limit: 10)

        // 3. Scan projects
        var statuses = projectScanner.scanAll()

        // 4. Determine active projects
        var activeProjects = Set<ProjectID>()

        // From recent sessions (last hour)
        let oneHourAgo = Date().addingTimeInterval(-3600)
        for session in sessions {
            if session.lastActivity > oneHourAgo, let projectID = session.projectID {
                activeProjects.insert(projectID)
            }
        }

        // 5. Assign agents based on in-progress tasks
        var assignments: [AgentID: ProjectID] = [:]
        var assignedAgents = Set<AgentID>()

        for (sessionID, task) in inProgress {
            // Try to find which project this session belongs to
            let session = sessions.first(where: { $0.sessionID.hasPrefix(sessionID.prefix(8)) })
            guard let projectID = session?.projectID ?? guessProject(for: sessionID, sessions: sessions) else { continue }

            activeProjects.insert(projectID)

            // Determine which agent should handle this task
            let agentID = AgentDefinition.assignRole(for: task.content + " " + task.activeForm)
            if !assignedAgents.contains(agentID) {
                assignments[agentID] = projectID
                assignedAgents.insert(agentID)
            }
        }

        // 6. Assign unassigned agents to random active projects (or idle)
        for agent in AgentDefinition.all {
            if !assignedAgents.contains(agent.id), let randomActive = activeProjects.randomElement() {
                assignments[agent.id] = randomActive
            }
        }

        // 7. Update active task counts in project statuses
        for (sessionID, items) in allTodos {
            let session = sessions.first(where: { $0.sessionID.hasPrefix(sessionID.prefix(8)) })
            if let projectID = session?.projectID {
                let activeCount = items.filter { $0.isInProgress }.count
                statuses[projectID]?.activeTaskCount += activeCount
            }
        }

        return SchedulerResult(
            agentAssignments: assignments,
            projectStatuses: statuses,
            activeTodos: allTodos,
            activeProjects: activeProjects
        )
    }

    private func guessProject(for sessionID: String, sessions: [SessionSummary]) -> ProjectID? {
        // Try to find the closest matching session
        return sessions.first?.projectID
    }
}
