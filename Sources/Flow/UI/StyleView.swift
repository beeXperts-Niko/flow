import AppKit
import SwiftUI

struct StyleOption: Identifiable {
    let id: String
    let title: String
    let icon: String
    let blurb: String
    let before: String
    let after: String

    static func titled(_ id: String) -> String {
        all.first { $0.id == id }?.title ?? id
    }

    static var all: [StyleOption] {
        [
            StyleOption(
                id: "auto", title: L10n.s("style.auto"), icon: "sparkles",
                blurb: L10n.s("style.auto.blurb"),
                before: L10n.s("style.auto.before"),
                after: L10n.s("style.auto.after")
            ),
            StyleOption(
                id: "literal", title: L10n.s("style.literal"), icon: "text.quote",
                blurb: L10n.s("style.literal.blurb"),
                before: L10n.s("style.literal.before"),
                after: L10n.s("style.literal.after")
            ),
            StyleOption(
                id: "email", title: L10n.s("style.email"), icon: "envelope",
                blurb: L10n.s("style.email.blurb"),
                before: L10n.s("style.email.before"),
                after: L10n.s("style.email.after")
            ),
            StyleOption(
                id: "chat", title: L10n.s("style.chat"), icon: "bubble.left.and.bubble.right",
                blurb: L10n.s("style.chat.blurb"),
                before: L10n.s("style.chat.before"),
                after: L10n.s("style.chat.after")
            ),
            StyleOption(
                id: "notes", title: L10n.s("style.notes"), icon: "list.bullet.rectangle",
                blurb: L10n.s("style.notes.blurb"),
                before: L10n.s("style.notes.before"),
                after: L10n.s("style.notes.after")
            ),
            StyleOption(
                id: "code", title: L10n.s("style.code"), icon: "chevron.left.forwardslash.chevron.right",
                blurb: L10n.s("style.code.blurb"),
                before: L10n.s("style.code.before"),
                after: L10n.s("style.code.after")
            )
        ]
    }
}

struct StyleView: View {
    @EnvironmentObject var state: AppState
    @State private var appQuery = ""
    @State private var showAllApps = false

    var body: some View {
        Page(title: L10n.s("style.title"), subtitle: L10n.s("style.subtitle")) {
            if let app = state.frontApp {
                Text(L10n.s("style.front", app.name, StyleOption.titled(state.effectiveStyle(for: app))))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(L10n.s("style.default"))
                .font(.system(size: 14, weight: .semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(StyleOption.all) { option in
                    StyleCard(option: option, selected: state.config.style == option.id) {
                        withAnimation(.snappy(duration: 0.2)) { state.config.style = option.id }
                    }
                }
            }

            appStyles

            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.s("style.custom.title"), systemImage: "text.bubble")
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.s("style.custom.body"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    if state.config.instructions.isEmpty {
                        Text(L10n.s("style.custom.placeholder"))
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $state.config.instructions)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .frame(height: 96)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke))
            }
            .card()

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.s("style.language"), systemImage: "globe")
                        .font(.system(size: 14, weight: .semibold))
                    Picker("", selection: $state.config.language) {
                        Text(L10n.s("lang.auto")).tag("auto")
                        Text(L10n.s("lang.de")).tag("de")
                        Text(L10n.s("lang.en")).tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    Text(L10n.s("style.languageHint"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(L10n.s("style.command.title"), systemImage: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: $state.config.commandMode)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Text(L10n.s("style.command.body"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
        }
        .onAppear { state.rescanApps() }
    }

    private var appStyles: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.s("style.perApp.title"), systemImage: "macwindow")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.s("style.perApp.body"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button(showAllApps ? L10n.s("style.recognizedOnly") : L10n.s("style.allApps")) {
                    showAllApps.toggle()
                }
                .buttonStyle(SoftButtonStyle())
            }

            TextField(L10n.s("style.search"), text: $appQuery)
                .textFieldStyle(.roundedBorder)

            if visibleApps.isEmpty {
                Text(state.config.appStyles.isEmpty
                     ? L10n.s("style.scanning")
                     : L10n.s("style.noApp"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, profile in
                        AppStyleRow(profile: profile)
                        if index < visibleApps.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var visibleApps: [AppStyleProfile] {
        let query = appQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = state.config.appStyles.filter { profile in
            query.isEmpty
                || profile.name.localizedStandardContains(query)
                || profile.bundleID.localizedStandardContains(query)
        }
        if !query.isEmpty || showAllApps { return matched }
        return matched.filter { $0.customized || $0.suggested != "auto" }
    }
}

private struct AppStyleRow: View {
    @EnvironmentObject var state: AppState
    let profile: AppStyleProfile

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Picker("", selection: styleBinding) {
                ForEach(StyleOption.all) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
        }
        .padding(.vertical, 8)
    }

    private var hint: String {
        if profile.customized, profile.style != profile.suggested {
            return L10n.s("style.suggestion", StyleOption.titled(profile.suggested))
        }
        return StyleOption.titled(profile.effectiveStyle)
    }

    private var styleBinding: Binding<String> {
        Binding(
            get: { profile.effectiveStyle },
            set: { state.setAppStyle(bundleID: profile.bundleID, name: profile.name, style: $0) }
        )
    }

    private var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: profile.name) ?? NSImage()
    }
}

private struct StyleCard: View {
    let option: StyleOption
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: option.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.violet)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.violet.opacity(0.12)))
                        )
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? Theme.violet : Color.secondary.opacity(0.4))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title).font(.system(size: 14, weight: .semibold))
                    Text(option.blurb)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.before)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .strikethrough(color: .secondary.opacity(0.4))
                        .lineLimit(2)
                    Text(option.after)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.04)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.violet : Theme.stroke, lineWidth: selected ? 2 : 1)
            )
            .shadow(color: (selected ? Theme.violet : .black).opacity(selected ? 0.18 : (hovering ? 0.08 : 0.04)), radius: 12, y: 4)
            .scaleEffect(hovering && !selected ? 1.01 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .onHover { value in withAnimation(.easeOut(duration: 0.15)) { hovering = value } }
    }
}
