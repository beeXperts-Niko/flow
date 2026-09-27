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

    static let all: [StyleOption] = [
        StyleOption(
            id: "auto", title: "Automatisch", icon: "sparkles",
            blurb: "Erkennt selbst, ob du eine Mail, Liste oder kurze Nachricht diktierst.",
            before: "ähm kannst du mir morgen die zahlen schicken",
            after: "Kannst du mir morgen die Zahlen schicken?"
        ),
        StyleOption(
            id: "literal", title: "Wörtlich", icon: "text.quote",
            blurb: "Nur Füllwörter und Zeichensetzung. Deine Formulierung bleibt.",
            before: "also das passt so halt für mich",
            after: "Das passt so für mich."
        ),
        StyleOption(
            id: "email", title: "E-Mail", icon: "envelope",
            blurb: "Anrede, Absätze und Gruß – bereit zum Senden.",
            before: "hallo frau berg danke für ihre rückmeldung viele grüße dieter",
            after: "Hallo Frau Berg,\n\ndanke für Ihre Rückmeldung.\n\nViele Grüße\nDieter"
        ),
        StyleOption(
            id: "chat", title: "Nachricht", icon: "bubble.left.and.bubble.right",
            blurb: "Locker und kurz für Slack, WhatsApp und Teams.",
            before: "bin in fünf minuten da ähm bring kaffee mit",
            after: "Bin in 5 Minuten da, bring Kaffee mit!"
        ),
        StyleOption(
            id: "notes", title: "Notizen", icon: "list.bullet.rectangle",
            blurb: "Klare Punkte und Absätze für Gedanken und Protokolle.",
            before: "punkte fürs meeting budget zeitplan und neue kampagne",
            after: "Punkte fürs Meeting:\n- Budget\n- Zeitplan\n- Neue Kampagne"
        ),
        StyleOption(
            id: "code", title: "Coding", icon: "chevron.left.forwardslash.chevron.right",
            blurb: "Bezeichner, Schreibweise und Symbole bleiben erhalten.",
            before: "funktion get user by id mit parameter id",
            after: "getUserById(id)"
        )
    ]
}

struct StyleView: View {
    @EnvironmentObject var state: AppState
    @State private var appQuery = ""
    @State private var showAllApps = false

    var body: some View {
        Page(title: "Stil", subtitle: "Flow setzt den Stil nach dem Programm im Vordergrund. Den Standard nutzt es, wenn keins erkannt wird.") {
            if let app = state.frontApp {
                Text("Gerade vorn: \(app.name) · \(StyleOption.titled(state.effectiveStyle(for: app)))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Standardstil")
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
                Label("Eigene Anweisung", systemImage: "text.bubble")
                    .font(.system(size: 14, weight: .semibold))
                Text("Gilt für jedes Diktat, zum Beispiel: Sie-Form, kurze Sätze, keine Emojis.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    if state.config.instructions.isEmpty {
                        Text("Schreibe in der Sie-Form und halte Sätze kurz.")
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
                    Label("Sprache", systemImage: "globe")
                        .font(.system(size: 14, weight: .semibold))
                    Picker("", selection: $state.config.language) {
                        Text("Automatisch").tag("auto")
                        Text("Deutsch").tag("de")
                        Text("Englisch").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    Text("Fest eingestellt erkennt Whisper genauer.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Befehlsmodus", systemImage: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: $state.config.commandMode)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Text("Markiere Text und sag zum Beispiel „mach das freundlicher“ oder „übersetz das ins Englische“.")
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
                    Label("Pro Programm", systemImage: "macwindow")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Die Liste kommt aus dem Programme-Ordner und wächst mit den Apps, die du öffnest. Den Stil kannst du hier ändern.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button(showAllApps ? "Nur erkannte" : "Alle Programme") {
                    showAllApps.toggle()
                }
                .buttonStyle(SoftButtonStyle())
            }

            TextField("Programm suchen", text: $appQuery)
                .textFieldStyle(.roundedBorder)

            if visibleApps.isEmpty {
                Text(state.config.appStyles.isEmpty
                     ? "Programme werden gelesen…"
                     : "Kein Programm für diese Suche.")
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
            return "Vorschlag: \(StyleOption.titled(profile.suggested))"
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
