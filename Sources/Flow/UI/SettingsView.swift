import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var whisperDraft = ""
    @State private var apiKeyDraft = ""

    var body: some View {
        Page(title: "Einstellungen", subtitle: "Taste, Aufnahme, Berechtigungen und Modell.") {
            SettingsSection(title: "Taste", icon: "keyboard") {
                SettingRow(title: "Diktiertaste", detail: "Standard ist Fn. Halten zum Sprechen, Doppeltipp für freies Sprechen.") {
                    Picker("", selection: $state.config.hotkey) {
                        ForEach([Hotkey.function, .rightOption, .rightCommand, .rightControl, .leftControl], id: \.rawValue) { key in
                            Text(key.title).tag(key.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSection(title: "Sprache", icon: "globe") {
                SettingRow(title: "Muttersprache", detail: "Für Übersetzungen aus dem Widget (Flaggen).") {
                    Picker("", selection: $state.config.nativeLanguage) {
                        ForEach(TranslateLanguage.all) { lang in
                            Text("\(lang.id.uppercased())  \(lang.name)").tag(lang.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                SettingRow(title: "Erkennung", detail: "Whisper: fest eingestellt erkennt genauer.") {
                    Picker("", selection: $state.config.language) {
                        Text("Automatisch").tag("auto")
                        Text("Deutsch").tag("de")
                        Text("Englisch").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }

            SettingsSection(title: "Aufnahme", icon: "waveform") {
                SettingRow(
                    title: "Automatische Korrektur",
                    detail: correctionDetail
                ) {
                    Toggle("", isOn: $state.config.autoCorrect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!state.engineReady)
                }
                Divider()
                SettingRow(title: "Töne", detail: "Kurzer Klang beim Start und Ende.") {
                    Toggle("", isOn: $state.config.playSounds).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(title: "Markierten Text umschreiben", detail: "Gesprochenes wird zum Befehl für die Markierung.") {
                    Toggle("", isOn: $state.config.commandMode).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsSection(title: "System", icon: "macwindow") {
                SettingRow(title: "Beim Anmelden starten", detail: "Flow liegt dann direkt in der Menüleiste bereit.") {
                    Toggle("", isOn: $state.config.launchAtLogin).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsSection(title: "Berechtigungen", icon: "lock.shield") {
                PermissionRow(
                    title: "Mikrofon",
                    detail: "Damit Flow deine Stimme hört.",
                    icon: "mic.fill",
                    granted: state.micGranted,
                    action: state.requestMicrophone
                )
                Divider()
                PermissionRow(
                    title: "Bedienungshilfen",
                    detail: "Für die globale Taste und das Einfügen in andere Apps.",
                    icon: "accessibility",
                    granted: state.axGranted,
                    action: state.openAccessibility,
                    repairHint: "Schalter an, Flow sagt trotzdem nein? Eintrag für Flow löschen oder aus/an, danach Flow neu starten."
                )
                if !state.axGranted {
                    Divider()
                    AccessibilityRepairCard()
                }
            }

            SettingsSection(title: "Modell", icon: "cpu") {
                SettingRow(
                    title: "Whisper",
                    detail: SnapshotMode.isActive
                        ? "Liegt lokal auf diesem Mac, im Flow-Ordner."
                        : "Läuft immer lokal in \(SupportPaths.models.path)"
                ) {
                    Button("Im Finder zeigen") {
                        NSWorkspace.shared.activateFileViewerSelecting([SupportPaths.models])
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Divider()
                SettingRow(title: "Spracherkennung", detail: "Modelldatei im Flow-Ordner. Die Aufnahme geht nicht in die Cloud.") {
                    HStack(spacing: 6) {
                        TextField("", text: $whisperDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                            .onSubmit(applyWhisper)
                        if whisperDraft != state.config.whisperModel {
                            Button("Übernehmen", action: applyWhisper).buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                Divider()
                SettingRow(title: "API-Schlüssel", detail: "Nur für die Korrektur. ⌘V oder Einfügen. Liegt danach im Schlüsselbund.") {
                    HStack(spacing: 6) {
                        SecureField("sk-…", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        Button("Einfügen", action: pasteAPIKey)
                            .buttonStyle(SoftButtonStyle())
                    }
                }
                Divider()
                SettingRow(title: "Korrektur-Modell", detail: correctionModelDetail) {
                    Picker("", selection: $state.config.openAIModel) {
                        Text(recommendedModelTitle).tag("auto")
                        if !modelChoices.isEmpty {
                            Divider()
                        }
                        ForEach(modelChoices, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 240)
                }
                Divider()
                SettingRow(title: "Status", detail: state.engineStatus) {
                    HStack(spacing: 8) {
                        StatusPill(state: state.engineState, text: statusLabel)
                        Button("Neu starten") { state.reloadEngine() }.buttonStyle(SoftButtonStyle())
                    }
                }
            }

            SettingsSection(title: "Daten", icon: "folder") {
                SettingRow(title: "Speicherort", detail: "Einstellungen, Verlauf und Protokoll liegen nur auf diesem Mac.") {
                    HStack(spacing: 8) {
                        Button("Im Finder zeigen") {
                            NSWorkspace.shared.activateFileViewerSelecting([SupportPaths.config])
                        }
                        .buttonStyle(SoftButtonStyle())
                        Button("Protokoll") {
                            NSWorkspace.shared.open(SupportPaths.log)
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text(state.config.correctsWithOpenAI
                     ? "Flow 1.0 · Die Aufnahme bleibt auf diesem Mac. Zur Korrektur geht der Text an OpenAI."
                     : "Flow 1.0 · Audio und Text verlassen deinen Mac nicht.")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .onAppear {
            whisperDraft = state.config.whisperModel
            apiKeyDraft = OpenAIKeyStore.load()
            state.lookupCorrectionModel(apiKeyDraft)
        }
        .onChange(of: apiKeyDraft) { _, _ in
            let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            OpenAIKeyStore.save(key)
            if state.config.correctsWithOpenAI {
                state.polishAvailable = state.engineReady && !key.isEmpty
            }
            state.lookupCorrectionModel(key)
        }
    }

    private var recommendedModelTitle: String {
        state.correctionModel.isEmpty ? "Empfohlen" : "Empfohlen: \(state.correctionModel)"
    }

    private var modelChoices: [String] {
        var ids = state.correctionModels
        let selected = state.config.openAIModel
        if selected != "auto", !selected.isEmpty, !ids.contains(selected) {
            ids.append(selected)
        }
        return ids
    }

    private var correctionModelDetail: String {
        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Empfohlen ist immer die neueste schnelle Stufe für deinen Schlüssel."
        }
        if state.correctionModel.isEmpty {
            return "Die Empfehlung wird gerade über den Schlüssel ermittelt."
        }
        if state.config.openAIModel == "auto" {
            return "Empfohlen: \(state.correctionModel). Im Menü kannst du ein anderes Modell festlegen."
        }
        return "Festgelegt auf \(state.config.openAIModel). Empfehlung: \(state.correctionModel)."
    }

    private var correctionDetail: String {
        if !state.config.autoCorrect {
            return "Aus. Whisper schreibt den Text, wie er ihn hört."
        }
        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "An, aber ohne API-Schlüssel bleibt es bei Whisper. Den Schlüssel trägst du unten ein."
        }
        return "OpenAI formuliert den Text nach. Die Aufnahme bleibt auf diesem Mac."
    }

    private var statusLabel: String {
        switch state.engineState {
        case .ready: return "Bereit"
        case .loading: return "Lädt"
        case .error: return "Fehler"
        }
    }

    private func pasteAPIKey() {
        let board = NSPasteboard.general
        let raw = board.string(forType: .string)
            ?? board.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
        guard let raw else { return }
        apiKeyDraft = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyWhisper() {
        let value = whisperDraft.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        state.config.whisperModel = value
    }

}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .card(padding: 18)
        }
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer()
            control
        }
    }
}
