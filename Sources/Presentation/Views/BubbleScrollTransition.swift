import SwiftUI

private struct InteractiveHoverModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.1 : 0))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func interactiveHover() -> some View {
        modifier(InteractiveHoverModifier())
    }

    func pointerOnHover() -> some View {
        onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    func bubbleScrollTransition() -> some View {
        scrollTransition(.animated(.spring(duration: 0.3, bounce: 0.2))) { content, phase in
            content
                .scaleEffect(x: 1, y: phase.isIdentity ? 1 : 0.75)
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .offset(y: phase.value * 16)
                .opacity(phase.isIdentity ? 1 : 0.5)
        }
    }
}
