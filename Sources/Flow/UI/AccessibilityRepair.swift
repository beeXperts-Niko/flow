import SwiftUI

/// Geführte Reparatur, wenn der Schalter in den Systemeinstellungen an ist, Flow aber trotzdem „nein“ sagt.
struct AccessibilityRepairCard: View {
    @EnvironmentObject var state: AppState
    @State private var waiting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bedienungshilfen reparieren")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Nach einem Update gilt der alte Schalter oft nicht mehr für die neue Flow-Version.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                repairStep(1, "Öffne Bedienungshilfen und suche Flow in der Liste.")
                repairStep(2, "Schalter aus, kurz warten, wieder an – oder Flow entfernen und neu hinzufügen.")
                repairStep(3, "Zurück zu Flow: Der Status unten wechselt auf „Erlaubt“.")
            }

            HStack(spacing: 10) {
                Button {
                    waiting = true
                    state.openAccessibility()
                } label: {
                    Label("Systemeinstellungen öffnen", systemImage: "gearshape")
                }
                .buttonStyle(PrimaryButtonStyle())

                if waiting && !state.axGranted {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Warte auf Freigabe…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if state.axGranted {
                    Label("Freigegeben", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.orange.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.orange.opacity(0.25)))
        .onChange(of: state.axGranted) { _, granted in
            if granted { waiting = false }
        }
    }

    private func repairStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.violet))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
