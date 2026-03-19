import SwiftUI

struct AskButton: View {
    var runner: SkillRunner
    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var conversationLines: [AskConversationLine] = []
    @State private var lastSyncedCount = 0
    @FocusState private var isSearchFieldFocused: Bool

    private var showResponse: Bool {
        !conversationLines.isEmpty || runner.isRunning || !runner.currentText.isEmpty
    }

    private var groupedSegments: [AskConversationSegment] {
        var segments: [AskConversationSegment] = []
        var toolBuffer: [AskConversationLine] = []

        func flushTools() {
            if !toolBuffer.isEmpty {
                segments.append(.toolGroup(toolBuffer))
                toolBuffer = []
            }
        }

        for line in conversationLines {
            if line.kind == .tool {
                toolBuffer.append(line)
            } else {
                flushTools()
                segments.append(.single(line))
            }
        }
        flushTools()
        return segments
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded && showResponse {
                responsePanel
                Divider()
            }

            inputBar
        }
        .glassEffect(
            .regular.interactive(),
            in: isExpanded ? .rect(cornerRadius: 20) : .rect(cornerRadius: 28)
        )
        .frame(maxWidth: isExpanded ? .infinity : 56)
        .onChange(of: runner.isRunning) {
            if runner.isRunning {
                if let label = runner.skillLabel {
                    conversationLines.append(AskConversationLine(
                        text: "Exécution du skill « \(label) »…", kind: .system
                    ))
                    lastSyncedCount = 0
                }
                if !isExpanded {
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                        isExpanded = true
                    }
                }
            } else {
                syncRunnerOutput()
            }
        }
        .onChange(of: runner.outputLines.count) {
            syncRunnerOutput()
        }
        .onChange(of: isExpanded) {
            if isExpanded {
                syncRunnerOutput()
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 0) {
            if isExpanded {
                TextField("Demander à Claude...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .font(.title3)
                    .padding(.leading, 20)
                    .padding(.vertical, 14)
                    .onSubmit { submitPrompt() }
                    .onExitCommand { collapse() }
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    if isExpanded {
                        collapseAndReset()
                    } else {
                        isExpanded = true
                    }
                }
                if isExpanded {
                    isSearchFieldFocused = true
                }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .leading) {
                if runner.isRunning && isExpanded {
                    HStack(spacing: 6) {
                        Button {
                            runner.stop()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)

                        ProgressView()
                            .controlSize(.small)
                    }
                    .offset(x: -50)
                    .transition(.opacity)
                }
            }
        }
        .frame(height: 56)
    }

    // MARK: - Response panel

    private var responsePanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(groupedSegments.enumerated()), id: \.element.id) { _, segment in
                        segmentView(segment)
                    }

                    if runner.isRunning && runner.currentText.isEmpty
                        && runner.outputLines.count <= lastSyncedCount {
                        AskThinkingView()
                            .id("thinking")
                    }

                    if !runner.currentText.isEmpty {
                        Text(runner.currentText)
                            .font(AskFont.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("streaming")
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 450)
            .overlay(alignment: .topTrailing) {
                if !conversationLines.isEmpty {
                    Button {
                        withAnimation { clearConversation() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: conversationLines.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: runner.currentText) {
                if !runner.currentText.isEmpty {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: runner.outputLines.count) {
                syncRunnerOutput()
                scrollToBottom(proxy)
            }
            .onChange(of: runner.isRunning) {
                if !runner.isRunning {
                    syncRunnerOutput()
                    scrollToBottom(proxy)
                }
            }
        }
    }

    // MARK: - Segment views

    @ViewBuilder
    private func segmentView(_ segment: AskConversationSegment) -> some View {
        switch segment {
        case .single(let line):
            conversationLineView(line)
        case .toolGroup(let lines):
            AskToolGroupView(lines: lines)
        }
    }

    @ViewBuilder
    private func conversationLineView(_ line: AskConversationLine) -> some View {
        switch line.kind {
        case .user:
            Text("→ \(line.text)")
                .font(AskFont.semiBold(size: 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, line == conversationLines.first ? 0 : 8)
        case .assistant:
            assistantLineView(line.text)
        case .tool:
            Text(line.text)
                .font(AskFont.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .system:
            Text(line.text)
                .font(AskFont.caption)
                .foregroundColor(.gray)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .error:
            Text(line.text)
                .font(AskFont.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func submitPrompt() {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !runner.isRunning else { return }

        conversationLines.append(AskConversationLine(text: prompt, kind: .user))
        searchText = ""

        runner.runPrompt(prompt, workingDirectory: AppSettings.rootDirectory)
    }

    private func syncRunnerOutput() {
        if runner.outputLines.count < lastSyncedCount {
            lastSyncedCount = 0
        }
        let newLines = runner.outputLines.dropFirst(lastSyncedCount)
        for line in newLines {
            let kind: AskConversationLine.Kind = switch line.kind {
            case .assistant: .assistant
            case .tool: .tool
            case .system: .system
            case .error: .error
            }
            conversationLines.append(AskConversationLine(text: line.text, kind: kind))
        }
        lastSyncedCount = runner.outputLines.count
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = conversationLines.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func collapse() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            isExpanded = false
            searchText = ""
        }
    }

    private func collapseAndReset() {
        isExpanded = false
        searchText = ""
    }

    @ViewBuilder
    private func assistantLineView(_ text: String) -> some View {
        let heading = InlineMarkdownParser.headingLevel(text)
        if heading.level > 0 {
            Text(InlineMarkdownParser.parse(heading.content))
                .font(AskFont.bold(size: headingSize(heading.level)))
                .foregroundStyle(.blue)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        } else {
            Text(InlineMarkdownParser.parse(text))
                .font(AskFont.body)
                .foregroundStyle(.blue)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 22
        case 2: 18
        default: 15
        }
    }

    private func clearConversation() {
        runner.stop()
        runner.outputLines = []
        runner.currentText = ""
        conversationLines = []
        lastSyncedCount = 0
    }
}
