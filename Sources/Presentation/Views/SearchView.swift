import SwiftUI

struct SearchView: View {
    let onOpenMeeting: (String) -> Void
    let onOpenPerson: (String) -> Void

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Rechercher dans les fichiers…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit { search() }
                    .onChange(of: query) { search() }
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(result.context)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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
        .onAppear { isSearchFocused = true }
    }

    private func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard term.count >= 2 else { results = []; return }

        var found: [SearchResult] = []
        let meetings = SearchScope(directory: AppSettings.meetingsDirectory, label: "Réunion", icon: "calendar", kind: { .meeting($0) })
        let people = SearchScope(directory: AppSettings.peopleDirectory, label: "Personne", icon: "person", kind: { .person($0) })
        searchDirectory(meetings, term: term, into: &found)
        searchDirectory(people, term: term, into: &found)
        searchTasks(term: term, into: &found)
        results = found
    }

    private struct SearchScope {
        let directory: URL
        let label: String
        let icon: String
        let kind: (String) -> SearchResult.Kind
    }

    private func searchDirectory(_ scope: SearchScope, term: String, into found: inout [SearchResult]) {
        let contents = DirectoryScanner.scan(at: scope.directory)
        for folder in contents.folders {
            if folder.name.lowercased().contains(term) {
                found.append(SearchResult(name: folder.name, context: scope.label, icon: scope.icon, kind: scope.kind(folder.name)))
            }
            let files = DirectoryScanner.scan(at: folder.url, fileExtension: "md").files
            for file in files {
                let fileName = file.url.deletingPathExtension().lastPathComponent
                let nameMatch = fileName.lowercased().contains(term)
                let contentMatch = !nameMatch && ((try? String(contentsOf: file.url, encoding: .utf8))?.lowercased().contains(term) == true)
                if nameMatch || contentMatch {
                    let ctx = "\(scope.label) — \(folder.name)"
                    found.append(SearchResult(name: fileName, context: ctx, icon: "doc.text", kind: scope.kind(folder.name)))
                }
            }
        }
    }

    private func searchTasks(term: String, into found: inout [SearchResult]) {
        if let content = try? String(contentsOf: AppSettings.tasksFileURL, encoding: .utf8),
           content.lowercased().contains(term) {
            found.append(SearchResult(name: "Tâches", context: "Fichier de tâches", icon: "checklist", kind: .task))
        }
    }

    private func openResult(_ result: SearchResult) {
        switch result.kind {
        case .meeting(let name):
            onOpenMeeting(name)
        case .person(let name):
            onOpenPerson(name)
        case .task:
            onOpenMeeting("") // Handled specially in MauriceApp
        }
    }
}

private struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let context: String
    let icon: String
    let kind: Kind

    enum Kind {
        case meeting(String)
        case person(String)
        case task
    }
}
