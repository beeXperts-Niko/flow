import SwiftUI

struct HistoryRow: View {
    enum Mode {
        case compact
        case relative
        case full
    }

    let entry: HistoryEntry
    var mode: Mode = .relative
    @EnvironmentObject var state: AppState
    @State private var hovering = false
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.text)
                        .font(.system(size: mode == .compact ? 12.5 : 13.5))
                        .lineLimit(expanded ? nil : (mode == .compact ? 2 : 3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    meta
                }
                Button(action: copy) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(IconButtonStyle())
                .opacity(hovering || copied ? 1 : 0)
                .help("Kopieren")
            }
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gesprochen")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(entry.raw)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
                    HStack(spacing: 8) {
                        Button("Text kopieren", action: copy).buttonStyle(SoftButtonStyle())
                        Button("Rohtext kopieren") { state.copy(entry.raw) }.buttonStyle(SoftButtonStyle())
                        Spacer()
                        Button(role: .destructive) {
                            withAnimation(.snappy) { state.deleteHistory(entry.id) }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .buttonStyle(SoftButtonStyle())
                        .foregroundStyle(.red)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, mode == .compact ? 8 : 11)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(hovering || expanded ? 0.045 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if mode == .compact {
                copy()
            } else {
                withAnimation(.snappy(duration: 0.25)) { expanded.toggle() }
            }
        }
    }

    private var meta: some View {
        HStack(spacing: 5) {
            Text(mode == .full ? Fmt.time(entry.date) : Fmt.relative(entry.date))
            if let app = entry.app, !app.isEmpty {
                Text("·")
                Text(app)
            }
            if entry.wasCommand == true {
                Text("·")
                Image(systemName: "wand.and.stars")
                Text("umgeschrieben")
            }
            if mode != .compact {
                Text("·")
                Text(entry.words == 1 ? "1 Wort" : "\(entry.words) Wörter")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
    }

    private func copy() {
        state.copy(entry.text)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { copied = false }
        }
    }
}
