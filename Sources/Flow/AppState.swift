import AVFoundation
import Cocoa
import Combine

enum Phase: Equatable {
    case idle
    case listening
    case transcribing
    case polishing(raw: String)
    case translating(code: String)
    case done(text: String, pasted: Bool)
    case failed(String)
    case notice(String)
}

enum EngineState {
    case ready
    case loading
    case error
}

enum MainSection: String, CaseIterable, Identifiable {
    case home
    case history
    case style
    case dictionary
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return L10n.s("nav.home")
        case .history: return L10n.s("nav.history")
        case .style: return L10n.s("nav.style")
        case .dictionary: return L10n.s("nav.dictionary")
        case .settings: return L10n.s("nav.settings")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .style: return "textformat"
        case .dictionary: return "character.book.closed"
        case .settings: return "gearshape"
        }
    }
}

final class AppState: ObservableObject {
    static let levelCount = 24

    @Published var phase: Phase = .idle
    /// True while a spoken command is rewriting a selection, so the widget does not show the command itself.
    @Published var rewriting = false
    @Published var levels: [CGFloat] = Array(repeating: 0, count: AppState.levelCount)
    @Published var elapsed: TimeInterval = 0
    @Published var handsFree = false
    @Published var engineReady = false
    @Published var polishAvailable = true
    @Published var correctionModel = ""
    @Published var correctionModels: [String] = []
    @Published var frontApp: FrontApp?
    @Published var engineStatus = L10n.s("engine.loadingModel")
    @Published var engineLoading = true
    @Published var micGranted = false
    @Published var axGranted = false
    @Published var widgetHovered = false
    @Published var widgetTranslateOpen = false
    @Published var widgetDragging = false
    @Published var section: MainSection = .home
    @Published var config: FlowConfig {
        didSet {
            guard config != oldValue else { return }
            config.save()
            configChanged?(oldValue, config)
        }
    }
    @Published private(set) var history: [HistoryEntry]

    var configChanged: ((FlowConfig, FlowConfig) -> Void)?
    var toggleRecording: () -> Void = {}
    var openMain: (MainSection?) -> Void = { _ in }
    var reloadEngine: () -> Void = {}
    var lookupCorrectionModel: (String) -> Void = { _ in }
    var finishOnboarding: () -> Void = {}
    var translateSelection: (String) -> Void = { _ in }

    init() {
        config = FlowConfig.load()
        history = HistoryStore.load()
    }

    var isBusy: Bool {
        switch phase {
        case .listening, .transcribing, .polishing, .translating: return true
        default: return false
        }
    }

    var engineState: EngineState {
        if engineReady { return .ready }
        return engineLoading ? .loading : .error
    }

    var modelDisplayName: String {
        let id = config.whisperModel.split(separator: "/").last.map(String.init) ?? L10n.s("model.local")
        return L10n.s("model.whisper", id)
    }

    func rememberApp(_ app: FrontApp) {
        if let index = config.appStyles.firstIndex(where: { $0.bundleID == app.bundleID }) {
            if config.appStyles[index].name != app.name {
                config.appStyles[index].name = app.name
            }
            return
        }
        let suggested = AppStyleCatalog.suggest(bundleID: app.bundleID, name: app.name)
        config.appStyles.append(
            AppStyleProfile(
                bundleID: app.bundleID,
                name: app.name,
                style: suggested,
                suggested: suggested,
                customized: false
            )
        )
        config.appStyles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func mergeInstalledApps(_ apps: [FrontApp]) {
        var next = config.appStyles
        var indexByID: [String: Int] = [:]
        for (index, profile) in next.enumerated() {
            indexByID[profile.bundleID] = index
        }
        var changed = false
        for app in apps {
            let suggested = AppStyleCatalog.suggest(bundleID: app.bundleID, name: app.name)
            if let index = indexByID[app.bundleID] {
                if next[index].name != app.name {
                    next[index].name = app.name
                    changed = true
                }
                if !next[index].customized, next[index].suggested != suggested {
                    next[index].suggested = suggested
                    next[index].style = suggested
                    changed = true
                }
            } else {
                next.append(
                    AppStyleProfile(
                        bundleID: app.bundleID,
                        name: app.name,
                        style: suggested,
                        suggested: suggested,
                        customized: false
                    )
                )
                indexByID[app.bundleID] = next.count - 1
                changed = true
            }
        }
        guard changed else { return }
        next.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        config.appStyles = next
    }

    func setAppStyle(bundleID: String, name: String, style: String) {
        rememberApp(FrontApp(bundleID: bundleID, name: name))
        guard let index = config.appStyles.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        var profile = config.appStyles[index]
        profile.style = style
        profile.customized = style != profile.suggested
        guard config.appStyles[index] != profile else { return }
        config.appStyles[index] = profile
    }

    func effectiveStyle(for app: FrontApp) -> String {
        if let profile = config.appStyles.first(where: { $0.bundleID == app.bundleID }) {
            return profile.effectiveStyle
        }
        return AppStyleCatalog.suggest(bundleID: app.bundleID, name: app.name)
    }

    func previewHistory(_ entries: [HistoryEntry]) {
        guard SnapshotMode.isActive else { return }
        history = entries
    }

    func rescanApps() {
        if SnapshotMode.isActive { return }
        let running = FrontApp.running()
        DispatchQueue.global(qos: .utility).async {
            let installed = AppStyleCatalog.unify(AppStyleCatalog.installedApps() + running)
            DispatchQueue.main.async { [weak self] in
                self?.mergeInstalledApps(installed)
            }
        }
    }

    var hasPermissions: Bool { micGranted && axGranted }

    func pushLevel(_ value: CGFloat) {
        var next = levels
        next.removeFirst()
        next.append(value)
        levels = next
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: AppState.levelCount)
    }

    func refreshPermissions() {
        let mic = Permissions.microphoneStatus() == .authorized
        let ax = Permissions.accessibilityGranted()
        if mic != micGranted { micGranted = mic }
        if ax != axGranted { axGranted = ax }
    }

    func requestMicrophone() {
        if Permissions.microphoneStatus() == .notDetermined {
            Permissions.requestMicrophone { [weak self] _ in
                DispatchQueue.main.async { self?.refreshPermissions() }
            }
        } else {
            Permissions.openMicrophoneSettings()
        }
    }

    func openAccessibility() {
        Permissions.openAccessibilitySettings()
    }

    func addHistory(_ entry: HistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > 500 { history = Array(history.prefix(500)) }
        HistoryStore.save(history)
    }

    func deleteHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        HistoryStore.save(history)
    }

    func clearHistory() {
        history.removeAll()
        HistoryStore.save(history)
    }

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    var totalWords: Int { history.reduce(0) { $0 + $1.words } }

    var todayCount: Int {
        history.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    // Tippgeschwindigkeit von 40 Wörtern pro Minute als Vergleichsbasis.
    var minutesSaved: Double {
        let typing = Double(totalWords) / 40
        let speaking = history.compactMap(\.duration).reduce(0, +) / 60
        return max(0, typing - speaking)
    }

    var speakingWPM: Int {
        let timed = history.filter { ($0.duration ?? 0) > 1 }
        let seconds = timed.compactMap(\.duration).reduce(0, +)
        guard seconds > 0 else { return 0 }
        let words = timed.reduce(0) { $0 + $1.words }
        return Int((Double(words) / (seconds / 60)).rounded())
    }
}
