import AVFoundation
import AppKit

/// Manages all audio for Claude Village — ElevenLabs pre-generated voices + ambient sounds
class VillageAudio {
    static let shared = VillageAudio()

    // MARK: - Speech (ElevenLabs pre-generated MP3)

    private var speechPlayer: AVAudioPlayer?
    private var voicesBaseURL: URL?

    // Phrase category counts (must match generated files)
    private static let thankCount = 10
    private static let requestCount = 10
    private static let idleCount = 6

    // MARK: - Ambient Audio

    private var ambientEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var isAmbientPlaying = false

    // Bird state
    private var birdPhase: Float = 0
    private var birdTimer: Float = 0
    private var birdFreq: Float = 3200
    private var birdActive: Bool = false
    private var birdDuration: Float = 0
    private var birdNextChirp: Float = 4.0
    private var birdNoteIndex: Int = 0  // for multi-note chirps
    private var birdNoteCount: Int = 1

    // Water state
    private var waterFilter: Float = 0
    private var waterFilter2: Float = 0
    private var waterLfo: Float = 0

    // Cricket / gentle ambient state
    private var cricketPhase: Float = 0
    private var cricketTimer: Float = 0
    private var cricketActive: Bool = false
    private var cricketNextChirp: Float = 6.0

    private init() {
        setupVoicesPath()
    }

    // MARK: - Speech Setup

    private func setupVoicesPath() {
        // Find voices directory — check app bundle Resources first, then source tree
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("voices") {
            if FileManager.default.fileExists(atPath: bundlePath.path) {
                voicesBaseURL = bundlePath
                print("🔊 ElevenLabs voices found in bundle: \(bundlePath.path)")
                return
            }
        }

        // Fallback: source tree path (development mode)
        let devPath = URL(fileURLWithPath: NSString("~/קלוד עבודות/claude-village/ClaudeVillage/Resources/voices").expandingTildeInPath)
        if FileManager.default.fileExists(atPath: devPath.path) {
            voicesBaseURL = devPath
            print("🔊 ElevenLabs voices found in dev: \(devPath.path)")
            return
        }

        print("⚠️ No ElevenLabs voices found, speech will be silent")
    }

    /// Play a pre-generated ElevenLabs voice clip for an agent
    /// category: "thank", "request", or "idle"
    func speak(_ text: String, agentID: AgentID? = nil, category: String? = nil) {
        guard let baseURL = voicesBaseURL,
              let aid = agentID else { return }

        // Determine category from text if not provided
        let cat = category ?? guessCategory(from: text)

        // Pick random index within category
        let maxIndex: Int
        switch cat {
        case "thank": maxIndex = VillageAudio.thankCount
        case "request": maxIndex = VillageAudio.requestCount
        case "idle": maxIndex = VillageAudio.idleCount
        default: maxIndex = VillageAudio.idleCount
        }

        let index = Int.random(in: 0..<maxIndex)
        let filename = "\(cat)_\(index).mp3"
        let fileURL = baseURL.appendingPathComponent(aid.rawValue).appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ Voice file not found: \(fileURL.path)")
            return
        }

        do {
            speechPlayer = try AVAudioPlayer(contentsOf: fileURL)
            speechPlayer?.volume = 0.85
            speechPlayer?.play()
        } catch {
            print("⚠️ Failed to play voice: \(error)")
        }
    }

    /// Guess the phrase category from the text content
    private func guessCategory(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("תודה") || lower.contains("טעים") || lower.contains("יאמי")
            || lower.contains("מעולה") || lower.contains("טוב") || lower.contains("וואו")
            || lower.contains("שף") || lower.contains("ממממ") || lower.contains("חיים טובים") {
            return "thank"
        }
        if lower.contains("רעב") || lower.contains("אוכל") || lower.contains("דונר")
            || lower.contains("קבב") || lower.contains("לחמג׳ון") || lower.contains("באקלווה")
            || lower.contains("מנטי") || lower.contains("פידה") || lower.contains("כופתה")
            || lower.contains("צ׳אי") || lower.contains("איסקנדר") || lower.contains("צריך")
            || lower.contains("רוצה") || lower.contains("מגיע") || lower.contains("בבקשה") {
            return "request"
        }
        return "idle"
    }

    // MARK: - Ambient Sound

    func startAmbient() {
        guard !isAmbientPlaying else { return }
        isAmbientPlaying = true

        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)

        let sr: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let srf = Float(sr)

        // --- Gentle bird song ---
        let birdNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let s = self else { return noErr }
            let buf = UnsafeMutableAudioBufferListPointer(abl)[0].mData?.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                s.birdTimer += 1.0 / srf
                var sample: Float = 0

                if s.birdActive {
                    // Soft sine chirp with gentle frequency sweep (sounds like a songbird)
                    let progress = s.birdTimer / s.birdDuration
                    let sweep = s.birdFreq * (1.0 + progress * 0.3)  // slight upward sweep
                    s.birdPhase += (2.0 * .pi * sweep) / srf
                    if s.birdPhase > 2.0 * .pi { s.birdPhase -= 2.0 * .pi }

                    // Smooth envelope: sine-shaped (no harsh edges)
                    let env = sin(progress * .pi)

                    sample = sin(s.birdPhase) * env * 0.015  // very quiet

                    if s.birdTimer >= s.birdDuration {
                        s.birdNoteIndex += 1
                        if s.birdNoteIndex < s.birdNoteCount {
                            // Next note in the chirp sequence
                            s.birdTimer = 0
                            s.birdDuration = Float.random(in: 0.06...0.12)
                            s.birdFreq = s.birdFreq * Float.random(in: 0.9...1.2)  // nearby pitch
                            s.birdPhase = 0
                        } else {
                            s.birdActive = false
                            s.birdTimer = 0
                            s.birdNextChirp = Float.random(in: 3.0...10.0)
                        }
                    }
                } else {
                    if s.birdTimer >= s.birdNextChirp {
                        s.birdActive = true
                        s.birdTimer = 0
                        s.birdDuration = Float.random(in: 0.08...0.15)
                        s.birdFreq = Float.random(in: 2400...4000)
                        s.birdNoteIndex = 0
                        s.birdNoteCount = Int.random(in: 2...5)  // 2-5 note chirp
                        s.birdPhase = 0
                    }
                }

                buf?[i] = sample
            }
            return noErr
        }

        // --- Gentle water / brook ---
        let waterNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let s = self else { return noErr }
            let buf = UnsafeMutableAudioBufferListPointer(abl)[0].mData?.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                let noise = Float.random(in: -1.0...1.0)

                // Double low-pass filter for very soft water sound
                s.waterFilter = s.waterFilter * 0.96 + noise * 0.04
                s.waterFilter2 = s.waterFilter2 * 0.95 + s.waterFilter * 0.05

                // Very slow volume modulation (gentle waves)
                s.waterLfo += (2.0 * .pi * 0.08) / srf
                if s.waterLfo > 2.0 * .pi { s.waterLfo -= 2.0 * .pi }
                let wave = (sin(s.waterLfo) + 1.0) * 0.5  // 0 to 1

                let sample = s.waterFilter2 * (0.008 + wave * 0.006)
                buf?[i] = sample
            }
            return noErr
        }

        // --- Gentle cricket / night insects (very subtle) ---
        let cricketNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let s = self else { return noErr }
            let buf = UnsafeMutableAudioBufferListPointer(abl)[0].mData?.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                s.cricketTimer += 1.0 / srf
                var sample: Float = 0

                if s.cricketActive {
                    // Cricket: high-frequency pulse train
                    s.cricketPhase += (2.0 * .pi * 4800) / srf
                    if s.cricketPhase > 2.0 * .pi { s.cricketPhase -= 2.0 * .pi }

                    // Quick on-off pulsing (cricket rhythm)
                    let pulseFreq: Float = 28  // pulses per second
                    let pulsePhase = s.cricketTimer * pulseFreq
                    let pulse: Float = sin(pulsePhase * 2.0 * .pi) > 0 ? 1.0 : 0.0

                    // Overall envelope
                    let totalDur: Float = 1.5
                    let progress = s.cricketTimer / totalDur
                    let env = sin(progress * .pi)

                    sample = sin(s.cricketPhase) * pulse * env * 0.006

                    if s.cricketTimer >= totalDur {
                        s.cricketActive = false
                        s.cricketTimer = 0
                        s.cricketNextChirp = Float.random(in: 5.0...15.0)
                    }
                } else {
                    if s.cricketTimer >= s.cricketNextChirp {
                        s.cricketActive = true
                        s.cricketTimer = 0
                        s.cricketPhase = 0
                    }
                }

                buf?[i] = sample
            }
            return noErr
        }

        // Attach and connect
        engine.attach(birdNode)
        engine.attach(waterNode)
        engine.attach(cricketNode)

        engine.connect(birdNode, to: mixer, format: format)
        engine.connect(waterNode, to: mixer, format: format)
        engine.connect(cricketNode, to: mixer, format: format)
        engine.connect(mixer, to: engine.outputNode, format: nil)

        // Master volume — keep it gentle
        mixer.outputVolume = 0.8

        do {
            try engine.start()
            print("🎵 Ambient audio started")
        } catch {
            print("⚠️ Ambient audio failed: \(error)")
        }

        self.ambientEngine = engine
        self.mixerNode = mixer
    }

    func stopAmbient() {
        ambientEngine?.stop()
        isAmbientPlaying = false
    }

    func setAmbientVolume(_ volume: Float) {
        mixerNode?.outputVolume = max(0, min(1, volume))
    }
}
