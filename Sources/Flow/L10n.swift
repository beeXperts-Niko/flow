import Foundation

/// UI strings from `Languages/<code>.json`.
/// Bundle copies and `~/Library/Application Support/Flow/Languages` are both scanned.
/// A file in Application Support overrides the same keys from the bundle.
/// System language is used when a file exists. Otherwise German stays German, and every other language uses English.
enum L10n {
    static var languageCode: String { loaded.code }
    static var locale: Locale { loaded.locale }

    static func s(_ key: String) -> String {
        loaded.active[key] ?? loaded.english[key] ?? key
    }

    static func s(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), locale: locale, arguments: args)
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private struct Loaded {
        var code: String
        var locale: Locale
        var active: [String: String]
        var english: [String: String]
    }

    private static let loaded = load()

    private static func load() -> Loaded {
        let tables = readTables()
        let code = resolve(tables.keys)
        return Loaded(
            code: code,
            locale: Locale(identifier: code),
            active: tables[code] ?? tables[match("en", in: tables) ?? ""] ?? [:],
            english: tables[match("en", in: tables) ?? ""] ?? [:]
        )
    }

    private static func readTables() -> [String: [String: String]] {
        var merged: [String: [String: String]] = [:]
        for directory in directories() {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }
            for file in files where file.pathExtension.lowercased() == "json" {
                let code = file.deletingPathExtension().lastPathComponent
                guard let data = try? Data(contentsOf: file),
                      let map = try? JSONDecoder().decode([String: String].self, from: data) else { continue }
                var next = merged[canonical(code)] ?? [:]
                for (key, value) in map where !key.hasPrefix("_") {
                    next[key] = value
                }
                merged[canonical(code)] = next
            }
        }
        return merged
    }

    private static func directories() -> [URL] {
        var urls: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Languages") {
            urls.append(bundled)
        }
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Languages")
        urls.append(source)
        urls.append(SupportPaths.directory.appendingPathComponent("Languages"))
        return urls
    }

    /// First preferred language only. A matching file wins (full tag, then language).
    /// German with a `de` file stays German. Every other miss uses English.
    private static func resolve(_ codes: Dictionary<String, [String: String]>.Keys) -> String {
        let available = Array(codes)
        let preferred = Locale.preferredLanguages.first ?? "en"
        for candidate in candidates(preferred) {
            if let hit = match(candidate, in: available) { return hit }
        }
        let language = candidates(preferred).last ?? preferred
        if language.caseInsensitiveCompare("de") == .orderedSame, let german = match("de", in: available) {
            return german
        }
        if let english = match("en", in: available) { return english }
        return available.sorted().first ?? "en"
    }

    private static func candidates(_ identifier: String) -> [String] {
        let canonical = identifier.replacingOccurrences(of: "_", with: "-")
        var list = [canonical]
        let parts = canonical.split(separator: "-").map(String.init)
        if parts.count > 2 {
            list.append(parts.dropLast().joined(separator: "-"))
        }
        if let language = parts.first, !list.contains(where: { $0.caseInsensitiveCompare(language) == .orderedSame }) {
            list.append(language)
        }
        return list
    }

    private static func canonical(_ code: String) -> String {
        let parts = code.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        guard let language = parts.first else { return code }
        var result = language.lowercased()
        if parts.count >= 2 {
            let rest = parts.dropFirst().map { part -> String in
                if part.count == 2, part.allSatisfy(\.isLetter) { return part.uppercased() }
                return part.prefix(1).uppercased() + part.dropFirst().lowercased()
            }
            result += "-" + rest.joined(separator: "-")
        }
        return result
    }

    private static func match(_ candidate: String, in codes: [String]) -> String? {
        let folded = canonical(candidate)
        return codes.first { canonical($0).caseInsensitiveCompare(folded) == .orderedSame }
    }

    private static func match(_ candidate: String, in tables: [String: [String: String]]) -> String? {
        match(candidate, in: Array(tables.keys))
    }
}
