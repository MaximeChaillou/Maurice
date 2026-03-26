import SwiftUI

struct ConsolePanel: View {
    var viewModel: ConsoleViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTerminalView(viewModel: viewModel)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: isExpanded ? .infinity : 0
                )
                .clipped()
                .padding(.top, isExpanded ? 8 : 0)
                .padding(.horizontal, isExpanded ? 8 : 0)

            toggleButton
        }
        .glassEffect(
            .regular.interactive(),
            in: isExpanded ? .rect(cornerRadius: 20) : .rect(cornerRadius: 28)
        )
        .frame(
            maxWidth: isExpanded ? .infinity : 56,
            maxHeight: isExpanded ? 500 : 56
        )
        .onChange(of: viewModel.shouldExpand) {
            if viewModel.shouldExpand, !isExpanded {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    isExpanded = true
                }
                viewModel.shouldExpand = false
            }
        }
        .onChange(of: viewModel.isRunning) {
            if !viewModel.isRunning, isExpanded {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    isExpanded = false
                }
            }
        }
    }

    // MARK: - Toggle button

    private var toggleButton: some View {
        HStack(spacing: 0) {
            if isExpanded {
                Spacer()
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    isExpanded.toggle()
                }
                if isExpanded, !viewModel.isRunning {
                    viewModel.restart()
                }
            } label: {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Console Claude")
        }
        .frame(height: 56)
    }
}
