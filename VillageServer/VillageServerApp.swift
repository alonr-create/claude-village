import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import VillageSimulation

// MARK: - Shared Server State

final class ServerState: @unchecked Sendable {
    let simulation = SimulationLoop()
    var wsChannels: [ObjectIdentifier: Channel] = [:]
    let lock = NSLock()
    var lastSnapshot: SimulationSnapshot?  // cached from last tick
    var ttsCache: TTSCache?  // nil if no API key configured
    var lastSpokenTexts: [String: String] = [:]  // agentID → last speech text (dedup TTS generation)

    let dataDir: String = {
        if let envDir = ProcessInfo.processInfo.environment["DATA_DIR"] {
            return envDir
        }
        return NSHomeDirectory() + "/.claude-village"
    }()

    var statePath: String { dataDir + "/village_state.json" }

    func loadStateIfExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dataDir) {
            try? fm.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
        }
        if let data = fm.contents(atPath: statePath) {
            simulation.loadState(from: data)
            print("Loaded state from \(statePath) (tick \(simulation.tick))")
        }
    }

    func saveState() {
        if let data = simulation.saveState() {
            let url = URL(fileURLWithPath: statePath)
            try? data.write(to: url, options: Data.WritingOptions.atomic)
        }
    }

    func loadWebViewer() -> String {
        // Try loading from files on disk first
        let paths = [
            "./VillageServer/public/index.html",
            "./public/index.html",
            "/app/public/index.html",
        ]
        for path in paths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content
            }
        }
        // Fallback — embedded HTML
        return WebViewerHTML.content
    }

    func broadcastSnapshot(_ snapshot: SimulationSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return }

        lock.lock()
        let channels = wsChannels
        lock.unlock()

        for (_, channel) in channels {
            var buf = channel.allocator.buffer(capacity: data.count)
            buf.writeBytes(data)
            let frame = WebSocketFrame(fin: true, opcode: .text, data: buf)
            channel.writeAndFlush(frame, promise: nil)
        }
    }

    func addWSChannel(_ channel: Channel) {
        lock.lock()
        wsChannels[ObjectIdentifier(channel)] = channel
        lock.unlock()
    }

    func removeWSChannel(_ channel: Channel) {
        lock.lock()
        wsChannels.removeValue(forKey: ObjectIdentifier(channel))
        lock.unlock()
    }
}

// MARK: - HTTP Handler

final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let state: ServerState

    init(state: ServerState) {
        self.state = state
    }

    var requestHead: HTTPRequestHead?
    var requestBody = ByteBuffer()

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            requestHead = head
            requestBody.clear()

        case .body(var body):
            requestBody.writeBuffer(&body)

        case .end:
            guard let head = requestHead else { return }
            handleRequest(context: context, head: head, body: requestBody)
        }
    }

    private func handleRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer) {
        let path = head.uri.split(separator: "?").first.map(String.init) ?? head.uri

        if head.method == .OPTIONS {
            respondCORS(context: context)
            return
        }

        switch (head.method, path) {
        case (.GET, "/"):
            respondHTML(context: context, html: state.loadWebViewer())

        case (.GET, "/api/snapshot"):
            // Return cached snapshot — don't call doTick() (that's the timer's job)
            if let snapshot = state.lastSnapshot {
                respondJSON(context: context, encodable: snapshot)
            } else {
                // First request before timer fired — generate one
                let snapshot = state.simulation.generateSnapshot()
                respondJSON(context: context, encodable: snapshot)
            }

        case (.GET, "/api/requests"):
            let pending = state.simulation.requests.filter { $0.status == "pending" }
            respondJSON(context: context, encodable: pending)

        case (.POST, let p) where p.hasPrefix("/api/requests/") && p.hasSuffix("/approve"):
            let parts = p.split(separator: "/")
            if parts.count >= 4, let uuid = UUID(uuidString: String(parts[2])) {
                state.simulation.approveRequest(uuid)
                respondJSON(context: context, json: #"{"ok":true}"#)
            } else {
                respond404(context: context)
            }

        case (.POST, let p) where p.hasPrefix("/api/requests/") && p.hasSuffix("/deny"):
            let parts = p.split(separator: "/")
            if parts.count >= 4, let uuid = UUID(uuidString: String(parts[2])) {
                state.simulation.denyRequest(uuid)
                respondJSON(context: context, json: #"{"ok":true}"#)
            } else {
                respond404(context: context)
            }

        case (.GET, let p) where p.hasPrefix("/api/tts/") && p.hasSuffix(".mp3"):
            // Serve cached TTS audio
            let filename = String(p.dropFirst("/api/tts/".count).dropLast(".mp3".count))
            if let ttsCache = state.ttsCache, let data = ttsCache.getCachedData(hash: filename) {
                respondMP3(context: context, data: data)
            } else {
                respond404(context: context)
            }

        case (.POST, "/api/presence"):
            state.simulation.pingPresence()
            respondJSON(context: context, json: #"{"ok":true}"#)

        case (.POST, "/api/connect"):
            var mutableBody = body
            if let bytes = mutableBody.readBytes(length: mutableBody.readableBytes) {
                let data = Data(bytes)
                let lastTick = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["lastTick"] as? UInt64 ?? 0
                state.simulation.pingPresence()
                if let summary = state.simulation.generateReturnSummary(lastTick: lastTick) {
                    // Pick a random agent to deliver the welcome message
                    let agents = Array(state.simulation.agents.values)
                    if let greeter = agents.randomElement() {
                        state.simulation.speak(greeter, text: "אלון חזר! \(summary) 🎉", duration: 6)
                    }
                    respondJSON(context: context, json: "{\"summary\":\"\(summary)\"}")
                } else {
                    respondJSON(context: context, json: #"{"summary":null}"#)
                }
            } else {
                respondJSON(context: context, json: #"{"summary":null}"#)
            }

        case (.POST, "/api/food"):
            var mutableBody = body
            if let bytes = mutableBody.readBytes(length: mutableBody.readableBytes) {
                let data = Data(bytes)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let x = json["x"] as? Double, let y = json["y"] as? Double {
                    state.simulation.dropFood(at: Vec2(x: x, y: y))
                    respondJSON(context: context, json: #"{"ok":true}"#)
                } else {
                    respondJSON(context: context, json: #"{"error":"bad request"}"#, status: .badRequest)
                }
            } else {
                respondJSON(context: context, json: #"{"error":"empty body"}"#, status: .badRequest)
            }

        case (.GET, "/village-ambient.mp3"):
            serveStaticFile(context: context, directory: "public", filename: "village-ambient.mp3", contentType: "audio/mpeg")

        case (.GET, let p) where p.hasPrefix("/icons/"):
            let filename = String(p.dropFirst("/icons/".count))
            guard !filename.contains("..") && !filename.contains("/") && filename.hasSuffix(".png") else {
                respond404(context: context)
                return
            }
            serveStaticFile(context: context, directory: "public/icons", filename: filename, contentType: "image/png")

        case (.GET, let p) where p.hasPrefix("/assets/"):
            // Serve Vite-built assets (JS, CSS, etc.)
            let filename = String(p.dropFirst("/assets/".count))
            guard !filename.contains("..") else {
                respond404(context: context)
                return
            }
            let ext = filename.components(separatedBy: ".").last ?? ""
            let contentTypes: [String: String] = [
                "js": "application/javascript",
                "css": "text/css",
                "png": "image/png",
                "jpg": "image/jpeg",
                "json": "application/json",
                "mp3": "audio/mpeg",
                "woff2": "font/woff2",
                "svg": "image/svg+xml",
                "wasm": "application/wasm",
            ]
            let ct = contentTypes[ext] ?? "application/octet-stream"
            serveStaticFile(context: context, directory: "public/assets", filename: filename, contentType: ct)

        default:
            respond404(context: context)
        }
    }

    private func serveStaticFile(context: ChannelHandlerContext, directory: String, filename: String, contentType: String) {
        let paths = [
            "./VillageServer/\(directory)/\(filename)",
            "./\(directory)/\(filename)",
            "/app/\(directory)/\(filename)",
        ]
        for path in paths {
            if let data = FileManager.default.contents(atPath: path) {
                var buf = context.channel.allocator.buffer(capacity: data.count)
                buf.writeBytes(data)
                let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: [
                    "Content-Type": contentType,
                    "Content-Length": "\(buf.readableBytes)",
                    "Cache-Control": "public, max-age=86400",
                    "Access-Control-Allow-Origin": "*",
                ])
                context.write(wrapOutboundOut(.head(head)), promise: nil)
                context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
                return
            }
        }
        respond404(context: context)
    }

    private func respondCORS(context: ChannelHandlerContext) {
        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
            "Content-Length": "0",
        ])
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func respondHTML(context: ChannelHandlerContext, html: String) {
        var buf = context.channel.allocator.buffer(capacity: html.utf8.count)
        buf.writeString(html)
        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: [
            "Content-Type": "text/html; charset=utf-8",
            "Content-Length": "\(buf.readableBytes)",
            "Access-Control-Allow-Origin": "*",
        ])
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func respondJSON<T: Encodable>(context: ChannelHandlerContext, encodable: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(encodable) {
            var buf = context.channel.allocator.buffer(capacity: data.count)
            buf.writeBytes(data)
            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(buf.readableBytes)",
                "Access-Control-Allow-Origin": "*",
            ])
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        }
    }

    private func respondJSON(context: ChannelHandlerContext, json: String, status: HTTPResponseStatus = .ok) {
        var buf = context.channel.allocator.buffer(capacity: json.utf8.count)
        buf.writeString(json)
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: [
            "Content-Type": "application/json; charset=utf-8",
            "Content-Length": "\(buf.readableBytes)",
            "Access-Control-Allow-Origin": "*",
        ])
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func respondMP3(context: ChannelHandlerContext, data: Data) {
        var buf = context.channel.allocator.buffer(capacity: data.count)
        buf.writeBytes(data)
        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: [
            "Content-Type": "audio/mpeg",
            "Content-Length": "\(buf.readableBytes)",
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "public, max-age=86400",
        ])
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func respond404(context: ChannelHandlerContext) {
        respondJSON(context: context, json: #"{"error":"not found"}"#, status: .notFound)
    }
}

// MARK: - WebSocket Handler

final class WebSocketHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    let state: ServerState

    init(state: ServerState) {
        self.state = state
    }

    func channelActive(context: ChannelHandlerContext) {
        state.addWSChannel(context.channel)
        print("WebSocket connected")
    }

    func channelInactive(context: ChannelHandlerContext) {
        state.removeWSChannel(context.channel)
        print("WebSocket disconnected")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)

        switch frame.opcode {
        case .ping:
            let pong = WebSocketFrame(fin: true, opcode: .pong, data: frame.unmaskedData)
            context.writeAndFlush(wrapOutboundOut(pong), promise: nil)

        case .connectionClose:
            let close = WebSocketFrame(fin: true, opcode: .connectionClose, data: context.channel.allocator.buffer(capacity: 0))
            context.writeAndFlush(wrapOutboundOut(close)).whenComplete { _ in
                context.close(promise: nil)
            }

        case .text:
            var frameData = frame.unmaskedData
            if let text = frameData.readString(length: frameData.readableBytes) {
                handleWSCommand(text, context: context)
            }

        default:
            break
        }
    }

    private func handleWSCommand(_ text: String, context: ChannelHandlerContext) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else { return }

        switch action {
        case "food":
            if let x = json["x"] as? Double, let y = json["y"] as? Double {
                state.simulation.dropFood(at: Vec2(x: x, y: y))
            }
        case "approve":
            if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr) {
                state.simulation.approveRequest(uuid)
            }
        case "deny":
            if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr) {
                state.simulation.denyRequest(uuid)
            }
        case "ping":
            // Respond with pong to keep Railway proxy alive
            var buf = context.channel.allocator.buffer(capacity: 16)
            buf.writeString(#"{"action":"pong"}"#)
            let pong = WebSocketFrame(fin: true, opcode: .text, data: buf)
            context.writeAndFlush(self.wrapOutboundOut(pong), promise: nil)
        default:
            break
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("WebSocket error: \(error)")
        context.close(promise: nil)
    }
}

// MARK: - Entry Point

@main
struct VillageServerEntry {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8420") ?? 8420
        let state = ServerState()

        state.loadStateIfExists()

        // Initialize TTS if API key is available
        if let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !apiKey.isEmpty {
            state.ttsCache = TTSCache(dataDir: state.dataDir, apiKey: apiKey)
            print("ElevenLabs TTS enabled")
        } else {
            print("No ELEVENLABS_API_KEY — TTS disabled (synthetic sounds only)")
        }

        print("Claude Village Server starting on port \(port)...")
        print("Data directory: \(state.dataDir)")

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let upgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, head in
                if head.uri == "/ws" {
                    return channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                }
                return channel.eventLoop.makeSucceededFuture(nil)
            },
            upgradePipelineHandler: { channel, _ in
                channel.pipeline.addHandler(WebSocketHandler(state: state))
            }
        )

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = HTTPHandler(state: state)
                let config: NIOHTTPServerUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { context in
                        context.pipeline.removeHandler(httpHandler, promise: nil)
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: config
                ).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }

        let serverChannel = try await bootstrap.bind(host: "0.0.0.0", port: port).get()
        print("Server listening on http://0.0.0.0:\(port)")
        print("Web viewer: http://localhost:\(port)")

        // Pre-warm TTS cache in background
        if state.ttsCache != nil {
            Task {
                await state.ttsCache?.prewarmKnownPhrases()
            }
        }

        // Simulation tick every 500ms (v2.0: 4x faster for fluid movement)
        let tickTimer = group.next().scheduleRepeatedTask(initialDelay: .milliseconds(500), delay: .milliseconds(500)) { _ in
            let snapshot = state.simulation.doTick()
            state.lastSnapshot = snapshot
            state.broadcastSnapshot(snapshot)

            // Generate TTS for new speech
            if let ttsCache = state.ttsCache {
                for agent in snapshot.agents {
                    if let speech = agent.currentSpeech {
                        let lastSpeech = state.lastSpokenTexts[agent.id]
                        if lastSpeech != speech {
                            state.lastSpokenTexts[agent.id] = speech
                            let name = agent.name
                            Task {
                                let _ = await ttsCache.generate(text: speech, agentName: name)
                            }
                        }
                    } else {
                        state.lastSpokenTexts.removeValue(forKey: agent.id)
                    }
                }
            }
        }

        // Auto-save every 60 seconds
        let saveTimer = group.next().scheduleRepeatedTask(initialDelay: .seconds(60), delay: .seconds(60)) { _ in
            state.saveState()
            print("Auto-saved state (tick \(state.simulation.tick))")
        }

        // Handle shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler {
            print("\nShutting down...")
            state.saveState()
            tickTimer.cancel()
            saveTimer.cancel()
            try? serverChannel.close().wait()
            exit(0)
        }
        signalSource.resume()

        print("Village is alive! Agents are autonomous and waiting for your commands.")
        print("Press Ctrl+C to stop.\n")

        try await serverChannel.closeFuture.get()
    }
}
