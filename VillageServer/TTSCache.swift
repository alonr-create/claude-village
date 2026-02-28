import Foundation
import VillageSimulation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Manages ElevenLabs TTS generation with filesystem caching
final class TTSCache: @unchecked Sendable {
    let cacheDir: String
    let apiKey: String
    let lock = NSLock()
    var inFlight: Set<String> = []  // dedup concurrent requests

    // ElevenLabs voice IDs per agent
    // Using voices with eleven_v3 model (best Hebrew support)
    let voiceMap: [String: String] = [
        "אייל": "onwK4e9ZLuTAKqWW03F9",  // Daniel — steady, mature male (product manager)
        "עידו": "pNInz6obpgDQGcFmaJgB",  // Adam — firm, direct male (backend dev)
        "יעל": "pFZP5JQG7iQjIQuC4Bku",   // Lily — velvety, artistic female (designer)
        "רוני": "FGY2WhTYpPnrIDTdsKH5",   // Laura — sassy, quirky female (QA tester)
    ]

    init(dataDir: String, apiKey: String) {
        self.cacheDir = dataDir + "/tts_cache"
        self.apiKey = apiKey
        let fm = FileManager.default

        // v3.0 migration: clear old cache (generated with eleven_multilingual_v2)
        // The marker file indicates cache was generated with eleven_v3
        let markerPath = dataDir + "/tts_v3_marker"
        if fm.fileExists(atPath: cacheDir) && !fm.fileExists(atPath: markerPath) {
            print("TTS: Clearing old cache (migrating to eleven_v3 model)...")
            try? fm.removeItem(atPath: cacheDir)
        }

        // Create cache dir
        if !fm.fileExists(atPath: cacheDir) {
            try? fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        }

        // Write v3 marker
        fm.createFile(atPath: markerPath, contents: "eleven_v3".data(using: .utf8))

        print("TTS cache directory: \(cacheDir)")
    }

    // MARK: - Hash

    /// FNV-1a hash of text + agent name → hex string
    func hashKey(text: String, agentName: String) -> String {
        let input = stripEmoji(text) + "|" + agentName
        var hash: UInt32 = 2166136261
        for byte in input.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return String(hash, radix: 16)
    }

    // MARK: - Cache Lookup

    func cachedFilePath(hash: String) -> String {
        return cacheDir + "/" + hash + ".mp3"
    }

    func isCached(hash: String) -> Bool {
        return FileManager.default.fileExists(atPath: cachedFilePath(hash: hash))
    }

    func getCachedData(hash: String) -> Data? {
        let path = cachedFilePath(hash: hash)
        return FileManager.default.contents(atPath: path)
    }

    // MARK: - Generate TTS

    /// Generate TTS audio for text, returns hash on success
    func generate(text: String, agentName: String) async -> String? {
        let cleanText = stripEmoji(text)
        guard !cleanText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let hash = hashKey(text: text, agentName: agentName)

        // Already cached?
        if isCached(hash: hash) { return hash }

        // Already generating?
        lock.lock()
        if inFlight.contains(hash) {
            lock.unlock()
            return nil
        }
        inFlight.insert(hash)
        lock.unlock()

        defer {
            lock.lock()
            inFlight.remove(hash)
            lock.unlock()
        }

        // Get voice ID
        let voiceID = voiceMap[agentName] ?? "21m00Tcm4TlvDq8ikWAM" // fallback to Rachel

        // Call ElevenLabs API
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": cleanText,
            "model_id": "eleven_v3",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.3,
                "use_speaker_boost": true,
            ]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            if httpResponse.statusCode == 200 && data.count > 1000 {
                // Save to cache
                let filePath = cachedFilePath(hash: hash)
                let fileURL = URL(fileURLWithPath: filePath)
                try data.write(to: fileURL, options: .atomic)
                print("TTS cached: \"\(cleanText.prefix(30))\" → \(hash).mp3 (\(data.count) bytes)")
                return hash
            } else {
                let errorText = String(data: data.prefix(200), encoding: .utf8) ?? "unknown"
                print("TTS API error \(httpResponse.statusCode): \(errorText)")
                return nil
            }
        } catch {
            print("TTS network error: \(error)")
            return nil
        }
    }

    // MARK: - Pre-warm

    /// Pre-generate TTS for all known conversation templates and phrases
    func prewarmKnownPhrases() async {
        print("TTS pre-warming cache...")
        var phrases: [(text: String, agent: String)] = []

        // Conversation templates
        for (_, lines) in SimulationLoop.conversationTemplates {
            for (agentID, text) in lines {
                let name = agentName(for: agentID)
                phrases.append((text, name))
            }
        }

        // Conversation openers
        for (agentID, texts) in SimulationLoop.conversationOpeners {
            let name = agentName(for: agentID)
            for text in texts {
                phrases.append((text, name))
            }
        }

        // Alon callouts
        for (agentID, texts) in SimulationLoop.alonCallouts {
            let name = agentName(for: agentID)
            for text in texts {
                phrases.append((text, name))
            }
        }

        // Eating thanks
        let thanks = ["!וואו! דונר! 😍", "!באקלווה! חיים טובים 🍬", "!קבב! הכי טעים 🍖", "!תודה אלון! יאמי 😋"]
        for t in thanks {
            for name in ["אייל", "עידו", "יעל", "רוני"] {
                phrases.append((t, name))
            }
        }

        // Explore chatter
        let chatter = ["מה קורה פה?", "הכל שקט...", "☕ הפסקת צ׳אי", "נוף יפה! 🏡", "הכפר גדל! 🌱"]
        for t in chatter {
            for name in ["אייל", "עידו", "יעל", "רוני"] {
                phrases.append((t, name))
            }
        }

        // Food alert
        phrases.append(("!אוכל! בואו 🥙", "אייל"))
        phrases.append(("!אוכל! בואו 🥙", "עידו"))
        phrases.append(("!אוכל! בואו 🥙", "יעל"))
        phrases.append(("!אוכל! בואו 🥙", "רוני"))

        // Approval/denial responses
        let approvals = ["!תודה אלון! 🎉", "!יש! אלון המלך 👑", "!מעולה! מתחיל לעבוד 💪"]
        let denials = ["😢 חבל...", "בסדר... 😔", "אולי בפעם הבאה 🙁"]
        for t in approvals + denials {
            for name in ["אייל", "עידו", "יעל", "רוני"] {
                phrases.append((t, name))
            }
        }

        // Count cached vs uncached
        var cached = 0
        var toGenerate: [(text: String, agent: String)] = []
        for p in phrases {
            let hash = hashKey(text: p.text, agentName: p.agent)
            if isCached(hash: hash) {
                cached += 1
            } else {
                toGenerate.append(p)
            }
        }
        print("TTS pre-warm: \(cached) already cached, \(toGenerate.count) to generate")

        // Generate in batches (don't overwhelm the API)
        for (i, p) in toGenerate.enumerated() {
            let _ = await generate(text: p.text, agentName: p.agent)
            if (i + 1) % 10 == 0 {
                print("TTS pre-warm: \(i + 1)/\(toGenerate.count) generated")
            }
            // Small delay between requests
            try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        }
        print("TTS pre-warm complete! Total cached: \(cached + toGenerate.count)")
    }

    // MARK: - Helpers

    private func agentName(for id: SimAgentID) -> String {
        switch id {
        case .eyal: return "אייל"
        case .yael: return "יעל"
        case .ido: return "עידו"
        case .roni: return "רוני"
        }
    }

    private func stripEmoji(_ text: String) -> String {
        return String(text.unicodeScalars.filter { scalar in
            // Keep non-emoji characters
            !(scalar.properties.isEmoji && scalar.value > 0x23F)
        })
    }
}
