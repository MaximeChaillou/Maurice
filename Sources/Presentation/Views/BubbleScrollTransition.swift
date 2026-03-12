import SwiftUI

extension View {
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
