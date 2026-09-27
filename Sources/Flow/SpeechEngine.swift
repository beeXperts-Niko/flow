import Foundation

struct HealthBody: Codable {
    var ready: Bool
    var error: String?
    var model: String?
    var polish: Bool?
    var polishError: String?
}

struct TextBody: Codable {
    var text: String
    var language: String?
}

struct ErrorBody: Codable {
    var error: String
}

struct CorrectionModelBody: Codable {
    var model: String
    var models: [String]?
}

struct CorrectionModelRequest: Encodable {
    var apiKey: String
}

struct PolishBody: Encodable {
    var raw: String
    var selection: String?
    var style: String
    var instructions: String
    var dictionary: String
    var targetLanguage: String?
    var provider: String
    var apiKey: String?
    var openAIModel: String?
}

enum EngineError: LocalizedError {
    case message(String)
    case missingPython

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .missingPython: return "Die lokale Engine ist nicht installiert."
        }
    }
}

final class SpeechEngine {
    private(set) var ready = false
    /// Correction backend ready; false means Whisper-only (no correction, no translation).
    private(set) var polishAvailable = false
    private(set) var statusText = "Whisper wird geladen…"
    var onUpdate: (() -> Void)?

    private var process: Process?
    private var setupProcess: Process?
    private var logHandle: FileHandle?
    private var pollTimer: Timer?
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 240
        return URLSession(configuration: configuration)
    }()

    func start() {
        guard setupProcess == nil else { return }
        if let bundle = bundledEngine, needsSetup(bundle) {
            runSetup(bundle)
            return
        }
        if process == nil, healthNow() == nil {
            launch()
        }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func restart() {
        shutdown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.launch()
            self?.poll()
        }
    }

    func shutdown() {
        pollTimer?.invalidate()
        pollTimer = nil
        let port = FlowConfig.load().port
        var request = URLRequest(url: endpoint("/shutdown", port: port))
        request.httpMethod = "POST"
        request.httpBody = Data()
        URLSession.shared.dataTask(with: request).resume()
        process?.terminate()
        process = nil
        ready = false
    }

    /// Startet einen Whisper-Durchlauf, ohne auf das Ergebnis zu warten.
    /// Läuft parallel zur Aufnahme, damit der erste Satz nach einer Pause nicht das Nachladen abwartet.
    func prewarm(port: Int) {
        var request = URLRequest(url: endpoint("/warmup", port: port))
        request.httpMethod = "POST"
        request.httpBody = Data()
        session.dataTask(with: request).resume()
    }

    func transcribe(wav: Data, language: String, port: Int) async throws -> String {
        var components = URLComponents(url: endpoint("/transcribe", port: port), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "language", value: language)]
        var request = URLRequest(url: components?.url ?? endpoint("/transcribe", port: port))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.upload(for: request, from: wav)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(TextBody.self, from: data).text
    }

    func polish(raw: String, selection: String?, config: FlowConfig, targetLanguage: String? = nil) async throws -> String {
        var request = URLRequest(url: endpoint("/polish", port: config.port))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let openAI = config.correctsWithOpenAI
        let storedKey = openAI ? OpenAIKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let body = PolishBody(
            raw: raw,
            selection: selection,
            style: config.style,
            instructions: config.instructions,
            dictionary: config.dictionary,
            targetLanguage: targetLanguage,
            provider: config.polishProvider,
            apiKey: storedKey.isEmpty ? nil : storedKey,
            openAIModel: openAI ? config.openAIModel : nil
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(TextBody.self, from: data).text
    }

    func correctionModel(apiKey: String, port: Int) async throws -> CorrectionModelBody {
        var request = URLRequest(url: endpoint("/correction-model", port: port))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CorrectionModelRequest(apiKey: apiKey))
        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(CorrectionModelBody.self, from: data)
    }

    // MARK: First-run setup

    private struct BundledEngine {
        let source: URL
        let script: URL
        let version: String
    }

    /// Engine sources shipped inside the app (packaged builds only).
    private var bundledEngine: BundledEngine? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let source = resources.appendingPathComponent("engine")
        let script = resources.appendingPathComponent("setup_engine.sh")
        let versionFile = resources.appendingPathComponent("engine.version")
        guard FileManager.default.fileExists(atPath: source.path),
              FileManager.default.fileExists(atPath: script.path),
              let version = try? String(contentsOf: versionFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty else { return nil }
        return BundledEngine(source: source, script: script, version: version)
    }

    private func needsSetup(_ bundle: BundledEngine) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: SupportPaths.python.path) else { return true }
        let installed = (try? String(contentsOf: SupportPaths.engineVersion, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return installed != bundle.version
    }

    private func runSetup(_ bundle: BundledEngine) {
        // An engine from the previous version may still be running and hold the port.
        if healthNow() != nil {
            shutdown()
        }
        let logURL = SupportPaths.log
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try? FileHandle(forWritingTo: logURL)
        _ = try? handle?.seekToEnd()

        let setup = Process()
        setup.executableURL = URL(fileURLWithPath: "/bin/bash")
        setup.arguments = [bundle.script.path, bundle.source.path, SupportPaths.directory.path, bundle.version]
        setup.standardOutput = handle
        setup.standardError = handle
        setup.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setupProcess = nil
                try? handle?.close()
                if finished.terminationStatus == 0 {
                    self.start()
                } else {
                    self.statusText = "Einrichtung fehlgeschlagen – Protokoll in den Einstellungen"
                    self.onUpdate?()
                }
            }
        }
        do {
            try setup.run()
            setupProcess = setup
            ready = false
            statusText = "Engine wird eingerichtet… (einmalig, einige Minuten)"
        } catch {
            statusText = "Einrichtung fehlgeschlagen: \(error.localizedDescription)"
        }
        onUpdate?()
    }

    private func launch() {
        guard setupProcess == nil else { return }
        let python = SupportPaths.python
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            statusText = "Engine fehlt"
            onUpdate?()
            return
        }
        let logURL = SupportPaths.log
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        _ = try? handle.seekToEnd()
        logHandle = handle

        let process = Process()
        process.executableURL = python
        process.arguments = ["-u", "-m", "flow_engine"]
        process.currentDirectoryURL = SupportPaths.directory
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        environment["FLOW_SUPPORT"] = SupportPaths.directory.path
        environment["HF_HOME"] = SupportPaths.models.path
        environment["HF_HUB_CACHE"] = SupportPaths.models.appendingPathComponent("hub").path
        environment["HUGGINGFACE_HUB_CACHE"] = SupportPaths.models.appendingPathComponent("hub").path
        process.environment = environment
        process.standardOutput = handle
        process.standardError = handle
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.process != nil {
                    self.ready = false
                    self.statusText = "Engine beendet"
                    self.onUpdate?()
                }
            }
        }
        do {
            try process.run()
            self.process = process
            statusText = "Whisper wird geladen…"
            ready = false
            onUpdate?()
        } catch {
            statusText = error.localizedDescription
            onUpdate?()
        }
    }

    private func poll() {
        let port = FlowConfig.load().port
        let request = URLRequest(url: endpoint("/health", port: port), timeoutInterval: 0.8)
        session.dataTask(with: request) { [weak self] data, _, _ in
            let health = data.flatMap { try? JSONDecoder().decode(HealthBody.self, from: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                if let health {
                    let config = FlowConfig.load()
                    let hasKey = !OpenAIKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    self.ready = health.ready
                    self.polishAvailable = health.ready && config.correctsWithOpenAI && hasKey
                    if let error = health.error, !health.ready {
                        self.statusText = error
                    } else if !health.ready {
                        self.statusText = "Whisper wird geladen…"
                    } else if config.correctsWithOpenAI && !hasKey {
                        self.statusText = "Bereit · Korrektur braucht noch den API-Schlüssel"
                    } else {
                        self.statusText = "Bereit"
                    }
                } else if self.process == nil {
                    self.ready = false
                    self.statusText = "Engine fehlt"
                }
                self.onUpdate?()
            }
        }.resume()
    }

    private func healthNow() -> HealthBody? {
        let port = FlowConfig.load().port
        let semaphore = DispatchSemaphore(value: 0)
        var health: HealthBody?
        let request = URLRequest(url: endpoint("/health", port: port), timeoutInterval: 0.4)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            health = data.flatMap { try? JSONDecoder().decode(HealthBody.self, from: $0) }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 0.5)
        return health
    }

    private func endpoint(_ path: String, port: Int) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(path)")!
    }

    private func validate(data: Data, response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "Engine-Fehler \(status)"
            throw EngineError.message(message)
        }
    }
}
