import Cocoa
import Combine
import SwiftUI

final class OverlayController {
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()
    private var leaveWork: DispatchWorkItem?
    private weak var state: AppState?
    /// Screen-space drag anchors – avoid SwiftUI translation (jitters when the panel moves).
    private var dragStartOrigin: NSPoint?
    private var dragStartMouse: NSPoint?
    /// Bottom-center of the panel. Only changes when the user drags, so resizing never drifts.
    private var anchor: NSPoint?
    private var mode: Mode = .collapsed
    private var shrinkWork: DispatchWorkItem?
    /// The pointer left while the bar had to stay open (dictation or translate menu).
    private var pointerLeft = false

    private enum Mode: Int {
        case collapsed, bar, menu

        var size: NSSize {
            switch self {
            case .collapsed: return NSSize(width: 64, height: 48)
            case .bar: return NSSize(width: 228, height: 72)
            case .menu: return NSSize(width: 236, height: 478)
            }
        }
    }

    init(state: AppState) {
        self.state = state
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 64, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        // Always stay above the Dock / other system chrome.
        panel.orderFrontRegardless()

        let root = OverlayView(
            onHoverChange: { [weak self] hovering in
                self?.setHovered(hovering)
            },
            onDragChanged: { [weak self] in
                self?.dragChanged()
            },
            onDragEnded: { [weak self] in
                self?.dragEnded()
            }
        )
        .environmentObject(state)
        let host = NSHostingView(rootView: root)
        // Otherwise the hosting view resizes the panel on its own and fights our placement.
        host.sizingOptions = []
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        Publishers.CombineLatest3(state.$phase, state.$widgetHovered, state.$widgetTranslateOpen)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.state?.widgetDragging != true else { return }
                self?.updateMode()
            }
            .store(in: &cancellables)

        show()
    }

    func show() {
        mode = targetMode()
        applyFrame()
        panel.orderFrontRegardless()
    }

    private func setHovered(_ hovering: Bool) {
        guard let state else { return }
        if hovering {
            pointerLeft = false
            leaveWork?.cancel()
            leaveWork = nil
            if !state.widgetHovered { state.widgetHovered = true }
            return
        }
        // Dragging reports a leave as the panel moves. Ignore that.
        // A leave during dictation or while the menu is open must still be remembered,
        // otherwise the bar stays up after the phase returns to idle.
        guard !state.widgetDragging else { return }
        leaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.finishLeave()
        }
        leaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
    }

    private func finishLeave() {
        guard let state, !state.widgetDragging else { return }
        if state.widgetTranslateOpen || state.isBusy {
            pointerLeft = true
            return
        }
        pointerLeft = false
        state.widgetHovered = false
    }

    private func dragChanged() {
        guard let state else { return }
        let mouse = NSEvent.mouseLocation
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouse = mouse
            leaveWork?.cancel()
            // Size stays put while dragging – expanding mid-drag causes jumps.
            if !state.widgetDragging {
                state.widgetDragging = true
            }
        }
        guard let start = dragStartOrigin, let mouse0 = dragStartMouse else { return }
        let origin = NSPoint(
            x: start.x + (mouse.x - mouse0.x),
            y: start.y + (mouse.y - mouse0.y)
        )
        var frame = panel.frame
        frame.origin = clamped(origin, size: frame.size)
        // display:false avoids full redraw flicker while tracking
        panel.setFrame(frame, display: false, animate: false)
    }

    private func dragEnded() {
        dragStartOrigin = nil
        dragStartMouse = nil
        anchor = NSPoint(x: panel.frame.midX, y: panel.frame.minY)
        persistAnchor()
        state?.widgetDragging = false
        state?.widgetHovered = true
        updateMode()
    }

    private func persistAnchor() {
        guard let state, let anchor else { return }
        guard let vf = (screenForPanel() ?? NSScreen.main)?.visibleFrame,
              vf.width > 1, vf.height > 1 else { return }
        var config = state.config
        config.widgetX = Double((anchor.x - vf.minX) / vf.width)
        config.widgetY = Double((anchor.y - vf.minY) / vf.height)
        state.config = config
    }

    private func targetMode() -> Mode {
        guard let state else { return .collapsed }
        if state.widgetTranslateOpen { return .menu }
        if state.widgetHovered || state.phase != .idle { return .bar }
        return .collapsed
    }

    /// Grow the panel immediately so SwiftUI can animate inside it;
    /// shrink only after the collapse animation has finished.
    private func updateMode() {
        releaseHoverIfPointerLeft()
        let target = targetMode()
        shrinkWork?.cancel()
        shrinkWork = nil
        guard target != mode else { return }
        if target.rawValue > mode.rawValue {
            mode = target
            applyFrame()
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.targetMode() == target else { return }
                self.mode = target
                self.applyFrame()
            }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: work)
        }
    }

    /// Hover state can stick after a dictation: the pointer left while the phase
    /// was busy, and that leave used to be ignored. Once idle, trust the pointer.
    private func releaseHoverIfPointerLeft() {
        guard let state else { return }
        guard state.widgetHovered, state.phase == .idle else { return }
        guard !state.widgetTranslateOpen, !state.widgetDragging else { return }
        let outside = !panel.frame.contains(NSEvent.mouseLocation)
        guard pointerLeft || outside else { return }
        pointerLeft = false
        state.widgetHovered = false
    }

    private func resolvedAnchor() -> NSPoint {
        if let anchor { return anchor }
        let screen = screenForSavedPosition() ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let point: NSPoint
        if let x = state?.config.widgetX, let y = state?.config.widgetY {
            point = NSPoint(x: vf.minX + CGFloat(x) * vf.width, y: vf.minY + CGFloat(y) * vf.height)
        } else {
            point = NSPoint(x: vf.midX, y: vf.minY + 12)
        }
        let rounded = NSPoint(x: point.x.rounded(), y: point.y.rounded())
        anchor = rounded
        return rounded
    }

    private func applyFrame() {
        let size = mode.size
        let anchor = resolvedAnchor()
        let vf = (NSScreen.screens.first { NSMouseInRect(anchor, $0.frame, false) } ?? NSScreen.main)?.visibleFrame
        var x = anchor.x
        var y = anchor.y
        if let vf {
            // Clamp horizontally with the bar footprint for every mode: the menu panel is wider only
            // by transparent margin, so it may overhang the edge instead of shifting the bar sideways.
            let half = Mode.bar.size.width / 2
            x = min(max(x, vf.minX + 8 + half), vf.maxX - 8 - half)
            let limits = verticalLimits(for: size, in: vf)
            y = min(max(y, limits.minY), limits.maxY)
        }
        let frame = NSRect(
            x: (x - size.width / 2).rounded(),
            y: y.rounded(),
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true, animate: false)
        panel.orderFrontRegardless()
    }

    private func screenForPanel() -> NSScreen? {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
    }

    private func screenForSavedPosition() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    /// The panel keeps empty space under the pill. That space may cross into the Dock
    /// so the pill itself can sit on the Dock or on the screen edge.
    private func verticalLimits(for size: NSSize, in visible: NSRect) -> (minY: CGFloat, maxY: CGFloat) {
        let minY = visible.minY - OverlayView.pillBottomInset
        let maxY = visible.maxY - size.height - 8
        return (minY, max(minY, maxY))
    }

    /// Keep the pill inside the visible frame: above the menu bar, and down to the Dock or screen edge.
    private func clamped(_ origin: NSPoint, size: NSSize, in visible: NSRect? = nil) -> NSPoint {
        let vf: NSRect
        if let visible {
            vf = visible
        } else if let screen = screenForPanel() ?? NSScreen.main {
            vf = screen.visibleFrame
        } else {
            return origin
        }
        let padX: CGFloat = 8
        let minX = vf.minX + padX
        let maxX = vf.maxX - size.width - padX
        let limits = verticalLimits(for: size, in: vf)
        let minY = limits.minY
        let maxY = limits.maxY
        return NSPoint(
            x: min(max(origin.x, minX), max(minX, maxX)),
            y: min(max(origin.y, minY), max(minY, maxY))
        )
    }
}

struct OverlayView: View {
    @EnvironmentObject var state: AppState
    var onHoverChange: (Bool) -> Void = { _ in }
    var onDragChanged: () -> Void = {}
    var onDragEnded: () -> Void = {}

    private var expanded: Bool {
        state.widgetHovered || state.phase != .idle || state.widgetTranslateOpen
    }

    static let pillBottomInset: CGFloat = 18
    private static let morph = Animation.spring(response: 0.38, dampingFraction: 0.84)

    var body: some View {
        // Bottom-pinned overlay: the pill keeps its position even for the frame where the content
        // is already taller than the panel (the panel grows one runloop later).
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { content }
            .animation(state.widgetDragging ? nil : Self.morph, value: expanded)
            .animation(state.widgetDragging ? nil : Self.morph, value: state.widgetTranslateOpen)
            .animation(state.widgetDragging ? nil : .easeOut(duration: 0.2), value: state.phase)
            .environment(\.colorScheme, .dark)
    }

    private var content: some View {
        VStack(spacing: 8) {
            if state.widgetTranslateOpen {
                TranslateMenuCard(
                    languages: translateTargets,
                    nativeId: state.config.nativeLanguage,
                    onPick: { id in
                        state.widgetTranslateOpen = false
                        state.translateSelection(id)
                    },
                    onClose: { state.widgetTranslateOpen = false }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .bottom))
                    )
                )
            }
            pill
        }
        // Generous hover/drag target around the visible shapes, without changing layout.
        .padding(10)
        .contentShape(Rectangle())
        .onHover(perform: onHoverChange)
        .simultaneousGesture(widgetDrag)
        .padding(-10)
        .fixedSize()
        .padding(.bottom, Self.pillBottomInset)
    }

    private var widgetDrag: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { _ in onDragChanged() }
            .onEnded { _ in onDragEnded() }
    }

    /// One capsule that morphs between chip and bar, so expand/collapse is a smooth resize.
    private var pill: some View {
        ZStack {
            if expanded {
                HStack(spacing: 8) { phaseContent }
                    .padding(.horizontal, horizontalInset)
                    .frame(width: pillWidth, height: 38)
                    .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.06)))
            } else {
                chipBars
                    .transition(.opacity.animation(.easeOut(duration: 0.12)))
            }
        }
        .frame(width: expanded ? pillWidth : 36, height: expanded ? 38 : 19)
        .background(
            Capsule(style: .continuous)
                .fill(Color(white: expanded ? 0.09 : 0.05).opacity(expanded ? 0.96 : 0.62))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(expanded ? 0.08 : 0.12), lineWidth: 0.5)
        )
        .clipShape(Capsule(style: .continuous))
        .softDropShadow(.bar)
        .contentShape(Capsule())
        .help(expanded ? "" : L10n.s("overlay.drag", state.config.resolvedHotkey.symbol))
    }

    static let recordingPillWidth: CGFloat = 196

    private var isRecording: Bool {
        if case .listening = state.phase { return true }
        return false
    }

    private var pillWidth: CGFloat {
        isRecording ? Self.recordingPillWidth : 172
    }

    /// Idle: round 26pt controls sit concentric in the capsule ends ((38 - 26) / 2).
    private var horizontalInset: CGFloat {
        switch state.phase {
        case .idle: return 6
        case .listening: return 14
        default: return 12
        }
    }

    private var chipBars: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(state.engineReady ? 0.55 : 0.28))
                    .frame(width: 2, height: CGFloat([5, 9, 6][index]))
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .idle:
            idleToolbar
        case .listening:
            HStack(spacing: 8) {
                PulsingDot()
                MirroredWaveform(levels: state.levels, bars: 15)
                    .frame(width: 72, height: 20)
                Text(Fmt.clock(state.elapsed))
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
                iconChip(system: "stop.fill", tint: .red, action: state.toggleRecording)
            }
        case .transcribing:
            statusRow(icon: nil, title: L10n.s("overlay.recognizing")) {
                ThinkingWave().frame(width: 32, height: 14)
            }
        case .polishing(let raw):
            if state.rewriting {
                statusRow(icon: nil, title: L10n.s("overlay.rewrite")) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [Theme.violet, Theme.pink], startPoint: .top, endPoint: .bottom))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [Theme.violet, Theme.pink], startPoint: .top, endPoint: .bottom))
                    Text(raw)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer(minLength: 0)
                }
            }
        case .translating(let code):
            statusRow(icon: nil, title: "→ \(code.uppercased())") {
                ThinkingWave().frame(width: 32, height: 14)
            }
        case .done(let text, let pasted):
            HStack(spacing: 8) {
                Image(systemName: pasted ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                    .foregroundStyle(pasted ? .green : .orange)
                Text(pasted ? L10n.s("overlay.inserted") : L10n.s("overlay.copied"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .notice(let message):
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(.white.opacity(0.65))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func statusRow<Leading: View>(icon: String?, title: String, @ViewBuilder leading: () -> Leading) -> some View {
        HStack(spacing: 8) {
            leading()
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }

    private var idleToolbar: some View {
        HStack(spacing: 6) {
            Button(action: state.toggleRecording) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.gradient))
            }
            .buttonStyle(.plain)
            .disabled(!state.engineReady)
            .opacity(state.engineReady ? 1 : 0.45)
            .help(L10n.s("overlay.dictate"))

            Text(state.config.resolvedHotkey.symbol)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    state.widgetTranslateOpen.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: state.widgetTranslateOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.78))
                .frame(height: 26)
                .padding(.horizontal, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(state.widgetTranslateOpen ? 0.14 : 0.08))
                )
            }
            .buttonStyle(.plain)
            .help(L10n.s("overlay.translateHelp"))

            Spacer(minLength: 2)

            iconChip(system: "gearshape", tint: .white.opacity(0.7)) {
                state.widgetTranslateOpen = false
                state.openMain(.settings)
            }
            .help(L10n.s("menu.settings"))
        }
    }

    /// Native language first (foreign text → my language), then the foreign targets.
    private var translateTargets: [TranslateLanguage] {
        let native = state.config.nativeLanguage
        let preferred = ["en", "de", "fr", "es", "it", "pt", "nl", "pl", "tr"]
        let order = [native] + preferred.filter { $0 != native }
        return order.compactMap { id in TranslateLanguage.all.first { $0.id == id } }
    }

    private func iconChip(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

/// Kleines Modal über der Leiste – Sprachen als Codes, ohne Emoji-Flaggen.
struct TranslateMenuCard: View {
    let languages: [TranslateLanguage]
    var nativeId: String = ""
    let onPick: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.s("overlay.translate"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Text(L10n.s("overlay.replace"))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                ForEach(languages) { lang in
                    let isNative = lang.id == nativeId
                    Button {
                        onPick(lang.id)
                    } label: {
                        HStack(spacing: 10) {
                            Text(lang.id.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(isNative ? 1 : 0.9))
                                .frame(width: 28, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isNative ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(lang.name)
                                    .font(.system(size: 12.5, weight: isNative ? .semibold : .medium))
                                    .foregroundStyle(.white.opacity(isNative ? 0.95 : 0.88))
                                if isNative {
                                    Text(L10n.s("overlay.mine"))
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.38))
                                }
                            }
                            .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TranslateRowStyle())

                    if isNative {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 196)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.1).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .softDropShadow(.menu)
    }
}

private struct TranslateRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0))
            )
    }
}

private enum SoftShadowStyle {
    case bar, menu

    var cornerRadius: CGFloat {
        switch self {
        case .bar: return 999
        case .menu: return 14
        }
    }
}

private extension View {
    func softDropShadow(_ style: SoftShadowStyle) -> some View {
        modifier(SoftDropShadow(style: style))
    }
}

/// Layered blurred copies of the shape: a tight contact edge plus progressively wider, fainter
/// layers. Sums to a smooth gaussian falloff that follows the contour.
/// Needs ~18pt free space below and ~14pt at the sides, or the panel clips it.
private struct SoftDropShadow: ViewModifier {
    let style: SoftShadowStyle

    private static let layers: [(opacity: Double, blur: CGFloat, y: CGFloat)] = [
        (0.26, 0.6, 0.5),
        (0.14, 2.5, 1.5),
        (0.16, 7.0, 4.0)
    ]

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                ForEach(Self.layers.indices, id: \.self) { index in
                    let layer = Self.layers[index]
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(layer.opacity))
                        .blur(radius: layer.blur)
                        .offset(y: layer.y)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct PulsingDot: View {
    @State private var on = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(on ? 1.2 : 0.55)
                .opacity(on ? 0 : 1)
            Circle().fill(Color.red).frame(width: 7, height: 7)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { on = true }
        }
    }
}

struct MirroredWaveform: View {
    let levels: [CGFloat]
    var bars = 23
    var color: Color = .white

    var body: some View {
        HStack(alignment: .center, spacing: 2.4) {
            ForEach(0..<bars, id: \.self) { index in
                let distance = abs(index - bars / 2)
                let source = max(0, levels.count - 1 - distance)
                let value = levels.isEmpty ? 0 : levels[source]
                let envelope = 1 - CGFloat(distance) / CGFloat(bars) * 1.1
                Capsule()
                    .fill(color.opacity(0.45 + 0.55 * envelope))
                    .frame(width: 2.4, height: max(3, 3 + value * 20 * envelope))
            }
        }
        .animation(.easeOut(duration: 0.1), value: levels)
    }
}

struct ThinkingWave: View {
    var bars = 7
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<bars, id: \.self) { index in
                    let phase = sin(time * 6.5 - Double(index) * 0.7)
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: 2.5, height: 3 + 10 * CGFloat(0.5 + 0.5 * phase))
                }
            }
        }
    }
}
