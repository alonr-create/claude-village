import Foundation

/// Saves and loads village state to disk
class PersistenceManager {
    let saveDirectory: String
    let saveFilename = "village_state.json"
    private var autoSaveTimer: Timer?

    var savePath: String {
        (saveDirectory as NSString).appendingPathComponent(saveFilename)
    }

    init(directory: String? = nil) {
        if let dir = directory {
            saveDirectory = dir
        } else {
            // Default: ~/.claude-village/
            saveDirectory = NSString("~/.claude-village").expandingTildeInPath
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(
            atPath: saveDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Save state to JSON file
    func save(_ state: VillageState) {
        var stateCopy = state
        stateCopy.lastSaveDate = Date()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(stateCopy)
            try data.write(to: URL(fileURLWithPath: savePath), options: .atomic)
            print("💾 Village state saved (\(data.count) bytes)")
        } catch {
            print("⚠️ Failed to save village state: \(error)")
        }
    }

    /// Load state from JSON file
    func load() -> VillageState? {
        guard FileManager.default.fileExists(atPath: savePath) else {
            print("📂 No saved state found at \(savePath)")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: savePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(VillageState.self, from: data)
            print("📂 Village state loaded (tick: \(state.simulationTick), \(state.structures.count) structures)")
            return state
        } catch {
            print("⚠️ Failed to load village state: \(error)")
            return nil
        }
    }

    /// Start auto-saving every interval seconds
    func startAutoSave(interval: TimeInterval = 60, stateProvider: @escaping () -> VillageState) {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            let state = stateProvider()
            self?.save(state)
        }
        print("⏰ Auto-save enabled every \(Int(interval))s")
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
}
