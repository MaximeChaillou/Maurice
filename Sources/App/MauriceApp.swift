import SwiftUI

@main
struct MauriceApp: App {
    @State private var recordingViewModel: RecordingViewModel
    @State private var transcriptListViewModel: TranscriptListViewModel
    @State private var memoryListViewModel = MemoryListViewModel()
    @State private var skillRunner = SkillRunner()
    @State private var coordinator = NavigationCoordinator()
    @State private var markdownTheme = MarkdownTheme.load()
    @State private var meetingViewModel = FolderContentViewModel(directory: AppSettings.meetingsDirectory)
    @State private var peopleViewModel = FolderContentViewModel(directory: AppSettings.peopleDirectory)
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
            ZStack {
                WaveBackground()

                VStack(spacing: 0) {
                    FloatingTabBar(activeTab: $coordinator.activeTab)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                    HStack(alignment: .bottom) {
                        Spacer()
                        FloatingActionBar(
                            isRecording: recordingViewModel.isRecording,
                            onRecordTap: { handleRecordTap() }
                        )
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        FloatingSearchButton(runner: skillRunner)
                            .padding(.trailing, 16)
                    }
                    .padding(.vertical, 12)
                }
            }
            .onAppear { transcriptListViewModel.load() }
            .onChange(of: recordingViewModel.isRecording) {
                if !recordingViewModel.isRecording {
                    transcriptListViewModel.load()
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

    // MARK: - Record

    private func handleRecordTap() {
        if recordingViewModel.isRecording {
            recordingViewModel.toggleRecording()
            return
        }

        // Context: meeting active > new meeting
        if coordinator.activeTab == .meeting, let folder = meetingViewModel.selectedFolder {
            recordingViewModel.subdirectory = folder
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let name = "Enregistrement \(formatter.string(from: Date()))"
            let created = meetingViewModel.createFolderWithName(name)
            recordingViewModel.subdirectory = created
            coordinator.activeTab = .meeting
        }

        recordingViewModel.toggleRecording()
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch coordinator.activeTab {
        case .meeting:
            FolderContentView(
                emptyIcon: "calendar",
                emptyTitle: "Aucune réunion sélectionnée",
                markdownTheme: markdownTheme,
                navigateByDate: true,
                showSkillConfig: true,
                recordingViewModel: recordingViewModel,
                skillRunner: skillRunner,
                viewModel: meetingViewModel
            )
        case .people:
            FolderContentView(
                emptyIcon: "person.2",
                emptyTitle: "Aucune personne sélectionnée",
                markdownTheme: markdownTheme,
                skillRunner: skillRunner,
                viewModel: peopleViewModel
            )
        case .task:
            TasksView(markdownTheme: markdownTheme)
        case .search:
            SearchView(
                onOpenMeeting: { name in
                    if name.isEmpty {
                        coordinator.activeTab = .task
                    } else {
                        meetingViewModel.loadFolders()
                        meetingViewModel.selectedFolder = name
                        coordinator.activeTab = .meeting
                    }
                },
                onOpenPerson: { name in
                    peopleViewModel.loadFolders()
                    peopleViewModel.selectedFolder = name
                    coordinator.activeTab = .people
                }
            )
        }
    }
}
