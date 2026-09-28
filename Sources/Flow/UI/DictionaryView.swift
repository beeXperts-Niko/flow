import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject var state: AppState
    @State private var heardAs = ""
    @State private var term = ""
    @FocusState private var heardFocused: Bool

    private var items: [DictionaryItem] { DictionaryItem.parse(state.config.dictionary) }

    var body: some View {
        Page(title: L10n.s("dictionary.title"), subtitle: L10n.s("dictionary.subtitle")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    field(icon: "ear", placeholder: L10n.s("dictionary.heardPlaceholder"), text: $heardAs)
                        .focused($heardFocused)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    field(icon: "character.cursor.ibeam", placeholder: L10n.s("dictionary.termPlaceholder"), text: $term)
                    Button {
                        add()
                    } label: {
                        Label(L10n.s("dictionary.add"), systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(heardAs.trimmingCharacters(in: .whitespaces).isEmpty
                              && term.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
                HStack(alignment: .top, spacing: 18) {
                    explainer(
                        icon: "ear",
                        title: L10n.s("dictionary.withHeard.title"),
                        text: L10n.s("dictionary.withHeard.body")
                    )
                    explainer(
                        icon: "text.badge.checkmark",
                        title: L10n.s("dictionary.spellingOnly.title"),
                        text: L10n.s("dictionary.spellingOnly.body")
                    )
                }
                Divider()
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.s("dictionary.learn.title"))
                            .font(.system(size: 13, weight: .medium))
                        Text(L10n.s("dictionary.learn.detail"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $state.config.learnEdits)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .card()

            if items.isEmpty {
                EmptyHint(
                    icon: "character.book.closed",
                    title: L10n.s("dictionary.emptyTitle"),
                    text: L10n.s("dictionary.emptyBody")
                )
                .card()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(items.count == 1 ? L10n.s("dictionary.countOne") : L10n.s("dictionary.count", items.count))
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
        let cleanHeard = heardAs.trimmingCharacters(in: .whitespaces)
        let cleanTerm = term.trimmingCharacters(in: .whitespaces)
        let entry: DictionaryItem
        if cleanTerm.isEmpty {
            guard !cleanHeard.isEmpty else { return }
            entry = DictionaryItem(term: cleanHeard, heardAs: "")
        } else if cleanHeard.isEmpty || cleanHeard == cleanTerm {
            entry = DictionaryItem(term: cleanTerm, heardAs: "")
        } else {
            entry = DictionaryItem(term: cleanTerm, heardAs: cleanHeard)
        }
        var current = items
        current.removeAll {
            $0.term.caseInsensitiveCompare(entry.term) == .orderedSame && $0.heardAs == entry.heardAs
        }
        current.insert(entry, at: 0)
        withAnimation(.snappy) {
            state.config.dictionary = DictionaryItem.serialize(current)
        }
        term = ""
        heardAs = ""
        heardFocused = true
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
            if !item.heardAs.isEmpty {
                Text(item.heardAs)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(item.term)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.violet.opacity(0.12)))
                .foregroundStyle(Theme.violet)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(IconButtonStyle())
            .opacity(hovering ? 1 : 0)
            .help(L10n.s("dictionary.remove"))
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
