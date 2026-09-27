import AppKit

struct FrontApp: Equatable {
    var bundleID: String
    var name: String

    static func current() -> FrontApp? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else { return nil }
        return FrontApp(bundleID: id, name: displayName(app.localizedName, fallback: id))
    }

    static func running() -> [FrontApp] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,
                  let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return nil }
            return FrontApp(bundleID: id, name: displayName(app.localizedName, fallback: id))
        }
    }

    private static func displayName(_ raw: String?, fallback: String) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct AppStyleProfile: Codable, Equatable, Identifiable {
    var bundleID: String
    var name: String
    var style: String
    var suggested: String
    var customized: Bool

    var id: String { bundleID }

    var effectiveStyle: String { customized ? style : suggested }
}

enum AppStyleCatalog {
    static func suggest(bundleID: String, name: String) -> String {
        let id = bundleID.lowercased()
        let title = name.lowercased()
        if matches(id, title, bundles: codeBundles, names: codeNames) { return "code" }
        if matches(id, title, bundles: emailBundles, names: emailNames) { return "email" }
        if matches(id, title, bundles: chatBundles, names: chatNames) { return "chat" }
        if matches(id, title, bundles: noteBundles, names: noteNames) { return "notes" }
        return "auto"
    }

    static func installedApps() -> [FrontApp] {
        let fileManager = FileManager.default
        var roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        roots.append(contentsOf: extraRoots(in: roots, fileManager: fileManager))

        var seen = Set<String>()
        var apps: [FrontApp] = []
        for root in roots {
            guard let items = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in items where url.pathExtension == "app" {
                guard let app = frontApp(at: url), seen.insert(app.bundleID).inserted else { continue }
                apps.append(app)
            }
        }
        return apps
    }

    static func unify(_ apps: [FrontApp]) -> [FrontApp] {
        var seen = Set<String>()
        var unique: [FrontApp] = []
        for app in apps where seen.insert(app.bundleID).inserted {
            unique.append(app)
        }
        return unique
    }

    private static func extraRoots(in roots: [URL], fileManager: FileManager) -> [URL] {
        var nested: [URL] = []
        for root in roots {
            guard let items = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in items {
                let directory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if directory, url.pathExtension != "app" {
                    nested.append(url)
                }
            }
        }
        return nested
    }

    private static func frontApp(at url: URL) -> FrontApp? {
        guard let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier,
              id != Bundle.main.bundleIdentifier,
              !id.lowercased().contains("helper") else { return nil }
        let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallback = url.deletingPathExtension().lastPathComponent
        let raw = (display?.isEmpty == false ? display : nil) ?? (bundleName?.isEmpty == false ? bundleName : nil) ?? fallback
        return FrontApp(bundleID: id, name: raw)
    }

    private static func matches(_ id: String, _ name: String, bundles: [String], names: [String]) -> Bool {
        if bundles.contains(where: { id == $0 || id.hasPrefix($0) }) { return true }
        let tokens = Set(name.split { !$0.isLetter && !$0.isNumber }.map { String($0) })
        return names.contains { needle in
            if needle.contains(" ") { return name.contains(needle) }
            return tokens.contains(needle)
        }
    }

    private static let codeBundles = [
        "com.apple.dt.xcode",
        "com.microsoft.vscode",
        "com.todesktop.",
        "com.cursor.",
        "dev.zed.",
        "com.jetbrains.",
        "com.google.android.studio",
        "com.panic.nova",
        "com.sublimetext.",
        "com.barebones.bbedit",
        "com.coteditor.",
        "com.macromates.",
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "dev.warp.",
        "com.mitchellh.ghostty",
        "com.exafunction.",
        "com.github.githubclient",
        "com.googlecode.macvim",
        "com.qvacua.vimr",
    ]
    private static let codeNames = [
        "xcode", "vscode", "cursor", "zed", "intellij", "pycharm", "webstorm", "phpstorm",
        "goland", "clion", "rider", "rubymine", "datagrip", "nova", "sublime", "bbedit",
        "coteditor", "textmate", "iterm", "iterm2", "terminal", "warp", "ghostty", "windsurf",
        "trae", "vim", "macvim", "vimr", "postman", "tableplus", "docker", "insomnia",
        "gitkraken", "sourcetree", "visual studio code", "android studio", "github desktop",
    ]
    private static let emailBundles = [
        "com.apple.mail",
        "com.microsoft.outlook",
        "com.readdle.smartemail",
        "com.readdle.sparkdesktop",
        "com.airmail.",
        "com.mimestream.",
        "org.mozilla.thunderbird",
        "com.freron.mailmate",
        "com.superhuman.",
    ]
    private static let emailNames = [
        "mail", "outlook", "spark", "thunderbird", "airmail", "mimestream", "superhuman", "mailmate",
    ]
    private static let chatBundles = [
        "com.tinyspeck.slackmacgap",
        "com.apple.mobilesms",
        "com.apple.messages",
        "net.whatsapp.whatsapp",
        "net.whatsapp.whatsapp.mac",
        "com.hnc.discord",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "org.telegram.",
        "ru.keepcoder.telegram",
        "org.whispersystems.signal",
        "com.facebook.archon",
        "com.skype.skype",
        "com.apple.ichat",
    ]
    private static let chatNames = [
        "slack", "whatsapp", "discord", "teams", "telegram", "signal", "messenger", "messages", "skype",
    ]
    private static let noteBundles = [
        "com.apple.notes",
        "com.apple.stickies",
        "com.apple.freeform",
        "com.apple.textedit",
        "com.apple.reminders",
        "md.obsidian",
        "notion.id",
        "com.bear-writer.",
        "com.lukilabs.lukiapp",
        "com.goodnotes.",
        "com.microsoft.word",
        "com.apple.iwork.pages",
        "com.ulyssesapp.",
        "com.logseq.",
    ]
    private static let noteNames = [
        "notes", "notizen", "obsidian", "notion", "bear", "craft", "goodnotes", "word", "pages",
        "textedit", "ulysses", "logseq", "reminders", "erinnerungen", "stickies", "freeform",
        "typora", "scrivener",
    ]
}
