import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject var state: AppState
    @State private var term = ""
    @State private var heardAs = ""
    @FocusState private var termFocused: Bool

    private var items: [DictionaryItem] { DictionaryItem.parse(state.config.dictionary) }

    var body: some View {
        Page(title: "Wörterbuch", subtitle: "Namen, Marken und Fachbegriffe, die Flow immer richtig schreiben soll.") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    field(icon: "character.cursor.ibeam", placeholder: "Schreibweise, z. B. VEMA", text: $term)
                        .focused($termFocused)
                    field(icon: "ear", placeholder: "Wird erkannt als (optional)", text: $heardAs)
                    Button {
                        add()
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
                HStack(alignment: .top, spacing: 18) {
                    explainer(
                        icon: "text.badge.checkmark",
                        title: "Nur Schreibweise",
                        text: "Flow gibt den Begriff an Whisper und die Korrektur weiter."
                    )
                    explainer(
                        icon: "arrow.left.arrow.right",
                        title: "Mit Erkennung",
                        text: "Was Whisper falsch hört, wird immer exakt ersetzt, z. B. „flow app“ → „Flow“."
                    )
                }
            }
            .card()

            if items.isEmpty {
                EmptyHint(
                    icon: "character.book.closed",
                    title: "Noch keine Einträge",
                    text: "Füge Namen von Kunden, Kollegen oder Produkten hinzu."
                )
                .card()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(items.count) Einträge")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    ForEach(items) { item in
                        DictionaryRow(item: item) { remove(item) }
                    }
                }
                .card(padding: 10)
            }
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(add)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    private func explainer(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.violet)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        let cleanTerm = term.trimmingCharacters(in: .whitespaces)
        guard !cleanTerm.isEmpty else { return }
        var current = items
        let cleanHeard = heardAs.trimmingCharacters(in: .whitespaces)
        current.removeAll { $0.term.caseInsensitiveCompare(cleanTerm) == .orderedSame && $0.heardAs == cleanHeard }
        current.insert(DictionaryItem(term: cleanTerm, heardAs: cleanHeard), at: 0)
        withAnimation(.snappy) {
            state.config.dictionary = DictionaryItem.serialize(current)
        }
        term = ""
        heardAs = ""
        termFocused = true
    }

    private func remove(_ item: DictionaryItem) {
        let remaining = items.filter { !($0.term == item.term && $0.heardAs == item.heardAs) }
        withAnimation(.snappy) {
            state.config.dictionary = DictionaryItem.serialize(remaining)
        }
    }
}

private struct DictionaryRow: View {
    let item: DictionaryItem
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(item.term)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.violet.opacity(0.12)))
                .foregroundStyle(Theme.violet)
            if !item.heardAs.isEmpty {
                Image(systemName: "arrow.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text("„\(item.heardAs)“")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(IconButtonStyle())
            .opacity(hovering ? 1 : 0)
            .help("Entfernen")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.045 : 0))
        )
        .onHover { hovering = $0 }
    }
}
