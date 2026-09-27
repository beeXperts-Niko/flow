import ApplicationServices
import Cocoa

struct InsertResult {
    var pasted: Bool
    /// Text bleibt in der Zwischenablage (kein Textfeld / kein AX) – Nutzer kann ⌘V oder ⌘⇧V.
    var keptOnClipboard: Bool
}

final class TextInserter {
    private var restoreWork: DispatchWorkItem?
    /// User clipboard waiting to be restored; reused if a second paste happens before the restore.
    private var pendingRestore: [[NSPasteboard.PasteboardType: Data]]?

    func selectedText() -> String? {
        guard let element = focusedElement() else { return nil }
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard error == .success, let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20_000 else { return nil }
        return text
    }

    func hasEditableFocus() -> Bool {
        guard Permissions.accessibilityGranted(), let element = focusedElement() else { return false }
        return isEditable(element)
    }

    init() {
        // Electron/Chromium apps can stall AX queries for seconds (default timeout 6s).
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
    }

    @discardableResult
    func insert(_ text: String) -> InsertResult {
        Timing.mark("insert: start")
        restoreWork?.cancel()
        let saved = pendingRestore ?? snapshot()
        Timing.mark("insert: clipboard saved (\(saved.count) items)")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Paste first; the AX checks below only decide about clipboard restore / fallback.
        let trusted = Permissions.accessibilityGranted()
        if trusted {
            post(key: 9, flags: .maskCommand)
            Timing.mark("insert: ⌘V posted")
        }
        let editable = trusted && hasEditableFocus()
        Timing.mark("insert: focus checked (editable=\(editable))")

        if editable {
            scheduleRestore(saved)
            return InsertResult(pasted: true, keptOnClipboard: false)
        }

        // Fallback: Text bleibt kopiert – ⌘V oder ⌘⇧V (Formatierung anpassen).
        pendingRestore = nil
        return InsertResult(pasted: false, keptOnClipboard: true)
    }

    /// Replaces the just-inserted raw text with `text`, but only if the characters right before the
    /// caret are verifiably `raw`. Returns false without touching anything otherwise – an unverified
    /// replace (e.g. ⌘Z + ⌘V) inserts the text twice in apps whose undo doesn't cover the paste.
    func replacePreviousInsert(raw: String, with text: String) -> Bool {
        guard Permissions.accessibilityGranted(),
              let element = focusedElement(),
              let range = rangeOfJustInserted(raw, in: element) else { return false }

        var cfRange = range
        guard let axRange = AXValueCreate(.cfRange, &cfRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axRange) == .success
        else { return false }

        // Some apps accept the set call but ignore it; never paste over an unexpected selection.
        guard selectedRawText(of: element) == raw else {
            var caret = CFRange(location: range.location + range.length, length: 0)
            if let back = AXValueCreate(.cfRange, &caret) {
                AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, back)
            }
            return false
        }

        restoreWork?.cancel()
        let saved = pendingRestore ?? snapshot()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        post(key: 9, flags: .maskCommand)
        scheduleRestore(saved)
        return true
    }

    /// Diagnostics: logs when `raw` actually shows up before the caret of the focused field.
    func logWhenLanded(_ raw: String, attempt: Int = 0) {
        guard Permissions.accessibilityGranted() else { return }
        if let element = focusedElement(), rangeOfJustInserted(raw, in: element) != nil {
            Timing.mark("text visible in target field")
            return
        }
        guard attempt < 60 else {
            Timing.mark("text not verifiable in target field after 3s")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.logWhenLanded(raw, attempt: attempt + 1)
        }
    }

    private func scheduleRestore(_ saved: [[NSPasteboard.PasteboardType: Data]]) {
        pendingRestore = saved
        let work = DispatchWorkItem { [weak self] in
            self?.restore(saved)
            self?.pendingRestore = nil
        }
        restoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    /// Range of `raw` ending exactly at the caret, in UTF-16 units as AX expects.
    private func rangeOfJustInserted(_ raw: String, in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var caret = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &caret), caret.length == 0 else { return nil }

        let length = (raw as NSString).length
        guard length > 0, caret.location >= length else { return nil }
        let candidate = CFRange(location: caret.location - length, length: length)
        guard text(in: candidate, of: element) == raw else { return nil }
        return candidate
    }

    private func text(in range: CFRange, of element: AXUIElement) -> String? {
        var cfRange = range
        if let axRange = AXValueCreate(.cfRange, &cfRange) {
            var result: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, axRange, &result
            ) == .success, let string = result as? String {
                return string
            }
        }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let full = value as? NSString,
              range.location + range.length <= full.length else { return nil }
        return full.substring(with: NSRange(location: range.location, length: range.length))
    }

    private func selectedRawText(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    func frontmostAppName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return app.localizedName
    }

    func copyToClipboard(_ text: String) {
        restoreWork?.cancel()
        pendingRestore = nil
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value)
        guard error == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func isEditable(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String ?? ""

        var editableValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editableValue) == .success,
           let editable = editableValue as? Bool {
            return editable
        }

        let editableRoles: Set<String> = [
            "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField",
            "AXWebArea", "AXTextEditor"
        ]
        if editableRoles.contains(role) { return true }

        // Manche Apps (Electron) melden AXGroup mit gesetztem SelectedText.
        var selected: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success {
            return true
        }
        return false
    }

    private func snapshot() -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = NSPasteboard.general.pasteboardItems else { return [] }
        return items.map { item in
            var stored: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    stored[type] = data
                }
            }
            return stored
        }
    }

    private func restore(_ snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items: [NSPasteboardItem] = snapshot.map { stored in
            let item = NSPasteboardItem()
            for (type, data) in stored {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func post(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
