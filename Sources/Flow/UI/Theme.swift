import AppKit
import SwiftUI

enum Theme {
    static let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let violet = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let pink = Color(red: 0.93, green: 0.28, blue: 0.60)
    static let gradient = LinearGradient(
        colors: [indigo, violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardFill = Color(nsColor: .controlBackgroundColor)
    static let stroke = Color.primary.opacity(0.07)
}

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct FlowMark: View {
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Theme.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: Theme.violet.opacity(0.35), radius: size * 0.18, y: size * 0.06)
    }
}

struct StatusPill: View {
    let state: EngineState
    let text: String

    private var color: Color {
        switch state {
        case .ready: return .green
        case .loading: return .orange
        case .error: return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if state == .loading {
                ProgressView().controlSize(.mini)
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.13)))
        .foregroundStyle(color)
    }
}

struct KeyCap: View {
    let label: String
    var onDark = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(onDark ? Color.white.opacity(0.22) : Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(onDark ? Color.white.opacity(0.35) : Color.primary.opacity(0.12))
            )
            .shadow(color: .black.opacity(onDark ? 0.15 : 0.06), radius: 0, y: 1.5)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : (hovering ? 0.08 : 0)))
                )
                .contentShape(Circle())
                .onHover { hovering = $0 }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.gradient))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Theme.violet.opacity(0.3), radius: 8, y: 3)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.13 : 0.07)))
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

struct Page<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    accessory
                }
                content
            }
            .padding(.horizontal, 40)
            .padding(.top, 52)
            .padding(.bottom, 40)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

extension Page where Accessory == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

enum Fmt {
    static let locale = Locale(identifier: "de_DE")

    static func relative(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "gerade eben" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Heute" }
        if calendar.isDateInYesterday(date) { return "Gestern" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    static func minutes(_ value: Double) -> String {
        if value < 1 { return "< 1 Min" }
        if value < 60 { return "\(Int(value.rounded())) Min" }
        return String(format: "%.1f Std", value / 60).replacingOccurrences(of: ".", with: ",")
    }

    static func clock(_ seconds: TimeInterval) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
