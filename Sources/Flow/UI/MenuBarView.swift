import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            recordButton
                .padding(.horizontal, 14)

            if !state.hasPermissions {
                permissionHint
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            if state.showsUpdateOffer {
                updateHint
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(L10n.s("menu.correction"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $state.config.autoCorrect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!state.engineReady)
                }
                .help(state.polishAvailable ? "" : (
                    state.config.usesCustomCorrectionAPI
                        ? L10n.s("menu.correctionUnavailable")
                        : L10n.s("menu.correctionNeedsKey")
                ))
                HStack(spacing: 8) {
                    Text(L10n.s("menu.mute"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $state.config.othersAudio) {
                        Text(L10n.s("audio.off")).tag(OthersAudio.off.rawValue)
                        Text(L10n.s("audio.quiet")).tag(OthersAudio.quiet.rawValue)
                        Text(L10n.s("audio.mute")).tag(OthersAudio.mute.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.s("menu.style"))
                            .font(.system(size: 12, weight: .medium))
                        if let app = state.frontApp {
                            Text(app.name)
                                .font(.system(size: 10.5))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Picker("", selection: menuStyle) {
                        ForEach(StyleOption.all) { option in
                            Label(option.title, systemImage: option.icon).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                .disabled(!state.config.autoCorrect)
                .opacity(state.config.autoCorrect ? 1 : 0.45)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 14)

            recent
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

            Divider()

            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
        .tint(Theme.violet)
    }

    private var menuStyle: Binding<String> {
        Binding(
            get: {
                if let app = state.frontApp {
                    return state.effectiveStyle(for: app)
                }
                return state.config.style
            },
            set: { style in
                if let app = state.frontApp {
                    state.setAppStyle(bundleID: app.bundleID, name: app.name, style: style)
                } else {
                    state.config.style = style
                }
            }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            FlowMark(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("Flow").font(.system(size: 14, weight: .semibold))
                Text(state.modelDisplayName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusPill(state: state.engineState, text: shortStatus)
        }
    }

    private var shortStatus: String {
        switch state.engineState {
        case .ready: return L10n.s("status.ready")
        case .loading: return L10n.s("status.loading")
        case .error: return L10n.s("status.error")
        }
    }

    private var recordButton: some View {
        let listening = state.phase == .listening
        return Button {
            state.toggleRecording()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.22)).frame(width: 34, height: 34)
                    Image(systemName: listening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(listening ? L10n.s("menu.stop") : L10n.s("menu.speakFree"))
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(listening ? Fmt.clock(state.elapsed) : L10n.s("menu.orHold", state.config.resolvedHotkey.symbol))
                        .font(.system(size: 11).monospacedDigit())
                        .opacity(0.8)
                }
                Spacer()
                if listening {
                    MirroredWaveform(levels: state.levels, bars: 11)
                        .frame(width: 56, height: 22)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(listening
                          ? AnyShapeStyle(Color.red.gradient)
                          : AnyShapeStyle(Theme.gradient))
            )
            .shadow(color: (listening ? Color.red : Theme.violet).opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!state.engineReady && !listening)
        .opacity(state.engineReady || listening ? 1 : 0.6)
    }

    private var updateHint: some View {
        Button {
            state.installAvailableUpdate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.app.fill").foregroundStyle(Theme.violet)
                Text(L10n.s("update.menu", state.availableRelease?.version ?? ""))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if state.isDownloadingUpdate {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.violet.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(state.isDownloadingUpdate)
    }

    private var permissionHint: some View {
        Button {
            state.openMain(.home)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
                Text(L10n.s("menu.permissions"))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recent: some View {
        let items = Array(state.history.prefix(4))
        if items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text(L10n.s("menu.empty"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.s("menu.recent"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                ForEach(items) { entry in
                    HistoryRow(entry: entry, mode: .compact)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 7) {
            HStack(spacing: 4) {
                Button {
                    state.openMain(.home)
                } label: {
                    Label(L10n.s("menu.open"), systemImage: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(SoftButtonStyle())
                Spacer()
                Button {
                    state.openMain(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(IconButtonStyle())
                .help(L10n.s("menu.settings"))
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(IconButtonStyle())
                .help(L10n.s("menu.quit"))
            }
            Text(L10n.appVersion)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }
}
