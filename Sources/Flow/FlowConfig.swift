import Foundation

struct FlowConfig: Codable, Equatable {
    var modelPath: String
    var whisperModel: String
    /// local = Qwen auf diesem Mac, openai = Chat-API mit eigenem Schlüssel
    var polishProvider: String
    var openAIModel: String
    /// Leer = https://api.openai.com/v1. Sonst eine OpenAI-kompatible Basisadresse.
    var correctionBaseURL: String = ""
    /// chatgpt = OpenAI. custom = eigene Adresse und eigenes Modell.
    var correctionKind: String = "chatgpt"
    /// true, sobald die alte Modell-Vorgabe einmal auf „auto“ umgestellt wurde
    var didChooseModel: Bool
    var appStyles: [AppStyleProfile]
    /// Whisper-Sprache: auto / de / en
    var language: String
    /// Muttersprache für Übersetzungen (de, en, …)
    var nativeLanguage: String
    var style: String
    var instructions: String
    var dictionary: String
    var commandMode: Bool
    /// false = nur Whisper, keine Nachbearbeitung
    var autoCorrect: Bool
    var hotkey: String
    var playSounds: Bool
    /// Während der Aufnahme: off, quiet oder mute.
    var othersAudio: String
    /// Kurze Korrekturen am eingesetzten Text ins Wörterbuch übernehmen.
    var learnEdits: Bool
    var launchAtLogin: Bool
    var onboarded: Bool
    var port: Int
    /// Widget-Mitte relativ zum sichtbaren Bildschirm (0…1). nil = Standard unten mittig.
    var widgetX: Double?
    var widgetY: Double?

    static let defaultModel = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Models/Qwen3.8-27B-Uncensored-MLX/4-bit")
    static let defaultWhisper = "mlx-community/whisper-large-v3-turbo"
    static let defaultPolishProvider = "openai"
    static let defaultOpenAIModel = "gpt-4.1-mini"

    static let standard = FlowConfig(
        modelPath: defaultModel,
        whisperModel: defaultWhisper,
        polishProvider: defaultPolishProvider,
        openAIModel: "auto",
        didChooseModel: true,
        appStyles: [],
        language: "auto",
        nativeLanguage: "de",
        style: "auto",
        instructions: "",
        dictionary: "",
        commandMode: true,
        autoCorrect: true,
        hotkey: Hotkey.function.rawValue,
        playSounds: true,
        othersAudio: OthersAudio.mute.rawValue,
        learnEdits: true,
        launchAtLogin: false,
        onboarded: false,
        port: 17321,
        widgetX: nil,
        widgetY: nil
    )

    init(
        modelPath: String,
        whisperModel: String,
        polishProvider: String,
        openAIModel: String,
        didChooseModel: Bool,
        appStyles: [AppStyleProfile],
        language: String,
        nativeLanguage: String,
        style: String,
        instructions: String,
        dictionary: String,
        commandMode: Bool,
        autoCorrect: Bool,
        hotkey: String,
        playSounds: Bool,
        othersAudio: String,
        learnEdits: Bool,
        launchAtLogin: Bool,
        onboarded: Bool,
        port: Int,
        widgetX: Double?,
        widgetY: Double?
    ) {
        self.modelPath = modelPath
        self.whisperModel = whisperModel
        self.polishProvider = polishProvider
        self.openAIModel = openAIModel
        self.didChooseModel = didChooseModel
        self.appStyles = appStyles
        self.language = language
        self.nativeLanguage = nativeLanguage
        self.style = style
        self.instructions = instructions
        self.dictionary = dictionary
        self.commandMode = commandMode
        self.autoCorrect = autoCorrect
        self.hotkey = hotkey
        self.playSounds = playSounds
        self.othersAudio = othersAudio
        self.learnEdits = learnEdits
        self.launchAtLogin = launchAtLogin
        self.onboarded = onboarded
        self.port = port
        self.widgetX = widgetX
        self.widgetY = widgetY
    }

    init(from decoder: Decoder) throws {
        let d = FlowConfig.standard
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelPath = try c.decodeIfPresent(String.self, forKey: .modelPath) ?? d.modelPath
        whisperModel = try c.decodeIfPresent(String.self, forKey: .whisperModel) ?? d.whisperModel
        polishProvider = try c.decodeIfPresent(String.self, forKey: .polishProvider) ?? d.polishProvider
        openAIModel = try c.decodeIfPresent(String.self, forKey: .openAIModel) ?? d.openAIModel
        correctionBaseURL = try c.decodeIfPresent(String.self, forKey: .correctionBaseURL) ?? ""
        if let kind = try c.decodeIfPresent(String.self, forKey: .correctionKind),
           kind == "chatgpt" || kind == "custom" {
            correctionKind = kind
        } else {
            let host = URL(string: correctionBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased()
            correctionKind = (host != nil && host != "api.openai.com") ? "custom" : "chatgpt"
        }
        didChooseModel = try c.decodeIfPresent(Bool.self, forKey: .didChooseModel) ?? false
        appStyles = try c.decodeIfPresent([AppStyleProfile].self, forKey: .appStyles) ?? []
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        nativeLanguage = try c.decodeIfPresent(String.self, forKey: .nativeLanguage) ?? d.nativeLanguage
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? d.style
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? d.instructions
        dictionary = try c.decodeIfPresent(String.self, forKey: .dictionary) ?? d.dictionary
        commandMode = try c.decodeIfPresent(Bool.self, forKey: .commandMode) ?? d.commandMode
        autoCorrect = try c.decodeIfPresent(Bool.self, forKey: .autoCorrect) ?? d.autoCorrect
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? d.hotkey
        playSounds = try c.decodeIfPresent(Bool.self, forKey: .playSounds) ?? d.playSounds
        if let stored = try c.decodeIfPresent(String.self, forKey: .othersAudio),
           OthersAudio(rawValue: stored) != nil {
            othersAudio = stored
        } else {
            let muted = try c.decodeIfPresent(Bool.self, forKey: .muteOthers) ?? true
            othersAudio = (muted ? OthersAudio.mute : OthersAudio.off).rawValue
        }
        learnEdits = try c.decodeIfPresent(Bool.self, forKey: .learnEdits) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? d.port
        widgetX = try c.decodeIfPresent(Double.self, forKey: .widgetX)
        widgetY = try c.decodeIfPresent(Double.self, forKey: .widgetY)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(modelPath, forKey: .modelPath)
        try c.encode(whisperModel, forKey: .whisperModel)
        try c.encode(polishProvider, forKey: .polishProvider)
        try c.encode(openAIModel, forKey: .openAIModel)
        try c.encode(correctionBaseURL, forKey: .correctionBaseURL)
        try c.encode(correctionKind, forKey: .correctionKind)
        try c.encode(didChooseModel, forKey: .didChooseModel)
        try c.encode(appStyles, forKey: .appStyles)
        try c.encode(language, forKey: .language)
        try c.encode(nativeLanguage, forKey: .nativeLanguage)
        try c.encode(style, forKey: .style)
        try c.encode(instructions, forKey: .instructions)
        try c.encode(dictionary, forKey: .dictionary)
        try c.encode(commandMode, forKey: .commandMode)
        try c.encode(autoCorrect, forKey: .autoCorrect)
        try c.encode(hotkey, forKey: .hotkey)
        try c.encode(playSounds, forKey: .playSounds)
        try c.encode(othersAudio, forKey: .othersAudio)
        try c.encode(othersAudio != OthersAudio.off.rawValue, forKey: .muteOthers)
        try c.encode(learnEdits, forKey: .learnEdits)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(onboarded, forKey: .onboarded)
        try c.encode(port, forKey: .port)
        try c.encodeIfPresent(widgetX, forKey: .widgetX)
        try c.encodeIfPresent(widgetY, forKey: .widgetY)
    }

    private enum CodingKeys: String, CodingKey {
        case modelPath, whisperModel, polishProvider, openAIModel, correctionBaseURL, correctionKind, didChooseModel, appStyles, language, nativeLanguage, style, instructions, dictionary
        case commandMode, autoCorrect, hotkey, playSounds, muteOthers, othersAudio, learnEdits, launchAtLogin, onboarded, port, widgetX, widgetY
    }

    static var snapshotDemo: FlowConfig {
        var config = standard
        config.modelPath = ""
        config.polishProvider = defaultPolishProvider
        config.openAIModel = "auto"
        config.didChooseModel = true
        config.onboarded = true
        config.dictionary = "flow app -> Flow\nsinthex -> Sinthex"
        config.appStyles = [
            AppStyleProfile(bundleID: "com.apple.mail", name: "Mail", style: "email", suggested: "email", customized: false),
            AppStyleProfile(bundleID: "com.apple.MobileSMS", name: "Nachrichten", style: "chat", suggested: "chat", customized: false),
            AppStyleProfile(bundleID: "com.apple.Notes", name: "Notizen", style: "notes", suggested: "notes", customized: false),
            AppStyleProfile(bundleID: "com.apple.Terminal", name: "Terminal", style: "code", suggested: "code", customized: false),
            AppStyleProfile(bundleID: "com.microsoft.Word", name: "Word", style: "notes", suggested: "notes", customized: false),
            AppStyleProfile(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", style: "chat", suggested: "chat", customized: false),
        ]
        return config
    }

    static func load() -> FlowConfig {
        if SnapshotMode.isActive { return .snapshotDemo }
        guard let data = try? Data(contentsOf: SupportPaths.config) else { return .standard }
        var config = (try? JSONDecoder().decode(FlowConfig.self, from: data)) ?? .standard
        // „Lokal“ war das optionale Qwen-Modell. Fehlt es, bleibt die Korrektur bei OpenAI
        // und Whisper startet trotzdem.
        if !config.didChooseModel {
            if config.openAIModel.isEmpty || config.openAIModel == defaultOpenAIModel {
                config.openAIModel = "auto"
            }
            config.didChooseModel = true
            config.save()
        }
        if config.polishProvider == "local" {
            let present = FileManager.default.fileExists(
                atPath: (config.modelPath as NSString).appendingPathComponent("config.json")
            )
            if !present {
                config.polishProvider = defaultPolishProvider
                config.save()
            }
        }
        return config
    }

    func save() {
        if SnapshotMode.isActive { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: SupportPaths.config, options: .atomic)
    }

    var resolvedHotkey: Hotkey {
        Hotkey(rawValue: hotkey) ?? .function
    }

    var othersAudioMode: OthersAudio {
        OthersAudio(rawValue: othersAudio) ?? .mute
    }

    var correctsWithOpenAI: Bool { polishProvider == "openai" }

    static let defaultCorrectionBaseURL = "https://api.openai.com/v1"

    var resolvedCorrectionBaseURL: String {
        if correctionKind != "custom" { return Self.defaultCorrectionBaseURL }
        return correctionBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Eigenes Modell über eine OpenAI-kompatible Adresse. Der Schlüssel ist dann optional.
    var usesCustomCorrectionAPI: Bool { correctionKind == "custom" }

    func correctionConfigured(hasKey: Bool) -> Bool {
        if usesCustomCorrectionAPI {
            return correctsWithOpenAI && !resolvedCorrectionBaseURL.isEmpty
        }
        return correctsWithOpenAI && hasKey
    }
}

enum SupportPaths {
    static var directory: URL {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var config: URL { directory.appendingPathComponent("config.json") }
    static var history: URL { directory.appendingPathComponent("history.json") }
    static var models: URL {
        let url = directory.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var log: URL { directory.appendingPathComponent("engine.log") }
    static var python: URL { directory.appendingPathComponent(".venv/bin/python") }
    static var timingLog: URL { directory.appendingPathComponent("timing.log") }
    static var engineVersion: URL { directory.appendingPathComponent("engine.version") }
}

/// Millisecond timeline of the dictation → paste path, appended to timing.log.
enum Timing {
    private static var start = Date()
    private static let queue = DispatchQueue(label: "flow.timing")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func begin(_ label: String) {
        start = Date()
        mark(label)
    }

    static func mark(_ label: String) {
        let now = Date()
        let line = "\(formatter.string(from: now))  +\(Int(now.timeIntervalSince(start) * 1000))ms  \(label)\n"
        queue.async {
            let url = SupportPaths.timingLog
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var raw: String
    var text: String
    var duration: Double?
    var app: String?
    var wasCommand: Bool?

    var words: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

enum HistoryStore {
    static func load() -> [HistoryEntry] {
        if SnapshotMode.isActive { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: SupportPaths.history),
              let entries = try? decoder.decode([HistoryEntry].self, from: data) else { return [] }
        return entries
    }

    static func save(_ entries: [HistoryEntry]) {
        if SnapshotMode.isActive { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: SupportPaths.history, options: .atomic)
    }
}

struct DictionaryItem: Identifiable, Equatable {
    let id = UUID()
    var term: String
    var heardAs: String

    static func parse(_ text: String) -> [DictionaryItem] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            if let range = line.range(of: "->") {
                let left = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let right = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                guard !left.isEmpty, !right.isEmpty else { return nil }
                return DictionaryItem(term: right, heardAs: left)
            }
            return DictionaryItem(term: line, heardAs: "")
        }
    }

    static func serialize(_ items: [DictionaryItem]) -> String {
        items.map { item in
            item.heardAs.isEmpty ? item.term : "\(item.heardAs) -> \(item.term)"
        }.joined(separator: "\n")
    }
}

struct TranslateLanguage: Identifiable, Hashable {
    let id: String
    let flag: String
    var name: String { L10n.s("lang.\(id)") }

    static let all: [TranslateLanguage] = [
        .init(id: "de", flag: "🇩🇪"),
        .init(id: "en", flag: "🇬🇧"),
        .init(id: "fr", flag: "🇫🇷"),
        .init(id: "es", flag: "🇪🇸"),
        .init(id: "it", flag: "🇮🇹"),
        .init(id: "pt", flag: "🇵🇹"),
        .init(id: "nl", flag: "🇳🇱"),
        .init(id: "pl", flag: "🇵🇱"),
        .init(id: "tr", flag: "🇹🇷")
    ]

    static func named(_ id: String) -> TranslateLanguage {
        all.first { $0.id == id } ?? all[0]
    }
}
