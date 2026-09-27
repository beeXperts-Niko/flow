import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Page(title: greeting, subtitle: state.config.correctsWithOpenAI
             ? "Sprich einfach. Whisper bleibt auf diesem Mac, die Korrektur läuft über deinen OpenAI-Schlüssel."
             : "Sprich einfach. Flow schreibt – privat, mit Whisper und Qwen auf diesem Mac.") {
            if !state.hasPermissions {
                PermissionBanner()
            }
            if state.micGranted && !state.axGranted {
                AccessibilityRepairCard()
            }
            HeroCard()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                StatCard(icon: "text.word.spacing", tint: Theme.violet, title: "Wörter diktiert", value: Fmt.number(state.totalWords))
                StatCard(icon: "hourglass", tint: Theme.pink, title: "Zeit gespart", value: Fmt.minutes(state.minutesSaved))
                StatCard(icon: "speedometer", tint: Theme.indigo, title: "Tempo", value: state.speakingWPM > 0 ? "\(state.speakingWPM) WPM" : "–")
                StatCard(icon: "calendar", tint: .orange, title: "Diktate heute", value: "\(state.todayCount)")
            }
            recentCard
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let salutation = hour < 11 ? "Guten Morgen" : (hour < 18 ? "Hallo" : "Guten Abend")
        if SnapshotMode.isActive { return salutation }
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? salutation : "\(salutation), \(first)"
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Zuletzt")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if !state.history.isEmpty {
                    Button("Alle anzeigen") { state.section = .history }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            if state.history.isEmpty {
                EmptyHint(
                    icon: "waveform.badge.mic",
                    title: "Noch keine Diktate",
                    text: "Klick in ein Textfeld, halte \(state.config.resolvedHotkey.title) und sprich los."
                )
            } else {
                ForEach(state.history.prefix(5)) { entry in
                    HistoryRow(entry: entry, mode: .relative)
                }
            }
        }
        .card(padding: 12)
    }
}

private struct HeroCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let listening = state.phase == .listening
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text(listening ? "FLOW HÖRT ZU" : "DIKTIEREN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 10) {
                    Text("Halte")
                    KeyCap(label: state.config.resolvedHotkey.symbol, onDark: true)
                    Text("und sprich.")
                }
                .font(.system(size: 24, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 6) {
                    tip("hand.tap", "Doppeltipp für freies Sprechen")
                    tip("escape", "Esc bricht ab")
                    tip("wand.and.stars", "Text markieren und sagen, was sich ändern soll")
                }
            }
            Spacer(minLength: 0)
            Button {
                state.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 118, height: 118)
                        .scaleEffect(listening ? 1 + (state.levels.last ?? 0) * 0.25 : 1)
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 94, height: 94)
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    Image(systemName: listening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(listening ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.gradient))
                }
                .animation(.easeOut(duration: 0.1), value: state.levels)
            }
            .buttonStyle(.plain)
            .disabled(!state.engineReady && !listening)
            .help(listening ? "Aufnahme beenden" : "Frei sprechen starten")
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.gradient)
                GeometryReader { proxy in
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 280, height: 280)
                        .offset(x: proxy.size.width - 230, y: -120)
                    Circle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 180, height: 180)
                        .offset(x: proxy.size.width * 0.45, y: proxy.size.height - 70)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        )
        .shadow(color: Theme.violet.opacity(0.3), radius: 18, y: 8)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 16)
            Text(text).font(.system(size: 12.5))
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

private struct StatCard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Theme.gradient)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
