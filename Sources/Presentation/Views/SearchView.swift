import SwiftUI

struct SearchView: View {
    let onOpenMeeting: (String) -> Void
    let onOpenPerson: (String) -> Void
    let searchService: SemanticSearchService
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Rechercher…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit { triggerSearch() }
                    .onChange(of: query) { triggerSearch() }
                    .onExitCommand { isPresented = false }

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if results.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView(
                    "Recherche",
                    systemImage: "magnifyingglass",
                    description: Text("Tapez un terme pour rechercher dans les réunions, personnes et tâches.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    Button {
                        openResult(result)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: result.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(result.context)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if !result.snippet.isEmpty {
                                    Text(result.highlightedSnippet())
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            isSearchFocused = true
            searchService.rebuildIndex()
        }
    }

    private func triggerSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { results = []; return }

        // Run exact search on background thread
        let exact = await Task.detached {
            ExactSearchEngine.search(term: term)
        }.value

        guard !Task.isCancelled else { return }

        // Add semantic results if available
        var semantic: [SearchResult] = []
        if searchService.isAvailable {
            semantic = await searchService.search(query: term).map { sr in
                let kind: SearchResult.Kind = switch sr.kind {
                case .meeting(let name): .meeting(name)
                case .person(let name): .person(name)
                case .task: .task
                }
                return SearchResult(
                    name: sr.name, context: sr.context, icon: sr.icon,
                    kind: kind, snippet: sr.snippet, query: sr.query
                )
            }
        }

        guard !Task.isCancelled else { return }

        // Merge: exact matches first, then semantic (deduplicated)
        var seen = Set(exact.map { "\($0.name)|\($0.context)" })
        var merged = exact
        for result in semantic {
            let key = "\(result.name)|\(result.context)"
            if seen.insert(key).inserted {
                merged.append(result)
            }
        }
        results = merged
    }

    private func openResult(_ result: SearchResult) {
        isPresented = false
        switch result.kind {
        case .meeting(let name):
            onOpenMeeting(name)
        case .person(let name):
            onOpenPerson(name)
        case .task:
            onOpenMeeting("")
        }
    }
}

private struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let context: String
    let icon: String
    let kind: Kind
    let snippet: String
    let query: String

    enum Kind {
        case meeting(String)
        case person(String)
        case task
    }

    func highlightedSnippet() -> AttributedString {
        guard !snippet.isEmpty, !query.isEmpty else {
            return AttributedString(snippet)
        }
        var attributed = AttributedString(snippet)
        let lowerSnippet = snippet.lowercased()
        let words = query.lowercased().split(separator: " ").map(String.init)

        for word in words where word.count >= 2 {
            var searchStart = lowerSnippet.startIndex
            while let range = lowerSnippet.range(of: word, range: searchStart..<lowerSnippet.endIndex) {
                let attrStart = AttributedString.Index(range.lowerBound, within: attributed)
                let attrEnd = AttributedString.Index(range.upperBound, within: attributed)
                if let start = attrStart, let end = attrEnd {
                    attributed[start..<end].foregroundColor = .primary
                    attributed[start..<end].font = .caption.bold()
                }
                searchStart = range.upperBound
            }
        }
        return attributed
    }
}

// MARK: - Exact search engine (nonisolated for background execution)

private enum ExactSearchEngine {
    struct SearchScope {
        let directory: URL
        let label: String
        let icon: String
        let kind: (String) -> SearchResult.Kind
    }

    static func search(term: String) -> [SearchResult] {
        let termLower = term.lowercased()
        var found: [SearchResult] = []
        let meetings = SearchScope(
            directory: AppSettings.meetingsDirectory,
            label: "Réunion",
            icon: "calendar",
            kind: { .meeting($0) }
        )
        let people = SearchScope(
            directory: AppSettings.peopleDirectory,
            label: "Personne",
            icon: "person",
            kind: { .person($0) }
        )
        searchDirectory(meetings, term: termLower, query: term, into: &found)
        searchDirectory(people, term: termLower, query: term, into: &found)
        searchTasks(term: termLower, query: term, into: &found)
        return found
    }

    static func searchDirectory(_ scope: SearchScope, term: String, query: String, into found: inout [SearchResult]) {
        let contents = DirectoryScanner.scan(at: scope.directory)
        for folder in contents.folders {
            if folder.name.lowercased().contains(term) {
                found.append(SearchResult(
                    name: folder.name,
                    context: scope.label,
                    icon: scope.icon,
                    kind: scope.kind(folder.name),
                    snippet: "",
                    query: query
                ))
            }
            let files = DirectoryScanner.scanRecursiveFiles(at: folder.url, fileExtension: "md")
            for file in files {
                let fileName = file.url.deletingPathExtension().lastPathComponent
                let content = try? String(contentsOf: file.url, encoding: .utf8)
                let nameMatch = fileName.lowercased().contains(term)
                let contentMatch = !nameMatch && (content?.lowercased().contains(term) == true)
                if nameMatch || contentMatch {
                    let ctx = "\(scope.label) — \(folder.name)"
                    let snippet = extractSnippet(from: content ?? "", term: term)
                    found.append(SearchResult(
                        name: fileName,
                        context: ctx,
                        icon: "doc.text",
                        kind: scope.kind(folder.name),
                        snippet: snippet,
                        query: query
                    ))
                }
            }
        }
    }

    static func searchTasks(term: String, query: String, into found: inout [SearchResult]) {
        if let content = try? String(contentsOf: AppSettings.tasksFileURL, encoding: .utf8),
           content.lowercased().contains(term) {
            let snippet = extractSnippet(from: content, term: term)
            found.append(SearchResult(
                name: "Tâches",
                context: "Fichier de tâches",
                icon: "checklist",
                kind: .task,
                snippet: snippet,
                query: query
            ))
        }
    }

    static func extractSnippet(from content: String, term: String, radius: Int = 60) -> String {
        let lower = content.lowercased()
        guard let range = lower.range(of: term) else { return "" }
        let matchOffset = content.distance(from: content.startIndex, to: range.lowerBound)
        let startOffset = max(0, matchOffset - radius)
        let endOffset = min(content.count, matchOffset + term.count + radius)
        let startIdx = content.index(content.startIndex, offsetBy: startOffset)
        let endIdx = content.index(content.startIndex, offsetBy: endOffset)
        var snippet = String(content[startIdx..<endIdx])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if startOffset > 0 { snippet = "…" + snippet }
        if endOffset < content.count { snippet += "…" }
        return snippet
    }
}
