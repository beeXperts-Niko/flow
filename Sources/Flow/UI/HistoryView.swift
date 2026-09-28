import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var confirmClear = false

    var body: some View {
        Page(title: L10n.s("history.title"), subtitle: L10n.s("history.subtitle")) {
            HStack(spacing: 10) {
                SearchField(text: $query)
                if !state.history.isEmpty {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label(L10n.s("history.clear"), systemImage: "trash")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        } content: {
            if state.history.isEmpty {
                EmptyHint(
                    icon: "clock.arrow.circlepath",
                    title: L10n.s("history.emptyTitle"),
                    text: L10n.s("history.emptyBody")
                )
                .card()
            } else if groups.isEmpty {
                EmptyHint(icon: "magnifyingglass", title: L10n.s("history.noResults"), text: L10n.s("history.noResultsBody", query))
                    .card()
            } else {
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.day(group.day))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)
                        ForEach(group.entries) { entry in
                            HistoryRow(entry: entry, mode: .full)
                        }
                    }
                    .card(padding: 10)
                }
            }
        }
        .confirmationDialog(L10n.s("history.deleteTitle"), isPresented: $confirmClear) {
            Button(L10n.s("history.delete"), role: .destructive) {
                withAnimation { state.clearHistory() }
            }
        } message: {
            Text(L10n.s("history.deleteBody"))
        }
    }

    private var groups: [(day: Date, entries: [HistoryEntry])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = needle.isEmpty ? state.history : state.history.filter {
            $0.text.lowercased().contains(needle)
                || $0.raw.lowercased().contains(needle)
                || ($0.app?.lowercased().contains(needle) ?? false)
        }
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { (day: $0, entries: grouped[$0] ?? []) }
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField(L10n.s("history.search"), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 220)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}
