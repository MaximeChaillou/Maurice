import SwiftUI

struct MemoryContentView: View {
    let viewModel: MemoryListViewModel
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var selectedFile: URL?
    @State private var navigationDirection: NavigationDirection = .forward

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if viewModel.navigation.canGoBack {
                    HStack {
                        Button {
                            selectedFile = nil
                            navigationDirection = .backward
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.goBack()
                            }
                        } label: {
                            Label("Retour", systemImage: "chevron.left")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(viewModel.navigation.directoryStack.last?.name ?? "")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
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
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folder.name)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text("Dossier")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            } icon: {
                                Image(systemName: "folder")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(viewModel.files) { file in
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(file.date, format: .dateTime.day().month(.abbreviated).year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        } icon: {
                            Image(systemName: "doc.text")
                        }
                        .tag(file.url)
                    }
                }
                .id(viewModel.navigation.currentDirectory)
                .transition(.directional(navigationDirection))
            }
            .clipped()
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

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
        .onAppear { viewModel.load() }
    }
}

private struct MemoryDetailView: View {
    let file: MemoryFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var bodyText: String = ""

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
        .onAppear { bodyText = file.body }
        .onChange(of: bodyText) { file.save(body: bodyText) }
    }
}
