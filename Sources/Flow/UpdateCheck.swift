import AppKit
import Foundation

struct AppRelease: Equatable {
    var version: String
    var pkgURL: URL
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case current
    case available(AppRelease)
    case downloading(AppRelease)
    case failed
}

enum UpdateCheck {
    static let feed = URL(string: "https://sinthex.de/flow/latest.json")!
    static let page = URL(string: "https://sinthex.de/flow/")!
    private static let dismissedKey = "flow.dismissedUpdate"

    private struct Payload: Decodable {
        var version: String
        var pkg: String
    }

    static var dismissedVersion: String {
        get { UserDefaults.standard.string(forKey: dismissedKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: dismissedKey) }
    }

    static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = parts(remote)
        let localParts = parts(local)
        let count = max(remoteParts.count, localParts.count)
        for index in 0..<count {
            let remoteValue = index < remoteParts.count ? remoteParts[index] : 0
            let localValue = index < localParts.count ? localParts[index] : 0
            if remoteValue != localValue { return remoteValue > localValue }
        }
        return false
    }

    static func fetch() async throws -> AppRelease {
        var request = URLRequest(url: feed)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let version = payload.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty, let pkg = URL(string: payload.pkg) else {
            throw URLError(.cannotParseResponse)
        }
        return AppRelease(version: version, pkgURL: pkg)
    }

    static func download(_ release: AppRelease) async throws -> URL {
        var request = URLRequest(url: release.pkgURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 180
        let (temp, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Flow-\(release.version).pkg")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    /// Expands the package and replaces the running app, then that app opens again.
    /// When the folder is not writable, macOS asks for an administrator password
    /// before this app quits. The replacement then belongs to the user.
    static func stageRelaunch(pkg: URL, version: String) throws {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let expanded = work.appendingPathComponent("expanded", isDirectory: true)
        let expand = Process()
        expand.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        expand.arguments = ["--expand-full", pkg.path, expanded.path]
        try expand.run()
        expand.waitUntilExit()
        guard expand.terminationStatus == 0,
              let source = flowApp(in: expanded, version: version) else {
            throw URLError(.cannotDecodeContentData)
        }
        let destination = Bundle.main.bundleURL.standardizedFileURL
        guard destination.pathExtension == "app" else { throw URLError(.cannotCreateFile) }
        let parent = destination.deletingLastPathComponent()
        let incoming = parent.appendingPathComponent("Flow.app.incoming")
        let owner = NSUserName()
        let group = groupName()
        let stagedBeside = FileManager.default.isWritableFile(atPath: parent.path)
            && ditto(source, to: incoming)
        if !stagedBeside {
            try? FileManager.default.removeItem(at: incoming)
            try privilegedReplace(source: source, destination: destination, owner: owner, group: group)
        }
        let script = work.appendingPathComponent("relaunch.sh")
        let body = stagedBeside
            ? relaunchAfterSwap(incoming: incoming, destination: destination)
            : relaunchAfterPrivileged(destination: destination)
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/bin/bash")
        launch.arguments = [
            "-c",
            "nohup \"$0\" \"$1\" >/dev/null 2>&1 &",
            script.path,
            "\(ProcessInfo.processInfo.processIdentifier)",
        ]
        try launch.run()
        launch.waitUntilExit()
        guard launch.terminationStatus == 0 else { throw URLError(.cannotOpenFile) }
    }

    private static func flowApp(in root: URL, version: String) -> URL? {
        guard let found = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in found where url.lastPathComponent == "Flow.app" {
            let info = url.appendingPathComponent("Contents/Info.plist")
            let binary = url.appendingPathComponent("Contents/MacOS/Flow")
            guard FileManager.default.isExecutableFile(atPath: binary.path),
                  let dict = NSDictionary(contentsOf: info),
                  dict["CFBundleIdentifier"] as? String == "de.sinthex.flow",
                  dict["CFBundleShortVersionString"] as? String == version else { continue }
            return url
        }
        return nil
    }

    private static func ditto(_ source: URL, to destination: URL) -> Bool {
        try? FileManager.default.removeItem(at: destination)
        let copy = Process()
        copy.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copy.arguments = [source.path, destination.path]
        guard (try? copy.run()) != nil else { return false }
        copy.waitUntilExit()
        let binary = destination.appendingPathComponent("Contents/MacOS/Flow")
        return copy.terminationStatus == 0 && FileManager.default.isExecutableFile(atPath: binary.path)
    }

    private static func privilegedReplace(source: URL, destination: URL, owner: String, group: String) throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowUpdate-privileged-\(UUID().uuidString).sh")
        let body = """
        #!/bin/bash
        set -euo pipefail
        dest="$1"
        src="$2"
        owner="$3"
        group="$4"
        backup="${dest}.previous"
        rm -rf "$backup"
        mv "$dest" "$backup"
        if ! /usr/bin/ditto "$src" "$dest"; then
          mv "$backup" "$dest"
          exit 1
        fi
        /usr/sbin/chown -R "${owner}:${group}" "$dest"
        /usr/bin/xattr -dr com.apple.quarantine "$dest" || true
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let ask = Process()
        ask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        ask.arguments = [
            "-e",
            """
            on run argv
              do shell script quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) & " " & quoted form of (item 3 of argv) & " " & quoted form of (item 4 of argv) & " " & quoted form of (item 5 of argv) with administrator privileges
            end run
            """,
            script.path,
            destination.path,
            source.path,
            owner,
            group,
        ]
        try ask.run()
        ask.waitUntilExit()
        guard ask.terminationStatus == 0 else { throw URLError(.noPermissionsToReadFile) }
    }

    private static func groupName() -> String {
        let pipe = Pipe()
        let id = Process()
        id.executableURL = URL(fileURLWithPath: "/usr/bin/id")
        id.arguments = ["-gn"]
        id.standardOutput = pipe
        guard (try? id.run()) != nil else { return "staff" }
        id.waitUntilExit()
        let name = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "staff" : name
    }

    private static func relaunchAfterSwap(incoming: URL, destination: URL) -> String {
        let incomingPath = shellQuote(incoming.path)
        let destinationPath = shellQuote(destination.path)
        return """
        #!/bin/bash
        set -u
        pid="$1"
        incoming=\(incomingPath)
        dest=\(destinationPath)
        log="${HOME}/Library/Logs/Flow-update.log"
        mkdir -p "$(dirname "$log")"
        for _ in $(seq 1 150); do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.2
        done
        sleep 0.4
        if rm -rf "$dest" && mv "$incoming" "$dest"; then
          /usr/bin/xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
          echo "$(date '+%Y-%m-%d %H:%M:%S') replaced $dest" >> "$log"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') needs privileges" >> "$log"
          /usr/bin/osascript - "$dest" "$incoming" <<'APPLESCRIPT' >> "$log" 2>&1
        on run argv
          do shell script "rm -rf " & quoted form of (item 1 of argv) & " && /bin/mv " & quoted form of (item 2 of argv) & " " & quoted form of (item 1 of argv) & " && /usr/bin/xattr -dr com.apple.quarantine " & quoted form of (item 1 of argv) with administrator privileges
        end run
        APPLESCRIPT
        fi
        if [ -d "$dest" ]; then
          /usr/bin/open "$dest"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') opening incoming copy" >> "$log"
          /usr/bin/open "$incoming"
        fi
        """
    }

    private static func relaunchAfterPrivileged(destination: URL) -> String {
        let destinationPath = shellQuote(destination.path)
        return """
        #!/bin/bash
        set -u
        pid="$1"
        dest=\(destinationPath)
        for _ in $(seq 1 150); do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.2
        done
        sleep 0.4
        rm -rf "${dest}.previous"
        /usr/bin/open "$dest"
        """
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
