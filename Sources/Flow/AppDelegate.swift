import Cocoa
import Combine
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state = AppState()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let hotkeys = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private let inserter = TextInserter()
    private let engine = SpeechEngine()
    private var overlay: OverlayController?
    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var job: Task<Void, Never>?
    private var listenStarted = Date()
    private var ticker: Timer?
    private var permissionTimer: Timer?
    private var resetWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var correctionLookup: Task<Void, Never>?
    private var correctionLookupKey: String?
    private var correctionGeneration = 0
    private var dictationApp: FrontApp?
    private var frontObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController(state: state)
        installEditMenu()
        setupStatusItem()
        wireState()

        hotkeys.hotkey = state.config.resolvedHotkey
        hotkeys.onHoldStart = { [weak self] in self?.beginListening(handsFree: false) }
        hotkeys.onHoldEnd = { [weak self] in
            guard let self, self.state.phase == .listening, !self.state.handsFree else { return }
            self.stopAndProcess()
        }
        hotkeys.onToggle = { [weak self] in self?.toggleHandsFree() }
        hotkeys.onEscape = { [weak self] in self?.cancel() }
        hotkeys.start()

        recorder.onLimit = { [weak self] in self?.stopAndProcess() }
        recorder.onLevel = { [weak self] level in
            guard let self, self.state.phase == .listening else { return }
            self.state.pushLevel(level)
        }
        engine.onUpdate = { [weak self] in
            guard let self else { return }
            let becameReady = !self.state.engineReady && self.engine.ready
            if self.state.engineReady != self.engine.ready { self.state.engineReady = self.engine.ready }
            if becameReady { self.refreshCorrectionModel(OpenAIKeyStore.load()) }
            if self.state.polishAvailable != self.engine.polishAvailable {
                self.state.polishAvailable = self.engine.polishAvailable
            }
            if self.state.engineStatus != self.engine.statusText { self.state.engineStatus = self.engine.statusText }
        }
        engine.start()
        observeFrontApp()
        state.rescanApps()

        state.refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            let before = self.state.axGranted
            self.state.refreshPermissions()
            if !before && self.state.axGranted {
                self.hotkeys.stop()
                self.hotkeys.start()
                self.overlay?.show()
            }
        }

        // Widget sofort sichtbar
        overlay?.show()

        if !state.config.onboarded {
            showOnboarding()
        } else if !state.hasPermissions {
            showMain(.home)
        }
    }

    /// Menüleisten-Apps haben sonst kein Menü „Bearbeiten“. Ohne den Eintrag
    /// kommt ⌘V in sicheren Textfeldern nicht an.
    private func installEditMenu() {
        guard NSApp.mainMenu == nil else { return }
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Flow ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Flow beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Bearbeiten")
        editItem.submenu = edit
        edit.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einfügen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = main
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
        ticker?.invalidate()
        permissionTimer?.invalidate()
        engine.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain(nil)
        return true
    }

    // MARK: Wiring

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        updateIcon(.idle)

        popover.behavior = .transient
        popover.animates = true
        let controller = NSHostingController(rootView: MenuBarView().environmentObject(state))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
    }

    private func wireState() {
        state.toggleRecording = { [weak self] in self?.toggleHandsFree() }
        state.openMain = { [weak self] section in self?.showMain(section) }
        state.reloadEngine = { [weak self] in self?.engine.restart() }
        state.finishOnboarding = { [weak self] in
            self?.state.config.onboarded = true
            self?.onboardingWindow?.close()
        }
        state.translateSelection = { [weak self] lang in self?.translateSelection(to: lang) }
        state.lookupCorrectionModel = { [weak self] key in self?.refreshCorrectionModel(key) }
        state.configChanged = { [weak self] old, new in self?.configChanged(from: old, to: new) }
        state.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.updateIcon(phase) }
            .store(in: &cancellables)
    }

    private func refreshCorrectionModel(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.config.correctsWithOpenAI, !trimmed.isEmpty else {
            correctionGeneration += 1
            correctionLookup?.cancel()
            correctionLookupKey = nil
            state.correctionModel = ""
            state.correctionModels = []
            return
        }
        if correctionLookupKey == trimmed, !state.correctionModel.isEmpty { return }
        correctionLookupKey = trimmed
        correctionGeneration += 1
        let generation = correctionGeneration
        let port = state.config.port
        correctionLookup?.cancel()
        correctionLookup = Task { [weak self] in
            guard let self else { return }
            do {
                let catalog = try await self.engine.correctionModel(apiKey: trimmed, port: port)
                await MainActor.run {
                    guard self.correctionGeneration == generation else { return }
                    self.state.correctionModel = catalog.model
                    self.state.correctionModels = catalog.models ?? []
                }
            } catch {
                await MainActor.run {
                    guard self.correctionGeneration == generation else { return }
                    self.correctionLookupKey = nil
                    self.state.correctionModel = ""
                    self.state.correctionModels = []
                }
            }
        }
    }

    private func observeFrontApp() {
        if let app = FrontApp.current() {
            state.frontApp = app
            state.rememberApp(app)
        }
        frontObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return }
            let raw = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let front = FrontApp(bundleID: id, name: raw.isEmpty ? id : raw)
            self.state.frontApp = front
            self.state.rememberApp(front)
        }
    }

    private func configChanged(from old: FlowConfig, to new: FlowConfig) {
        hotkeys.hotkey = new.resolvedHotkey
        if old.launchAtLogin != new.launchAtLogin {
            updateLaunch(new.launchAtLogin)
        }
        if old.modelPath != new.modelPath || old.whisperModel != new.whisperModel || old.port != new.port {
            engine.restart()
        }
    }

    // MARK: Dictation

    private func show(_ phase: Phase, resetAfter delay: TimeInterval? = nil) {
        resetWork?.cancel()
        state.phase = phase
        guard let delay else { return }
        let work = DispatchWorkItem { [weak self] in self?.state.phase = .idle }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginListening(handsFree: Bool) {
        guard !state.isBusy else { return }
        guard engine.ready else {
            show(.notice("Modell wird noch geladen…"), resetAfter: 1.8)
            return
        }
        let microphone = Permissions.microphoneStatus()
        if microphone == .notDetermined {
            Permissions.requestMicrophone { [weak self] granted in
                DispatchQueue.main.async {
                    self?.state.refreshPermissions()
                    if granted { self?.beginListening(handsFree: handsFree) }
                }
            }
            return
        }
        guard microphone == .authorized else {
            show(.failed("Mikrofon ist nicht erlaubt"), resetAfter: 2.2)
            showMain(.settings)
            return
        }
        // Ohne Bedienungshilfen: Aufnahme vom Widget geht, Einfügen wird zur Zwischenablage.
        // Die globale Taste braucht Bedienungshilfen – die prüft der HotkeyMonitor selbst.
        dictationApp = FrontApp.current()
        if let dictationApp { state.rememberApp(dictationApp) }
        engine.prewarm(port: state.config.port)
        do {
            try recorder.start()
        } catch {
            show(.failed(error.localizedDescription), resetAfter: 2.5)
            return
        }
        popover.performClose(nil)
        state.handsFree = handsFree
        state.resetLevels()
        state.elapsed = 0
        listenStarted = Date()
        show(.listening)
        if state.config.playSounds { NSSound(named: "Tink")?.play() }
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state.phase == .listening else { return }
            self.state.elapsed = Date().timeIntervalSince(self.listenStarted)
        }
    }

    private func toggleHandsFree() {
        if state.phase == .listening {
            stopAndProcess()
        } else if !state.isBusy {
            beginListening(handsFree: true)
        }
    }

    private func cancel() {
        switch state.phase {
        case .listening:
            _ = recorder.stop()
            ticker?.invalidate()
            state.handsFree = false
            show(.notice("Abgebrochen"), resetAfter: 0.9)
        case .transcribing, .polishing, .translating:
            job?.cancel()
            show(.notice("Abgebrochen"), resetAfter: 0.9)
        default:
            break
        }
    }

    private func stopAndProcess() {
        guard state.phase == .listening else { return }
        Timing.begin("---- recording stopped")
        let wav = recorder.stop()
        let duration = Date().timeIntervalSince(listenStarted)
        state.handsFree = false
        ticker?.invalidate()
        if state.config.playSounds { NSSound(named: "Pop")?.play() }
        guard let wav else {
            show(.notice("Nichts gehört"), resetAfter: 1.4)
            return
        }
        let modelAvailable = engine.polishAvailable
        let selection = state.config.commandMode && modelAvailable ? inserter.selectedText() : nil
        let front = FrontApp.current() ?? dictationApp
        if let front { state.rememberApp(front) }
        let appName = front?.name ?? inserter.frontmostAppName()
        var snapshot = state.config
        if let front { snapshot.style = state.effectiveStyle(for: front) }
        if !modelAvailable { snapshot.autoCorrect = false }
        Timing.mark("selection read (\(selection == nil ? "none" : "\(selection!.count) chars")), app=\(appName ?? "?"), style=\(snapshot.style)")
        show(.transcribing)

        job = Task { [weak self] in
            guard let self else { return }
            do {
                let raw = try await self.engine.transcribe(wav: wav, language: snapshot.language, port: snapshot.port)
                Timing.mark("whisper done (autoCorrect=\(snapshot.autoCorrect))")
                if Task.isCancelled { return }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    await MainActor.run { self.show(.notice("Nichts erkannt"), resetAfter: 1.4) }
                    return
                }

                // Nur Whisper: direkt einfügen, kein Sprachmodell.
                if !snapshot.autoCorrect && selection == nil {
                    await MainActor.run {
                        Timing.mark("main thread reached")
                        self.deliver(text: trimmed, raw: trimmed, duration: duration, app: appName, command: false)
                        self.inserter.logWhenLanded(trimmed)
                    }
                    return
                }

                // Sofort einfügen – außer bei Bearbeitungsbefehl auf Markierung.
                let earlyResult: InsertResult?
                if selection == nil {
                    earlyResult = await MainActor.run { () -> InsertResult in
                        Timing.mark("main thread reached")
                        self.show(.polishing(raw: trimmed))
                        let result = self.inserter.insert(trimmed)
                        self.inserter.logWhenLanded(trimmed)
                        return result
                    }
                } else {
                    earlyResult = nil
                    await MainActor.run { self.show(.polishing(raw: trimmed)) }
                }

                // Let the target app render the paste before the model saturates the GPU.
                if earlyResult != nil {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                Timing.mark("polish request sent")
                var polishedText = trimmed
                var polishError: String?
                do {
                    let polished = try await self.engine.polish(raw: trimmed, selection: selection, config: snapshot)
                    let clean = polished.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { polishedText = clean }
                } catch {
                    if Task.isCancelled { return }
                    polishError = error.localizedDescription
                }
                if Task.isCancelled { return }
                let final = polishedText
                let correctionError = polishError

                await MainActor.run {
                    if let early = earlyResult {
                        if final != trimmed {
                            if early.pasted {
                                // If the raw text can't be verified at the caret, keep it rather than
                                // risk a second insert; the corrected text stays in the history.
                                _ = self.inserter.replacePreviousInsert(raw: trimmed, with: final)
                            } else {
                                self.inserter.copyToClipboard(final)
                            }
                        } else if early.keptOnClipboard {
                            self.inserter.copyToClipboard(final)
                        }
                        self.finishDeliver(
                            text: final,
                            raw: trimmed,
                            duration: duration,
                            app: appName,
                            command: false,
                            pasted: early.pasted
                        )
                    } else {
                        let result = self.inserter.insert(final)
                        self.finishDeliver(
                            text: final,
                            raw: trimmed,
                            duration: duration,
                            app: appName,
                            command: true,
                            pasted: result.pasted
                        )
                    }
                    if let correctionError {
                        self.show(.notice(correctionError), resetAfter: 3.4)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { self.show(.failed(error.localizedDescription), resetAfter: 3) }
            }
        }
    }

    private func translateSelection(to languageId: String) {
        guard !state.isBusy else { return }
        guard engine.ready else {
            show(.notice("Modell wird noch geladen…"), resetAfter: 1.6)
            return
        }
        guard engine.polishAvailable else {
            let hint = state.config.correctsWithOpenAI
                ? "Übersetzen braucht einen OpenAI-Schlüssel"
                : "Übersetzen braucht das Sprachmodell"
            show(.notice(hint), resetAfter: 2.2)
            return
        }
        guard let selection = inserter.selectedText(), !selection.isEmpty else {
            show(.notice("Zuerst Text markieren"), resetAfter: 1.6)
            return
        }
        let lang = TranslateLanguage.named(languageId)
        let snapshot = state.config
        show(.translating(code: lang.id))
        state.widgetHovered = true
        state.widgetTranslateOpen = false

        job = Task { [weak self] in
            guard let self else { return }
            do {
                let translated = try await self.engine.polish(
                    raw: selection,
                    selection: selection,
                    config: snapshot,
                    targetLanguage: languageId
                )
                if Task.isCancelled { return }
                let text = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    await MainActor.run { self.show(.failed("Keine Übersetzung"), resetAfter: 2) }
                    return
                }
                await MainActor.run {
                    let result = self.inserter.insert(text)
                    self.state.addHistory(HistoryEntry(
                        id: UUID(),
                        date: Date(),
                        raw: selection,
                        text: text,
                        duration: nil,
                        app: self.inserter.frontmostAppName(),
                        wasCommand: true
                    ))
                    self.show(
                        .done(text: text, pasted: result.pasted),
                        resetAfter: result.pasted ? 1.6 : 2.8
                    )
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { self.show(.failed(error.localizedDescription), resetAfter: 3) }
            }
        }
    }

    private func finishDeliver(
        text: String,
        raw: String,
        duration: TimeInterval,
        app: String?,
        command: Bool,
        pasted: Bool
    ) {
        state.addHistory(HistoryEntry(
            id: UUID(),
            date: Date(),
            raw: raw,
            text: text,
            duration: duration,
            app: app,
            wasCommand: command
        ))
        show(.done(text: text, pasted: pasted), resetAfter: pasted ? 1.5 : 2.8)
    }

    private func deliver(text: String, raw: String, duration: TimeInterval, app: String?, command: Bool) {
        let result = inserter.insert(text)
        finishDeliver(text: text, raw: raw, duration: duration, app: app, command: command, pasted: result.pasted)
    }

    // MARK: Windows

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMain(_ section: MainSection?) {
        if let section { state.section = section }
        popover.performClose(nil)
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Flow"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 920, height: 620)
            window.contentView = NSHostingView(rootView: MainView().environmentObject(state))
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("FlowMainWindow")
            mainWindow = window
        }
        present(mainWindow)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Willkommen"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OnboardingView().environmentObject(state))
            window.delegate = self
            window.center()
            onboardingWindow = window
        }
        present(onboardingWindow)
    }

    private func present(_ window: NSWindow?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === onboardingWindow {
            if !state.config.onboarded { state.config.onboarded = true }
            onboardingWindow = nil
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let visible = [self.mainWindow, self.onboardingWindow].contains { $0?.isVisible == true }
            if !visible { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private func updateLaunch(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            show(.failed("Login-Start: \(error.localizedDescription)"), resetAfter: 3)
        }
    }

    private func updateIcon(_ phase: Phase) {
        guard let button = statusItem?.button else { return }
        let name: String
        var tint: NSColor?
        switch phase {
        case .listening:
            name = "mic.fill"
            tint = .systemRed
        case .transcribing, .polishing, .translating:
            name = "ellipsis.circle"
        default:
            name = "waveform"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Flow")
        image?.isTemplate = tint == nil
        button.image = image
        button.contentTintColor = tint
    }
}
