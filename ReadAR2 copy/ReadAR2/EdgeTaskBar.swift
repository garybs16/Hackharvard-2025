#if os(visionOS)
import SwiftUI

public struct EdgeTaskBar: View {
    // Public configuration
    public var showsLabels: Bool = false
    public var autoHideDelay: TimeInterval = 1.2
    public var width: CGFloat = 92            // expanded width
    public var handleWidth: CGFloat = 18      // invisible hover handle
    public var cornerRadius: CGFloat = 22
    public var spacing: CGFloat = 14
    public var alwaysVisible: Bool = false
    public var startRevealed: Bool = false

    // Buttons exposed as closures (UI only)
    public var onPrev: () -> Void = {}
    public var onRestart: () -> Void = {}
    public var onRewind: () -> Void = {}
    public var onPlayPause: () -> Void = {}
    public var onForward: () -> Void = {}
    public var onNext: () -> Void = {}
    public var onAutoAdvanceToggle: () -> Void = {}
    public var onOpenMore: () -> Void = {}

    // Internal state
    @State private var revealed = false
    @State private var hovering = false
    @State private var hideTask: Task<Void, Never>?

    public init(
        showsLabels: Bool = false,
        autoHideDelay: TimeInterval = 1.2,
        width: CGFloat = 92,
        handleWidth: CGFloat = 18,
        cornerRadius: CGFloat = 22,
        spacing: CGFloat = 14,
        alwaysVisible: Bool = false,
        startRevealed: Bool = false,
        onPrev: @escaping () -> Void = {},
        onRestart: @escaping () -> Void = {},
        onRewind: @escaping () -> Void = {},
        onPlayPause: @escaping () -> Void = {},
        onForward: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {},
        onAutoAdvanceToggle: @escaping () -> Void = {},
        onOpenMore: @escaping () -> Void = {}
    ) {
        self.showsLabels = showsLabels
        self.autoHideDelay = autoHideDelay
        self.width = width
        self.handleWidth = handleWidth
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.alwaysVisible = alwaysVisible
        self.startRevealed = startRevealed
        self.onPrev = onPrev
        self.onRestart = onRestart
        self.onRewind = onRewind
        self.onPlayPause = onPlayPause
        self.onForward = onForward
        self.onNext = onNext
        self.onAutoAdvanceToggle = onAutoAdvanceToggle
        self.onOpenMore = onOpenMore
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            // 1) Invisible hover handle hugging the right edge
            Color.white.opacity(0.001) // nearly invisible but hit-testable
                .frame(width: handleWidth)
                .frame(maxHeight: .infinity, alignment: .trailing) // cover full height for reliable hover
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .onHover { inside in
                    if alwaysVisible { return }
                    hovering = inside
                    if inside { reveal() } else { scheduleHide() }
                }

            // 2) The task bar panel
            VStack(spacing: spacing) {
                TaskBarButton(systemName: "chevron.up", title: showsLabels ? "Prev" : nil, action: onPrev)
                TaskBarButton(systemName: "arrow.counterclockwise", title: showsLabels ? "Restart" : nil, action: onRestart)
                TaskBarButton(systemName: "gobackward.5", title: showsLabels ? "Back 5s" : nil, action: onRewind)
                TaskBarButton(systemName: "play.fill", title: showsLabels ? "Play/Pause" : nil, action: onPlayPause)
                TaskBarButton(systemName: "goforward.5", title: showsLabels ? "Fwd 5s" : nil, action: onForward)
                TaskBarButton(systemName: "chevron.down", title: showsLabels ? "Next" : nil, action: onNext)
                TaskBarButton(
                    systemName: "sparkles",
                    title: showsLabels ? "Gemini" : nil,
                    iconForegroundStyle: AnyShapeStyle(LinearGradient(
                        colors: [
                            .red, .orange, .yellow, .green, .blue, .indigo, .purple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )),
                    iconSize: 24,
                    action: onAutoAdvanceToggle
                )
                Divider().opacity(0.3)
                TaskBarButton(systemName: "ellipsis.circle", title: showsLabels ? "More" : nil, action: onOpenMore)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .glassBackgroundEffect()
                    .shadow(color: .black.opacity((revealed || alwaysVisible) ? 0.25 : 0.15), radius: (revealed || alwaysVisible) ? 18 : 8, x: 0, y: 6)
            )
            .opacity((revealed || alwaysVisible) ? 1 : 0)
            .offset(x: (revealed || alwaysVisible) ? 0 : width + 12)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: revealed)
            .onHover { inside in
                if alwaysVisible { return }
                hovering = inside
                if inside { reveal() } else { scheduleHide() }
            }
            .hoverEffectDisabled()
            .zIndex(1000)
            .accessibilityHidden(!(revealed || alwaysVisible))
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .onDisappear { hideTask?.cancel() }
        .onAppear {
            if startRevealed || alwaysVisible { revealed = true }
        }
    }

    private func reveal() {
        hideTask?.cancel()
        if !revealed { revealed = true }
    }

    private func scheduleHide() {
        if alwaysVisible { return }
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(autoHideDelay * 1_000_000_000))
            if !hovering { revealed = false }
        }
    }
}
#endif

