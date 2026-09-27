import ApplicationServices
import AVFoundation
import Cocoa

enum Permissions {
    static func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func microphoneStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static func requestMicrophone(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: done)
    }

    static func openAccessibilitySettings() {
        // Zuerst Apple-Dialog (legt Flow oft erst in die Liste), danach die Pane öffnen.
        promptAccessibility()
        openPrivacyPane(anchors: ["Privacy_Accessibility"])
    }

    static func openMicrophoneSettings() {
        openPrivacyPane(anchors: ["Privacy_Microphone"])
    }

    /// Öffnet Datenschutz & Sicherheit und holt Systemeinstellungen nach vorne.
    static func openPrivacyPane(anchors: [String]) {
        let candidates: [String] = anchors.flatMap { anchor in
            [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
                "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
                "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?\(anchor)"
            ]
        } + [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        var opened = false
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                opened = true
                break
            }
        }

        if !opened {
            // Fallback über /usr/bin/open – zuverlässiger, wenn NSWorkspace die URL scheinbar „öffnet“.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [candidates[0]]
            try? process.run()
        }

        // Systemeinstellungen nach vorne holen – sonst bleibt das Fenster hinter Flow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            bringSystemSettingsForward()
        }
    }

    private static func bringSystemSettingsForward() {
        let ids = ["com.apple.systempreferences", "com.apple.Preferences"]
        for id in ids {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config)
                return
            }
        }
        // Letzter Fallback: App per Name aktivieren.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "System Settings"]
        try? process.run()
    }
}
