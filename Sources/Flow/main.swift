import Cocoa

let app = NSApplication.shared
let arguments = CommandLine.arguments

if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
    app.setActivationPolicy(.accessory)
    Snapshot.run(into: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
