import SwiftUI

enum NavigationDirection {
    case forward, backward
}

extension AnyTransition {
    static func directional(_ direction: NavigationDirection) -> AnyTransition {
        direction == .forward
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }
}

struct MemoryContentView: View {
    let viewModel: MemoryListViewModel
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var selectedFile: URL?
    @State private var navigationDirection: NavigationDirection = .forward

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 240)
                .clipped()

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            if viewModel.navigation.canGoBack {
                Button {
                    selectedFile = nil
                    navigationDirection = .backward
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.goBack()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                        Text(viewModel.navigation.directoryStack.last?.name ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
            }

            List(selection: $selectedFile) {
                ForEach(viewModel.folders) { folder in
                    Button {
                        selectedFile = nil
                        navigationDirection = .forward
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.navigateInto(folder)
                        }
                    } label: {
                        Label(folder.name, systemImage: "folder")
                            .foregroundStyle(.white)
                            .font(.body)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.files) { file in
                    Label(file.name, systemImage: "doc.text")
                        .foregroundStyle(.white)
                        .font(.body)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                        .tag(file.url)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .id(viewModel.navigation.currentDirectory)
            .transition(.directional(navigationDirection))
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let url = selectedFile,
           let file = viewModel.files.first(where: { $0.url == url }) {
            MemoryDetailView(file: file, markdownTheme: markdownTheme)
                .id(file.id)
        } else {
            ContentUnavailableView(
                "Aucun fichier sélectionné",
                systemImage: "brain.head.profile",
                description: Text("Sélectionnez un fichier dans la liste.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MemoryDetailView: View {
    let file: MemoryFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var bodyText: String = ""
    @State private var cachedFrontmatter: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(file.name)
                .font(.headline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

            Divider()

            ThemedMarkdownView(content: $bodyText, theme: markdownTheme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadFile() }
        .onChange(of: bodyText) { saveFile() }
    }

    private func loadFile() {
        let url = file.url
        Task {
            let (body, frontmatter) = await Task.detached {
                let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                guard raw.hasPrefix("---") else { return (raw, "") }
                let lines = raw.components(separatedBy: "\n")
                guard let closeIndex = lines.dropFirst().firstIndex(of: "---") else { return (raw, "") }
                let fm = lines[0...closeIndex].joined(separator: "\n")
                let body = lines.dropFirst(closeIndex + 1)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (body, fm)
            }.value
            cachedFrontmatter = frontmatter
            bodyText = body
        }
    }

    private func saveFile() {
        let text = bodyText
        let fm = cachedFrontmatter
        let url = file.url
        Task.detached {
            let full = fm.isEmpty ? text : fm + "\n\n" + text
            try? full.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
