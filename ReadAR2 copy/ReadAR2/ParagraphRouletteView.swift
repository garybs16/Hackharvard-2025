#if os(visionOS)
import SwiftUI

struct ParagraphRouletteStyle {
    var cardWidth: CGFloat
    var cardPadding: EdgeInsets
    var cardCornerRadius: CGFloat
    var cardShadowRadius: CGFloat
    var cardShadowOpacity: Double
    var spotlightColor: Color
    var spotlightBlurRadius: CGFloat
    var spotlightScale: CGFloat
    var minScale: CGFloat
    var maxScale: CGFloat
    var minOpacity: Double
    var maxOpacity: Double
    var maxRotationDegrees: Double
    var spacing: CGFloat
    var font: Font
    var foregroundColor: Color
    var backgroundBlurRadius: CGFloat
    var outerPadding: CGFloat

    init(
        cardWidth: CGFloat = 360,
        cardPadding: EdgeInsets = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
        cardCornerRadius: CGFloat = 28,
        cardShadowRadius: CGFloat = 16,
        cardShadowOpacity: Double = 0.12,
        spotlightColor: Color = Color.white.opacity(0.4),
        spotlightBlurRadius: CGFloat = 60,
        spotlightScale: CGFloat = 1.3,
        minScale: CGFloat = 0.80,
        maxScale: CGFloat = 1.0,
        minOpacity: Double = 0.3,
        maxOpacity: Double = 1.0,
        maxRotationDegrees: Double = 8,
        spacing: CGFloat = 40,
        font: Font = .system(size: 20, weight: .semibold, design: .rounded),
        foregroundColor: Color = .primary,
        backgroundBlurRadius: CGFloat = 36,
        outerPadding: CGFloat = 6
    ) {
        self.cardWidth = cardWidth
        self.cardPadding = cardPadding
        self.cardCornerRadius = cardCornerRadius
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowOpacity = cardShadowOpacity
        self.spotlightColor = spotlightColor
        self.spotlightBlurRadius = spotlightBlurRadius
        self.spotlightScale = spotlightScale
        self.minScale = minScale
        self.maxScale = maxScale
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.maxRotationDegrees = maxRotationDegrees
        self.spacing = spacing
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundBlurRadius = backgroundBlurRadius
        self.outerPadding = outerPadding
    }
}

fileprivate struct ParagraphItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ParagraphRouletteView<Content: View>: View {
    private let paragraphs: [ParagraphItem]
    @Binding private var activeID: UUID?
    private let style: ParagraphRouletteStyle
    private let onActiveChange: ((ParagraphItem) -> Void)?
    private let itemContent: (ParagraphItem, Bool) -> Content

    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var viewportRect: CGRect = .zero
    @State private var nearestID: UUID?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var dragActive: Bool = false
    @State private var snapping: Bool = false
    @State private var pendingNearestUpdate: Bool = false
    @State private var lastPrefUpdate: CFTimeInterval = 0

    private var ids: [UUID] {
        paragraphs.map(\.id)
    }

    /// Initializes the ParagraphRouletteView with:
    /// - Parameters
    ///   - activeID: Binding to the currently active UUID
    ///   - style: ParagraphRouletteStyle to customize appearance
    ///   - contentCount: number of items
    ///   - onActiveChange: closure called when activeID changes
    ///   - content: closure to render each item content view
    init(
        activeID: Binding<UUID?>,
        style: ParagraphRouletteStyle = ParagraphRouletteStyle(),
        contentCount: Int,
        onActiveChange: @escaping (UUID?) -> Void = { _ in },
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._activeID = activeID
        self.style = style
        self.paragraphs = (0..<contentCount).map { idx in ParagraphItem(id: deterministicUUID(from: "count-\(idx)"), index: idx, text: "") }
        self.onActiveChange = nil
        self.itemContent = { item, _ in content(item.index) }
    }

    /// Convenience initializer with default card content rendering from paragraphs as Strings
    init(
        paragraphs: [String],
        activeID: Binding<UUID?>,
        style: ParagraphRouletteStyle = ParagraphRouletteStyle(),
        onActiveChange: @escaping (UUID?) -> Void = { _ in }
    ) where Content == _DefaultParagraphCard {
        self._activeID = activeID
        self.style = style
        self.paragraphs = paragraphs.enumerated().map { idx, text in
            ParagraphItem(id: deterministicUUID(from: "string-\(idx)-\(text.prefix(24))"), index: idx, text: text)
        }
        self.onActiveChange = nil
        self.itemContent = { item, isActive in
            _DefaultParagraphCard(
                text: item.text,
                index: item.index,
                style: style,
                isActive: isActive
            )
        }
    }

    /// New initializer accepting [ParagraphItem]
    init(
        paragraphs: [ParagraphItem],
        activeID: Binding<UUID?>,
        style: ParagraphRouletteStyle = .init(),
        onActiveChange: ((ParagraphItem) -> Void)? = nil,
        @ViewBuilder itemContent: @escaping (ParagraphItem, Bool) -> Content
    ) {
        self.paragraphs = paragraphs
        self._activeID = activeID
        self.style = style
        self.onActiveChange = onActiveChange
        self.itemContent = itemContent
    }

    /// Convenience initializer for [ParagraphItem] without itemContent (defaults to DefaultCardView)
    init(
        paragraphs: [ParagraphItem],
        activeID: Binding<UUID?>,
        style: ParagraphRouletteStyle = .init(),
        onActiveChange: ((ParagraphItem) -> Void)? = nil
    ) where Content == AnyView {
        self.paragraphs = paragraphs
        self._activeID = activeID
        self.style = style
        self.onActiveChange = onActiveChange
        self.itemContent = { item, isActive in AnyView(DefaultCardView(item: item, isActive: isActive, style: style)) }
    }

    /// Convenience initializer accepting [String] with itemContent closure
    init(
        paragraphs: [String],
        activeID: Binding<UUID?>,
        style: ParagraphRouletteStyle = .init(),
        onActiveChange: ((ParagraphItem) -> Void)? = nil,
        @ViewBuilder itemContent: @escaping (ParagraphItem, Bool) -> Content
    ) {
        let items = paragraphs.enumerated().map { idx, text in
            ParagraphItem(id: deterministicUUID(from: "string-\(idx)-\(text.prefix(24))"), index: idx, text: text)
        }
        self.init(paragraphs: items, activeID: activeID, style: style, onActiveChange: onActiveChange, itemContent: itemContent)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: style.spacing) {
                        let effectiveWidth = min(style.cardWidth * 1.25, geo.size.width - style.outerPadding * 2)
                        ForEach(paragraphs, id: \.id) { item in
                            let isActive = activeID == item.id
                            itemContent(item, isActive)
                                .id(item.id)
                                .frame(width: effectiveWidth)
                                .background(
                                    GeometryReader { geoItem in
                                        Color.clear
                                            .preference(key: ParagraphItemFramePreferenceKey.self, value: [item.id: geoItem.frame(in: .named("roulette"))])
                                    }
                                )
                                .scaleEffect(scale(for: item.id))
                                .opacity(opacity(for: item.id))
                                .rotation3DEffect(
                                    .degrees(rotation(for: item.id)),
                                    axis: (x: 1, y: 0, z: 0),
                                    anchor: .center,
                                    perspective: 0.5
                                )
                                .zIndex(zIndex(for: item.id))
                                .background(backgroundBlur(for: item.id))
                                .cornerRadius(style.cardCornerRadius)
                                .contentShape(RoundedRectangle(cornerRadius: style.cardCornerRadius))
                                .shadow(color: Color.black.opacity(shadowOpacity(for: item.id)), radius: shadowRadius(for: item.id), x: 0, y: 6)
                                .accessibilityElement()
                                .accessibilityAddTraits(
                                    isActive ? .isSelected : []
                                )
                                .accessibilityLabel(accessibilityLabel(index: item.index, text: item.text))
                                .onTapGesture {
                                    onTap(id: item.id)
                                }
                        }
                    }
                    .padding(style.outerPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onPreferenceChange(ParagraphItemFramePreferenceKey.self) { value in
                        // Throttle updates to avoid multiple per frame storms
                        let now = CACurrentMediaTime()
                        if now - lastPrefUpdate < 0.03 { return } // ~33 Hz max
                        lastPrefUpdate = now

                        if itemFrames == value { return }
                        itemFrames = value
                        viewportRect = geo.frame(in: .named("roulette"))
                        if pendingNearestUpdate || snapping { return }
                        pendingNearestUpdate = true
                        DispatchQueue.main.async {
                            pendingNearestUpdate = false
                            updateNearest()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                dragActive = true
                            }
                            .onEnded { _ in
                                dragActive = false
                                updateNearest()
                                snapToNearest(animated: true)
                            }
                    )
                }
                .coordinateSpace(name: "roulette")
                .onAppear {
                    scrollProxy = proxy
                    DispatchQueue.main.async {
                        if activeID != nil {
                            snapToActive(animated: false)
                        } else {
                            snapToNearest(animated: false)
                        }
                    }
                }
                .onChange(of: activeID) { _ in
                    snapToActive(animated: true)
                }
            }
        }
    }

    private func accessibilityLabel(index: Int, text: String) -> Text {
        Text("Paragraph \(index + 1). ") + Text(text)
    }

    private func isActive(_ id: UUID) -> Bool {
        activeID == id
    }

    private func centerPoint() -> CGFloat {
        viewportRect.midY
    }

    private func distance(for id: UUID) -> CGFloat {
        guard let frame = itemFrames[id] else { return CGFloat.infinity }
        let centerY = frame.midY
        return abs(centerY - centerPoint()) / (viewportRect.height / 2)
    }

    private func scale(for id: UUID) -> CGFloat {
        let d = min(distance(for: id), 1)
        return style.minScale + (style.maxScale - style.minScale) * (1 - d)
    }

    private func opacity(for id: UUID) -> Double {
        // Keep the active item fully opaque
        if isActive(id) { return style.maxOpacity }
        // If any item is active, dim all others strongly regardless of distance
        if activeID != nil { return style.minOpacity }
        // Otherwise, fall back to distance-based opacity
        let d = min(distance(for: id), 1)
        return style.minOpacity + (style.maxOpacity - style.minOpacity) * (1 - d)
    }

    private func rotation(for id: UUID) -> Double {
        let d = min(distance(for: id), 1)
        let sign = frameSign(for: id)
        return sign * style.maxRotationDegrees * Double(d)
    }

    private func frameSign(for id: UUID) -> Double {
        guard let frame = itemFrames[id] else { return 1 }
        let centerY = frame.midY
        return centerY < centerPoint() ? 1 : -1
    }

    private func zIndex(for id: UUID) -> Double {
        let d = min(distance(for: id), 1)
        return 1 - Double(d)
    }

    private func shadowOpacity(for id: UUID) -> Double {
        isActive(id) ? style.cardShadowOpacity : 0
    }

    private func shadowRadius(for id: UUID) -> CGFloat {
        isActive(id) ? style.cardShadowRadius : 0
    }

    @ViewBuilder
    private func backgroundBlur(for id: UUID) -> some View {
        if isActive(id) && distance(for: id) < 0.25 {
            Color.clear
                .glassBackgroundEffect()
                .cornerRadius(style.cardCornerRadius)
                .blur(radius: style.backgroundBlurRadius)
        } else {
            Color.clear
        }
    }

    private func updateNearest() {
        guard !dragActive && !snapping else { return }
        // If no explicit selection yet, default to the first paragraph rather than the nearest
        if activeID == nil, let first = paragraphs.first?.id {
            nearestID = first
            activeID = first
            if let change = onActiveChange, let item = paragraphs.first {
                change(item)
            }
            return
        }

        let validDistances = ids.compactMap { id -> (UUID, CGFloat)? in
            guard itemFrames[id] != nil else { return nil }
            return (id, distance(for: id))
        }
        guard !validDistances.isEmpty else { return }
        let nearestCandidate = validDistances.min(by: { $0.1 < $1.1 })?.0
        if nearestCandidate != nearestID {
            nearestID = nearestCandidate
            // Do not override an existing explicit selection
            // (activeID is only set here if it is still nil)
        }
    }

    private func onTap(id: UUID) {
        if activeID == id {
            activeID = nil
            if let change = onActiveChange {
                change(ParagraphItem(id: id, index: 0, text: ""))
            }
            return
        }

        activeID = id

        // Notify change with the actual item if available
        if let change = onActiveChange, let item = paragraphs.first(where: { $0.id == id }) {
            change(item)
        }

        // Exception: Do not force-center the first, second, or last items
        if let item = paragraphs.first(where: { $0.id == id }) {
            let isException = (item.index == 0) || (item.index == 1) || (item.index == paragraphs.count - 1)
            if !isException {
                snapToActive(animated: true)
            }
        } else {
            // Fallback: center if item not found
            snapToActive(animated: true)
        }
    }

    private func snapToNearest(animated: Bool) {
        guard let nearest = nearestID else { return }
        scrollTo(nearest, animated: animated)
    }

    private func snapToActive(animated: Bool) {
        guard let active = activeID else { return }
        scrollTo(active, animated: animated)
    }

    /// Programmatically scrolls to the specified item UUID, centering it.
    /// - Parameters:
    ///   - id: UUID of the item to scroll to; pass nil to do nothing.
    ///   - animated: Whether scrolling should animate.
    func scrollTo(_ id: UUID?, animated: Bool = true) {
        guard let id = id, let proxy = scrollProxy else { return }
        // Determine anchor: keep first paragraph at top, others centered
        let anchor: UnitPoint = {
            if let item = paragraphs.first(where: { $0.id == id }), item.index == 0 {
                return .top
            } else {
                return .center
            }
        }()
        snapping = true
        let clearSnapping: () -> Void = {
            // Clear snapping on the next runloop to avoid layout feedback loops
            DispatchQueue.main.async { self.snapping = false }
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: anchor)
            }
            clearSnapping()
        } else {
            proxy.scrollTo(id, anchor: anchor)
            clearSnapping()
        }
    }
}

fileprivate func deterministicUUID(from seed: String) -> UUID {
    var hasher = Hasher()
    hasher.combine(seed)
    let h1 = UInt64(bitPattern: Int64(hasher.finalize()))
    var hasher2 = Hasher()
    hasher2.combine(seed + "::2")
    let h2 = UInt64(bitPattern: Int64(hasher2.finalize()))
    var bytes = [UInt8](repeating: 0, count: 16)
    withUnsafeBytes(of: h1.bigEndian) { raw in
        for i in 0..<8 { bytes[i] = raw[i] }
    }
    withUnsafeBytes(of: h2.bigEndian) { raw in
        for i in 0..<8 { bytes[8 + i] = raw[i] }
    }
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}

struct _DefaultParagraphCard: View {
    let text: String
    let index: Int
    let style: ParagraphRouletteStyle
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassBackgroundEffect()
                .shadow(color: Color.black.opacity(isActive ? style.cardShadowOpacity : 0), radius: style.cardShadowRadius, x: 0, y: 6)

            Text(text)
                .font(style.font)
                .foregroundColor(style.foregroundColor)
                .multilineTextAlignment(.leading)
                .padding(style.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("Paragraph \(index + 1): ") + Text(text.prefix(50) + (text.count > 50 ? "…" : "")))
    }
}

private struct DefaultCardView: View {
    let item: ParagraphItem
    let isActive: Bool
    let style: ParagraphRouletteStyle
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paragraph \(item.index + 1)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(style.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackgroundEffect()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(isActive ? 0.25 : 0.1), radius: isActive ? 18 : 8, x: 0, y: isActive ? 12 : 6)
        }
    }
}

#if DEBUG
struct ParagraphRouletteView_Previews: PreviewProvider {
    @State static var active: UUID? = nil
    static let paragraphs: [String] = [
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.",
        "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit.",
        "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.",
        "Sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.",
        "Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam.",
        "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur."
    ]

    static var previews: some View {
        Group {
            ParagraphRouletteView(
                paragraphs: paragraphs,
                activeID: $active
            )
            .frame(width: 400, height: 700)

            ParagraphRouletteView(
                paragraphs: paragraphs,
                activeID: $active,
                style: ParagraphRouletteStyle(
                    cardWidth: 320,
                    cardPadding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
                    cardCornerRadius: 18,
                    cardShadowRadius: 10,
                    cardShadowOpacity: 0.2,
                    spotlightColor: Color.blue.opacity(0.3),
                    spotlightBlurRadius: 50,
                    spotlightScale: 1.1,
                    minScale: 0.7,
                    maxScale: 1.0,
                    minOpacity: 0.25,
                    maxOpacity: 1.0,
                    maxRotationDegrees: 12,
                    spacing: 32,
                    font: .system(size: 18, weight: .medium, design: .rounded),
                    foregroundColor: .blue,
                    backgroundBlurRadius: 28
                )
            )
            .frame(width: 360, height: 700)
        }
    }
}
#endif

#endif



