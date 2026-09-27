import Cocoa
import SwiftUI

// Rendert die Oberfläche offscreen als PNG, ohne Bildschirmaufnahme-Rechte: Flow --snapshot <ordner>
// Liest dabei weder Verlauf, Konfiguration noch den Schlüsselbund.
enum SnapshotMode {
    static var isActive: Bool { CommandLine.arguments.contains("--snapshot") }
}

enum Snapshot {
    static func run(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let state = AppState()
        state.engineReady = true
        state.engineStatus = "Bereit"
        state.polishAvailable = true
        state.correctionModel = "gpt-6-luna"
        state.correctionModels = ["gpt-6-luna"]
        state.frontApp = FrontApp(bundleID: "com.apple.mail", name: "Mail")
        state.refreshPermissions()
        state.previewHistory(demoHistory)
        state.levels = (0..<AppState.levelCount).map { CGFloat(0.3 + 0.6 * abs(sin(Double($0) * 0.7))) }
        state.elapsed = 7

        for section in MainSection.allCases {
            state.section = section
            render(MainView().environmentObject(state), size: NSSize(width: 1100, height: 760), to: directory.appendingPathComponent("main-\(section.rawValue).png"))
        }
        state.section = .style
        render(MainView().environmentObject(state), size: NSSize(width: 1100, height: 1080), to: directory.appendingPathComponent("main-style-full.png"))
        state.section = .settings
        render(MainView().environmentObject(state), size: NSSize(width: 1100, height: 1280), to: directory.appendingPathComponent("main-settings-full.png"))
        render(
            MenuBarView().environmentObject(state).background(Color(nsColor: .windowBackgroundColor)),
            size: NSSize(width: 340, height: 560),
            to: directory.appendingPathComponent("menubar.png")
        )
        render(OnboardingView().environmentObject(state), size: NSSize(width: 640, height: 560), to: directory.appendingPathComponent("onboarding.png"))

        // Persistentes Hover-Widget
        state.phase = .idle
        state.widgetHovered = false
        render(
            OverlayView().environmentObject(state).background(Color(white: 0.85)),
            size: NSSize(width: 64, height: 48),
            to: directory.appendingPathComponent("widget-collapsed.png")
        )
        state.widgetHovered = true
        state.widgetTranslateOpen = false
        render(
            OverlayView().environmentObject(state).background(Color(white: 0.85)),
            size: NSSize(width: 228, height: 72),
            to: directory.appendingPathComponent("widget-expanded.png")
        )
        state.widgetTranslateOpen = true
        render(
            OverlayView().environmentObject(state).background(Color(white: 0.85)),
            size: NSSize(width: 236, height: 478),
            to: directory.appendingPathComponent("widget-translate.png")
        )
        state.widgetTranslateOpen = false

        let phases: [(String, Phase)] = [
            ("listening", .listening),
            ("transcribing", .transcribing),
            ("polishing", .polishing(raw: "ähm also ich wollte kurz sagen dass wir das meeting verschieben")),
            ("done-paste", .done(text: "Meeting verschieben.", pasted: true)),
            ("done-copy", .done(text: "Meeting verschieben.", pasted: false))
        ]
        for (name, phase) in phases {
            state.phase = phase
            let view = OverlayView().environmentObject(state)
                .background(Color(white: 0.85))
            render(view, size: NSSize(width: 640, height: 120), to: directory.appendingPathComponent("overlay-\(name).png"))
        }
    }

    private static var demoHistory: [HistoryEntry] {
        let now = Date()
        return [
            HistoryEntry(id: UUID(), date: now.addingTimeInterval(-180), raw: "können wir das meeting auf donnerstag zehn uhr schieben", text: "Können wir das Meeting auf Donnerstag, 10 Uhr schieben?", duration: 6, app: "Mail", wasCommand: false),
            HistoryEntry(id: UUID(), date: now.addingTimeInterval(-900), raw: "bitte get user by id um einen cache ergänzen", text: "Bitte getUserById um einen Cache ergänzen.", duration: 5, app: "Cursor", wasCommand: true),
            HistoryEntry(id: UUID(), date: now.addingTimeInterval(-2400), raw: "bin in fünf minuten da", text: "Bin in fünf Minuten da.", duration: 2, app: "Nachrichten", wasCommand: false),
        ]
    }

    private static func render<V: View>(_ view: V, size: NSSize, to url: URL) {
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}
