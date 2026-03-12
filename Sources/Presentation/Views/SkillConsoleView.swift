import SwiftUI

struct SkillConsoleView: View {
    @Bindable var runner: SkillRunner
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar — always visible
            headerBar

            if isExpanded {
                expandedContent
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            if runner.isRunning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Text(runner.lastAssistantLine)
                .font(.system(.caption, design: .monospaced).bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.blue)

            Spacer()

            if runner.isRunning {
                Button {
                    runner.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Arrêter")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Expanded console

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(runner.outputLines) { line in
                            Text(line.text)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(line.kind == .assistant ? .bold : .regular)
                                .foregroundStyle(line.kind == .assistant ? .blue : line.kind == .tool ? .secondary : .primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !runner.currentText.isEmpty {
                            Text(runner.currentText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("streaming")
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 200)
                .onChange(of: runner.outputLines.count) {
                    if let last = runner.outputLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: runner.currentText) {
                    if !runner.currentText.isEmpty {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }
}
