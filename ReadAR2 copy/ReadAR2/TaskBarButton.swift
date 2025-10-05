import SwiftUI

public struct TaskBarButton: View {
    public let systemName: String
    public let title: String?
    public let iconForegroundStyle: AnyShapeStyle?
    public let iconSize: CGFloat
    public let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    public init(systemName: String, title: String? = nil, iconForegroundStyle: AnyShapeStyle? = nil, iconSize: CGFloat = 20, action: @escaping () -> Void) {
        self.systemName = systemName
        self.title = title
        self.iconForegroundStyle = iconForegroundStyle
        self.iconSize = iconSize
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolVariant(isPressed ? .fill : .none)
                    .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.04 : 1.0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isPressed)
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isHovering)
                    .modifier(IconForegroundStyleModifier(style: iconForegroundStyle))
                if let title = title {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .opacity(0.9)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle()) // Ensure minimum hit target
            .padding(4)
            .background(
                Group {
                    #if os(visionOS)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(isHovering ? 0.9 : 0.6))
                        .glassBackgroundEffect()
                    #else
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(isHovering ? 0.9 : 0.6))
                    #endif
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .pressAction { pressed in isPressed = pressed }
        .accessibilityLabel(Text(title ?? systemName))
    }
}

// Simple press detector helper to get pressed state animations
private struct PressModifier: ViewModifier {
    let onChange: (Bool) -> Void
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onChange(true) }
                    .onEnded { _ in onChange(false) }
            )
    }
}

private extension View {
    func pressAction(_ onChange: @escaping (Bool) -> Void) -> some View {
        modifier(PressModifier(onChange: onChange))
    }
}

private struct IconForegroundStyleModifier: ViewModifier {
    let style: AnyShapeStyle?
    func body(content: Content) -> some View {
        if let style {
            content.foregroundStyle(style)
        } else {
            content
        }
    }
}
