import SwiftUI

struct AskButton: View {
    var runner: SkillRunner
    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var conversationLines: [ConversationLine] = []
    @State private var lastSyncedCount = 0
    @FocusState private var isSearchFieldFocused: Bool

    private var showResponse: Bool {
        !conversationLines.isEmpty || runner.isRunning || !runner.currentText.isEmpty
    }

    private var groupedSegments: [ConversationSegment] {
        var segments: [ConversationSegment] = []
        var toolBuffer: [ConversationLine] = []

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
                    conversationLines.append(ConversationLine(text: "Exécution du skill « \(label) »…", kind: .user))
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

                    if !runner.currentText.isEmpty {
                        Text(runner.currentText)
                            .font(.system(.body, design: .monospaced))
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
    private func segmentView(_ segment: ConversationSegment) -> some View {
        switch segment {
        case .single(let line):
            conversationLineView(line)
        case .toolGroup(let lines):
            ToolGroupView(lines: lines)
        }
    }

    @ViewBuilder
    private func conversationLineView(_ line: ConversationLine) -> some View {
        switch line.kind {
        case .user:
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, line == conversationLines.first ? 0 : 8)
        case .assistant:
            assistantLineView(line.text)
        case .tool:
            Text(line.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .system:
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .error:
            Text(line.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func submitPrompt() {
        let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !runner.isRunning else { return }

        conversationLines.append(ConversationLine(text: prompt, kind: .user))
        searchText = ""

        runner.runPrompt(prompt, workingDirectory: AppSettings.rootDirectory)
    }

    private func syncRunnerOutput() {
        // Runner was reset (new run started) — reset sync counter
        if runner.outputLines.count < lastSyncedCount {
            lastSyncedCount = 0
        }
        let newLines = runner.outputLines.dropFirst(lastSyncedCount)
        for line in newLines {
            let kind: ConversationLine.Kind = switch line.kind {
            case .assistant: .assistant
            case .tool: .tool
            case .system: .system
            case .error: .error
            }
            conversationLines.append(ConversationLine(text: line.text, kind: kind))
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
        let heading = headingLevel(text)
        if heading.level > 0 {
            Text(parseInlineMarkdown(heading.content))
                .font(.system(headingStyle(heading.level), design: .monospaced).weight(.bold))
                .foregroundStyle(.blue)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        } else {
            Text(parseInlineMarkdown(text))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.blue)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headingLevel(_ text: String) -> (level: Int, content: String) {
        InlineMarkdownParser.headingLevel(text)
    }

    private func headingStyle(_ level: Int) -> Font.TextStyle {
        switch level {
        case 1: .title
        case 2: .title2
        default: .title3
        }
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        InlineMarkdownParser.parse(text)
    }

    private func clearConversation() {
        runner.stop()
        runner.outputLines = []
        runner.currentText = ""
        conversationLines = []
        lastSyncedCount = 0
    }
}

// MARK: - Tool group (collapsible)

private struct ToolGroupView: View {
    let lines: [ConversationLine]
    @State private var isOpen = false

    private var summary: String {
        let count = lines.count
        return "\(count) outil\(count > 1 ? "s" : "") utilisé\(count > 1 ? "s" : "")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text(summary)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Inline Markdown parser

private enum InlineMarkdownParser {
    static func headingLevel(_ text: String) -> (level: Int, content: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var level = 0
        for char in trimmed {
            if char == "#" { level += 1 } else { break }
        }
        guard level > 0, level <= 3, trimmed.dropFirst(level).first == " " else {
            return (0, text)
        }
        return (level, String(trimmed.dropFirst(level + 1)))
    }

    static func parse(_ text: String) -> AttributedString {
        parseBold(text[...])
    }

    private static func parseBold(_ remaining: Substring) -> AttributedString {
        var result = AttributedString()
        var rest = remaining

        while !rest.isEmpty {
            if let openRange = rest.range(of: "**") {
                let before = rest[rest.startIndex..<openRange.lowerBound]
                if !before.isEmpty { result.append(parseItalic(before)) }
                let afterOpen = rest[openRange.upperBound...]
                if let closeRange = afterOpen.range(of: "**") {
                    var bold = parseItalic(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    for run in bold.runs {
                        bold[run.range].inlinePresentationIntent =
                            (bold[run.range].inlinePresentationIntent ?? []).union(.stronglyEmphasized)
                    }
                    result.append(bold)
                    rest = afterOpen[closeRange.upperBound...]
                } else {
                    result.append(AttributedString("**"))
                    rest = afterOpen
                }
            } else {
                result.append(parseItalic(rest))
                break
            }
        }
        return result
    }

    private static func parseItalic(_ remaining: Substring) -> AttributedString {
        var result = AttributedString()
        var rest = remaining

        while !rest.isEmpty {
            if let openRange = rest.range(of: "*") {
                let before = rest[rest.startIndex..<openRange.lowerBound]
                if !before.isEmpty { result.append(AttributedString(before)) }
                let afterOpen = rest[openRange.upperBound...]
                if let closeRange = afterOpen.range(of: "*") {
                    var italic = AttributedString(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    italic.inlinePresentationIntent = .emphasized
                    result.append(italic)
                    rest = afterOpen[closeRange.upperBound...]
                } else {
                    result.append(AttributedString("*"))
                    rest = afterOpen
                }
            } else {
                result.append(AttributedString(rest))
                break
            }
        }
        return result
    }
}

// MARK: - Models

private struct ConversationLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: Kind

    enum Kind {
        case user, assistant, tool, system, error
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private enum ConversationSegment {
    case single(ConversationLine)
    case toolGroup([ConversationLine])

    var id: String {
        switch self {
        case .single(let line): line.id.uuidString
        case .toolGroup(let lines): lines.first?.id.uuidString ?? UUID().uuidString
        }
    }
}
