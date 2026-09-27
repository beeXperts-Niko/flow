import SwiftUI

struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case microphone
        case accessibility
        case tryIt
    }

    @EnvironmentObject var state: AppState
    @State private var step: Step = .welcome
    @State private var sample = ""
    @FocusState private var sampleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack {
                if step != .welcome {
                    Button("Zurück") { go(-1) }.buttonStyle(SoftButtonStyle())
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.rawValue) { item in
                        Capsule()
                            .fill(item == step ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.primary.opacity(0.15)))
                            .frame(width: item == step ? 22 : 7, height: 7)
                    }
                }
                Spacer()
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .animation(.snappy, value: step)
        }
        .frame(width: 640, height: 560)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [Theme.violet.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 22) {
                FlowMark(size: 84)
                VStack(spacing: 8) {
                    Text("Willkommen bei Flow")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(state.config.correctsWithOpenAI
                         ? "Sprich natürlich. Flow schreibt sauberen Text in jede App.\nWhisper hört auf diesem Mac, OpenAI formuliert."
                         : "Sprich natürlich. Flow schreibt sauberen Text in jede App –\nkomplett lokal mit Whisper und Qwen.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 14) {
                    feature("bolt.fill", "Dreimal schneller als Tippen", "Halte eine Taste, sprich, lass los.")
                    feature("sparkles", "Formuliert automatisch", "Füllwörter raus, Zeichensetzung rein, passender Stil.")
                    state.config.correctsWithOpenAI
                        ? feature("lock.fill", "Aufnahme bleibt hier", "Nur der erkannte Text geht zur Korrektur an OpenAI, mit deinem Schlüssel.")
                        : feature("lock.fill", "Privat", "Audio und Text verlassen deinen Mac nie.")
                }
                .padding(.top, 8)
            }
            .padding(40)
        case .microphone:
            permissionStep(
                icon: "mic.fill",
                title: "Mikrofon erlauben",
                text: "Flow hört nur zu, solange du die Taste hältst. Die Aufnahme wird direkt auf diesem Mac verarbeitet.",
                granted: state.micGranted,
                button: "Mikrofon erlauben",
                action: state.requestMicrophone,
                note: nil
            )
        case .accessibility:
            permissionStep(
                icon: "accessibility",
                title: "Bedienungshilfen erlauben",
                text: "Damit erkennt Flow die Diktiertaste in jeder App und fügt den Text an der Cursorposition ein.",
                granted: state.axGranted,
                button: "Systemeinstellungen öffnen",
                action: state.openAccessibility,
                note: "Schalte Flow in der Liste ein. Steht Flow schon drin, einmal aus- und wieder einschalten."
            )
        case .tryIt:
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Probier es aus")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    HStack(spacing: 8) {
                        Text("Klick ins Feld, halte")
                        KeyCap(label: state.config.resolvedHotkey.symbol)
                        Text("und sag etwas.")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                }
                ZStack(alignment: .topLeading) {
                    if sample.isEmpty {
                        Text("„Ähm, erinnere mich bitte morgen um zehn an das Angebot für Müller.“")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $sample)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .focused($sampleFocused)
                }
                .frame(height: 150)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.cardFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(sampleFocused ? Theme.violet.opacity(0.6) : Theme.stroke, lineWidth: sampleFocused ? 2 : 1)
                )
                HStack(spacing: 8) {
                    StatusPill(
                        state: state.engineState,
                        text: state.engineState != .ready
                            ? state.engineStatus
                            : state.polishAvailable
                                ? (state.config.correctsWithOpenAI ? "OpenAI ist bereit" : "Qwen ist bereit")
                                : "Whisper ist bereit"
                    )
                    if state.phase == .listening {
                        MirroredWaveform(levels: state.levels, bars: 15, color: Theme.violet)
                            .frame(width: 80, height: 22)
                    }
                }
            }
            .padding(.horizontal, 56)
            .onAppear { sampleFocused = true }
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.violet)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.violet.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(text).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
        }
    }

    private func permissionStep(
        icon: String,
        title: String,
        text: String,
        granted: Bool,
        button: String,
        action: @escaping () -> Void,
        note: String?
    ) -> some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(granted ? AnyShapeStyle(Color.green.opacity(0.15)) : AnyShapeStyle(Theme.violet.opacity(0.12)))
                    .frame(width: 110, height: 110)
                Image(systemName: granted ? "checkmark" : icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(granted ? AnyShapeStyle(Color.green) : AnyShapeStyle(Theme.gradient))
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: granted)
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            if granted {
                Label("Erlaubt", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button(button, action: action).buttonStyle(PrimaryButtonStyle())
                if let note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
        }
        .padding(40)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Los geht’s"
        case .tryIt: return "Fertig"
        default: return "Weiter"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .microphone: return state.micGranted
        default: return true
        }
    }

    private func primaryAction() {
        if step == .tryIt {
            state.finishOnboarding()
        } else {
            go(1)
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = next }
    }
}
