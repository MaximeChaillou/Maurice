import SwiftUI

struct ConsolePanel: View {
    var viewModel: ConsoleViewModel
    @State private var isExpanded = false
    @State private var terminalVisible = false

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTerminalView(viewModel: viewModel)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: isExpanded ? .infinity : 0
                )
                .clipped()
                .opacity(terminalVisible ? 1 : 0)
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
            if viewModel.shouldExpand {
                if !isExpanded {
                    expand()
                }
                viewModel.shouldExpand = false
            }
        }
        .onChange(of: viewModel.isRunning) {
            if !viewModel.isRunning, isExpanded {
                collapse()
            }
        }
    }

    // MARK: - Expand / Collapse

    private func expand() {
        terminalVisible = false
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            isExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            terminalVisible = true
            viewModel.focusTerminal()
        }
    }

    private func collapse() {
        terminalVisible = false
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            isExpanded = false
        }
    }

    // MARK: - Toggle button

    private var toggleButton: some View {
        HStack(spacing: 0) {
            if isExpanded {
                Spacer()
            }

            Button {
                if isExpanded {
                    collapse()
                } else {
                    expand()
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
