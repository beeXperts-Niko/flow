import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var whisperDraft = ""
    @State private var apiKeyDraft = ""
    @State private var modelNameDraft = ""

    var body: some View {
        Page(title: L10n.s("settings.title"), subtitle: L10n.s("settings.subtitle")) {
            SettingsSection(title: L10n.s("settings.hotkey.section"), icon: "keyboard") {
                SettingRow(title: L10n.s("settings.hotkey.title"), detail: L10n.s("settings.hotkey.detail")) {
                    Picker("", selection: $state.config.hotkey) {
                        ForEach([Hotkey.function, .rightOption, .rightCommand, .rightControl, .leftControl], id: \.rawValue) { key in
                            Text(key.title).tag(key.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSection(title: L10n.s("settings.language.section"), icon: "globe") {
                SettingRow(title: L10n.s("settings.native.title"), detail: L10n.s("settings.native.detail")) {
                    Picker("", selection: $state.config.nativeLanguage) {
                        ForEach(TranslateLanguage.all) { lang in
                            Text("\(lang.id.uppercased())  \(lang.name)").tag(lang.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                SettingRow(title: L10n.s("settings.recognition.title"), detail: L10n.s("settings.recognition.detail")) {
                    Picker("", selection: $state.config.language) {
                        Text(L10n.s("lang.auto")).tag("auto")
                        Text(L10n.s("lang.de")).tag("de")
                        Text(L10n.s("lang.en")).tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }

            SettingsSection(title: L10n.s("settings.recording.section"), icon: "waveform") {
                SettingRow(
                    title: L10n.s("settings.correction.title"),
                    detail: correctionDetail
                ) {
                    Toggle("", isOn: $state.config.autoCorrect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!state.engineReady)
                }
                Divider()
                SettingRow(title: L10n.s("settings.sounds.title"), detail: L10n.s("settings.sounds.detail")) {
                    Toggle("", isOn: $state.config.playSounds).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(title: L10n.s("settings.mute.title"), detail: L10n.s("settings.mute.detail")) {
                    Picker("", selection: $state.config.othersAudio) {
                        Text(L10n.s("audio.off")).tag(OthersAudio.off.rawValue)
                        Text(L10n.s("audio.quiet")).tag(OthersAudio.quiet.rawValue)
                        Text(L10n.s("audio.mute")).tag(OthersAudio.mute.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                Divider()
                SettingRow(title: L10n.s("settings.rewrite.title"), detail: L10n.s("settings.rewrite.detail")) {
                    Toggle("", isOn: $state.config.commandMode).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsSection(title: L10n.s("settings.system.section"), icon: "macwindow") {
                SettingRow(title: L10n.s("settings.login.title"), detail: L10n.s("settings.login.detail")) {
                    Toggle("", isOn: $state.config.launchAtLogin).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsSection(title: L10n.s("settings.permissions.section"), icon: "lock.shield") {
                PermissionRow(
                    title: L10n.s("common.mic"),
                    detail: L10n.s("settings.mic.detail"),
                    icon: "mic.fill",
                    granted: state.micGranted,
                    action: state.requestMicrophone
                )
                Divider()
                PermissionRow(
                    title: L10n.s("common.accessibility"),
                    detail: L10n.s("settings.ax.detail"),
                    icon: "accessibility",
                    granted: state.axGranted,
                    action: state.openAccessibility,
                    repairHint: L10n.s("settings.ax.repair")
                )
                if !state.axGranted {
                    Divider()
                    AccessibilityRepairCard()
                }
            }

            SettingsSection(title: L10n.s("settings.asr.title"), icon: "waveform") {
                SettingRow(title: L10n.s("settings.model.short"), detail: L10n.s("settings.asr.detail")) {
                    HStack(spacing: 6) {
                        TextField("", text: $whisperDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                            .onSubmit(applyWhisper)
                        if whisperDraft != state.config.whisperModel {
                            Button(L10n.s("settings.apply"), action: applyWhisper).buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                Divider()
                SettingRow(
                    title: "Whisper",
                    detail: SnapshotMode.isActive
                        ? L10n.s("settings.whisper.local")
                        : L10n.s("settings.whisper.path", SupportPaths.models.path)
                ) {
                    Button(L10n.s("settings.reveal")) {
                        NSWorkspace.shared.activateFileViewerSelecting([SupportPaths.models])
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                Divider()
                SettingRow(title: L10n.s("settings.status"), detail: state.engineStatus) {
                    HStack(spacing: 8) {
                        StatusPill(state: state.engineState, text: statusLabel)
                        Button(L10n.s("settings.restart")) { state.reloadEngine() }.buttonStyle(SoftButtonStyle())
                    }
                }
            }

            SettingsSection(title: L10n.s("settings.correction.section"), icon: "sparkles") {
                SettingRow(title: L10n.s("settings.model.short"), detail: correctionModelDetail) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Picker("", selection: $state.config.correctionKind) {
                            Text(L10n.s("settings.correction.chatgpt")).tag("chatgpt")
                            Text(L10n.s("settings.correction.own")).tag("custom")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 240)
                        if state.config.usesCustomCorrectionAPI {
                            TextField(L10n.s("settings.model.namePlaceholder"), text: $modelNameDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 240)
                                .onSubmit(applyModelName)
                                .onChange(of: modelNameDraft) { _, _ in applyModelName() }
                                .help(L10n.s("settings.model.customHint"))
                        } else {
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
                    }
                }
                if state.config.usesCustomCorrectionAPI {
                    Divider()
                    SettingRow(title: L10n.s("settings.api.title"), detail: L10n.s("settings.api.detail")) {
                        TextField(L10n.s("settings.api.placeholder"), text: $state.config.correctionBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                            .onSubmit { state.lookupCorrectionModel(apiKeyDraft) }
                    }
                }
                Divider()
                SettingRow(
                    title: L10n.s("settings.key.title"),
                    detail: state.config.usesCustomCorrectionAPI
                        ? L10n.s("settings.key.detailCustom")
                        : L10n.s("settings.key.detail")
                ) {
                    HStack(spacing: 6) {
                        SecureField("sk-…", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        Button(L10n.s("settings.paste"), action: pasteAPIKey)
                            .buttonStyle(SoftButtonStyle())
                    }
                }
            }

            SettingsSection(title: L10n.s("update.settings.section"), icon: "arrow.down.app") {
                SettingRow(title: L10n.s("update.settings.title"), detail: updateDetail) {
                    HStack(spacing: 8) {
                        if state.update == .checking || state.isDownloadingUpdate {
                            ProgressView().controlSize(.small)
                        }
                        if state.availableRelease != nil {
                            Button(L10n.s("update.settings.install"), action: state.installAvailableUpdate)
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(state.isDownloadingUpdate)
                        }
                        Button(L10n.s("update.settings.check")) {
                            state.checkForUpdate(userInitiated: true)
                        }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(state.update == .checking || state.isDownloadingUpdate)
                    }
                }
                if state.update == .failed {
                    Divider()
                    SettingRow(title: L10n.s("update.settings.open"), detail: L10n.s("update.settings.failed")) {
                        Button(L10n.s("update.settings.open"), action: state.openUpdatePage)
                            .buttonStyle(SoftButtonStyle())
                    }
                }
            }

            SettingsSection(title: L10n.s("settings.data.section"), icon: "folder") {
                SettingRow(title: L10n.s("settings.storage.title"), detail: L10n.s("settings.storage.detail")) {
                    HStack(spacing: 8) {
                        Button(L10n.s("settings.reveal")) {
                            NSWorkspace.shared.activateFileViewerSelecting([SupportPaths.config])
                        }
                        .buttonStyle(SoftButtonStyle())
                        Button(L10n.s("settings.log")) {
                            NSWorkspace.shared.open(SupportPaths.log)
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text(footerText)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .onAppear {
            whisperDraft = state.config.whisperModel
            apiKeyDraft = OpenAIKeyStore.load()
            syncModelName()
            state.lookupCorrectionModel(apiKeyDraft)
        }
        .onChange(of: apiKeyDraft) { _, _ in
            let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            OpenAIKeyStore.save(key)
            state.polishAvailable = state.engineReady && state.config.correctionConfigured(hasKey: !key.isEmpty)
            state.lookupCorrectionModel(key)
        }
        .onChange(of: state.config.correctionKind) { _, _ in
            state.polishAvailable = state.engineReady && state.config.correctionConfigured(
                hasKey: !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            state.lookupCorrectionModel(apiKeyDraft)
        }
        .onChange(of: state.config.correctionBaseURL) { _, _ in
            state.polishAvailable = state.engineReady && state.config.correctionConfigured(
                hasKey: !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            state.lookupCorrectionModel(apiKeyDraft)
        }
        .onChange(of: state.config.openAIModel) { _, _ in
            syncModelName()
        }
    }

    private var updateDetail: String {
        switch state.update {
        case .checking:
            return L10n.s("update.settings.checking")
        case .current:
            return L10n.s("update.settings.currentOk")
        case .available(let release):
            return L10n.s("update.settings.available", release.version)
        case .downloading:
            return L10n.s("update.settings.downloading")
        case .failed:
            return L10n.s("update.settings.failed")
        case .idle:
            return L10n.s("update.settings.current", L10n.appVersion)
        }
    }

    private var footerText: String {
        if state.config.usesCustomCorrectionAPI {
            return L10n.s("settings.footer.custom", L10n.appVersion)
        }
        return state.config.correctsWithOpenAI
            ? L10n.s("settings.footer.on", L10n.appVersion)
            : L10n.s("settings.footer.off", L10n.appVersion)
    }

    private func syncModelName() {
        modelNameDraft = state.config.openAIModel == "auto" ? "" : state.config.openAIModel
    }

    private func applyModelName() {
        let name = modelNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = name.isEmpty ? "auto" : name
        guard state.config.openAIModel != next else { return }
        state.config.openAIModel = next
    }

    private var recommendedModelTitle: String {
        state.correctionModel.isEmpty ? L10n.s("settings.recommended") : L10n.s("settings.recommendedNamed", state.correctionModel)
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
        if state.config.usesCustomCorrectionAPI {
            if state.config.openAIModel != "auto" {
                let recommendation = state.correctionModel.isEmpty ? "—" : state.correctionModel
                return L10n.s("settings.model.pinned", state.config.openAIModel, recommendation)
            }
            if state.correctionModel.isEmpty {
                return L10n.s("settings.model.typeName")
            }
            return L10n.s("settings.model.auto", state.correctionModel)
        }
        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.s("settings.model.noKey")
        }
        if state.correctionModel.isEmpty {
            return L10n.s("settings.model.looking")
        }
        if state.config.openAIModel == "auto" {
            return L10n.s("settings.model.auto", state.correctionModel)
        }
        return L10n.s("settings.model.pinned", state.config.openAIModel, state.correctionModel)
    }

    private var correctionDetail: String {
        if !state.config.autoCorrect {
            return L10n.s("settings.correction.off")
        }
        if state.config.usesCustomCorrectionAPI {
            return L10n.s("settings.correction.custom")
        }
        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.s("settings.correction.noKey")
        }
        return L10n.s("settings.correction.on")
    }

    private var statusLabel: String {
        switch state.engineState {
        case .ready: return L10n.s("status.ready")
        case .loading: return L10n.s("status.loading")
        case .error: return L10n.s("status.error")
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
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            control
        }
    }
}
