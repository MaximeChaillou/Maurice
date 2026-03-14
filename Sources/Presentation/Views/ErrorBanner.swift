import SwiftUI

@Observable
@MainActor
final class ErrorState {
    var message: String?

    func show(_ message: String) {
        self.message = message
    }
}

struct ErrorBannerModifier: ViewModifier {
    @State var errorState = ErrorState()

    func body(content: Content) -> some View {
        content
            .environment(errorState)
            .overlay(alignment: .bottom) {
                if let message = errorState.message {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(message)
                            .font(.callout)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            withAnimation { errorState.message = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(5))
                            withAnimation { errorState.message = nil }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: errorState.message)
    }
}

extension View {
    func withErrorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}
