import SwiftUI

@main
struct MauriceApp: App {
    @State private var recordingViewModel: RecordingViewModel
    @State private var transcriptListViewModel: TranscriptListViewModel
    @State private var memoryListViewModel = MemoryListViewModel()
    @State private var sidebarSelection: SidebarSection? = .recording
    @State private var markdownTheme = MarkdownTheme.load()
    @Environment(\.openWindow) private var openWindow

    init() {
        let storage = FileTranscriptionStorage()

        let useCase = RecordingUseCase(
            transcription: SpeechAnalyzerLiveTranscription(),
            storage: storage
        )

        _recordingViewModel = State(initialValue: RecordingViewModel(recordingUseCase: useCase))
        _transcriptListViewModel = State(initialValue: TranscriptListViewModel(storage: storage))
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            } detail: {
                detailView
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingSearchButton()
                    .padding(16)
                    .padding(.leading, 300)
            }
            .onAppear { transcriptListViewModel.load() }
            .onChange(of: recordingViewModel.isRecording) {
                if !recordingViewModel.isRecording {
                    transcriptListViewModel.load()
                }
            }
            .onChange(of: sidebarSelection) {
                if sidebarSelection != .meetings {
                    recordingViewModel.subdirectory = nil
                }
            }
            .onChange(of: markdownTheme) { markdownTheme.save() }
            .onReceive(NotificationCenter.default.publisher(for: .skillRunnerDidFinish)) { _ in
                transcriptListViewModel.load()
                memoryListViewModel.reloadDirectory()
            }
        }
        .defaultSize(width: 1100, height: 700)

        Window("Réglages", id: "settings") {
            SettingsView(markdownTheme: $markdownTheme) {
                memoryListViewModel.reloadDirectory()
                transcriptListViewModel.load()
                markdownTheme = MarkdownTheme.load()
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 750, height: 500)
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Label("Enregistrement", systemImage: "mic.fill")
                .tag(SidebarSection.recording)

            Label("Transcripts", systemImage: "doc.text")
                .tag(SidebarSection.transcripts)

            Label("Réunions", systemImage: "calendar")
                .tag(SidebarSection.meetings)

            Label("Personnes", systemImage: "person.2")
                .tag(SidebarSection.people)

            Label("Tâches", systemImage: "checklist")
                .tag(SidebarSection.tasks)

            Label("Mémoire", systemImage: "brain.head.profile")
                .tag(SidebarSection.memory)
        }
        .navigationTitle("Maurice")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if recordingViewModel.isRecording {
                    Button {
                        recordingViewModel.toggleRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("Enregistrement en cours")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "stop.fill")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.horizontal, 8)
                }

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Réglages", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch sidebarSelection {
        case .recording, .none:
            RecordingView(viewModel: recordingViewModel)
        case .transcripts:
            TranscriptsContentView(viewModel: transcriptListViewModel)
        case .meetings:
            FolderContentView(
                directory: AppSettings.meetingsDirectory,
                emptyIcon: "calendar",
                emptyTitle: "Aucune réunion sélectionnée",
                markdownTheme: markdownTheme,
                navigateByDate: true,
                showSkillConfig: true,
                recordingViewModel: recordingViewModel
            )
        case .people:
            FolderContentView(
                directory: AppSettings.peopleDirectory,
                emptyIcon: "person.2",
                emptyTitle: "Aucune personne sélectionnée",
                markdownTheme: markdownTheme
            )
        case .tasks:
            TasksView(markdownTheme: markdownTheme)
        case .memory:
            MemoryContentView(viewModel: memoryListViewModel, markdownTheme: markdownTheme)
        }
    }
}

enum SidebarSection: Hashable {
    case recording
    case transcripts
    case tasks
    case meetings
    case people
    case memory
}

private struct TranscriptsContentView: View {
    let viewModel: TranscriptListViewModel
    @State private var selectedTranscript: URL?
    @State private var navigationDirection: NavigationDirection = .forward

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if viewModel.navigation.canGoBack {
                    HStack {
                        Button {
                            selectedTranscript = nil
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

                List(selection: $selectedTranscript) {
                    ForEach(viewModel.folders) { folder in
                        Button {
                            selectedTranscript = nil
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

                    ForEach(viewModel.transcripts) { transcript in
                        TranscriptRow(transcript: transcript)
                            .tag(transcript.url)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.delete(transcript)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                }
                .id(viewModel.navigation.currentDirectory)
                .transition(.directional(navigationDirection))
            }
            .clipped()
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            if let url = selectedTranscript,
               let transcript = viewModel.transcripts.first(where: { $0.url == url }) {
                TranscriptDetailView(transcript: transcript) { newName in
                    viewModel.rename(transcript, to: newName)
                    selectedTranscript =
                        viewModel.transcripts.first(where: { $0.name == newName })?.url ?? url
                }
            } else {
                ContentUnavailableView(
                    "Aucun transcript sélectionné",
                    systemImage: "doc.text",
                    description: Text("Sélectionnez un transcript dans la liste.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

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

private struct TranscriptRow: View {
    let transcript: StoredTranscript

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(transcript.name)
                    .font(.body)
                    .lineLimit(1)
                Text(transcript.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } icon: {
            Image(systemName: "doc.text")
        }
    }
}
