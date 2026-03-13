import SwiftUI

@main
struct MauriceApp: App {
    @State private var recordingViewModel: RecordingViewModel
    @State private var transcriptListViewModel: TranscriptListViewModel
    @State private var memoryListViewModel = MemoryListViewModel()
    @State private var skillRunner = SkillRunner()
    @State private var coordinator = NavigationCoordinator()
    @State private var appTheme = AppTheme.load()
    @State private var meetingViewModel = FolderContentViewModel(directory: AppSettings.meetingsDirectory)
    @State private var peopleViewModel = FolderContentViewModel(directory: AppSettings.peopleDirectory)
    @State private var searchService = SemanticSearchService()
    @State private var showSearch = false

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
                WaveBackground(hue: appTheme.hue(for: coordinator.activeTab))
                    .animation(.easeInOut(duration: 0.6), value: coordinator.activeTab)

                VStack(spacing: 0) {
                    FloatingTabBar(activeTab: $coordinator.activeTab, onSearchTap: { showSearch = true })
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .padding(.horizontal, 16)

                    FloatingActionBar(
                        viewModel: recordingViewModel,
                        onRecordTap: { handleRecordTap() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .overlay(alignment: .bottomTrailing) {
                    AskButton(runner: skillRunner)
                        .padding(.trailing, 32)
                        .padding(.bottom, 12)
                }
            }
            .onAppear { transcriptListViewModel.load() }
            .onChange(of: recordingViewModel.isRecording) {
                if !recordingViewModel.isRecording {
                    transcriptListViewModel.load()
                }
            }
            .onChange(of: appTheme) { appTheme.save() }
            .onReceive(NotificationCenter.default.publisher(for: .skillRunnerDidFinish)) { _ in
                transcriptListViewModel.load()
                memoryListViewModel.reloadDirectory()
            }
            .overlay {
                if showSearch {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showSearch = false }
                        .transition(.opacity)

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
                        },
                        searchService: searchService,
                        isPresented: $showSearch
                    )
                    .frame(width: 600, height: 450)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.15), value: showSearch)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsMenuButton()
            }
            CommandGroup(after: .textEditing) {
                Button("Rechercher…") {
                    showSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Window("Réglages", id: "settings") {
            SettingsView(appTheme: $appTheme) {
                memoryListViewModel.reloadDirectory()
                transcriptListViewModel.load()
                appTheme = AppTheme.load()
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)
    }

    // MARK: - Record

    private func handleRecordTap() {
        if recordingViewModel.isRecording {
            recordingViewModel.toggleRecording()
            return
        }

        // Context: meeting active > person 1-1 active > new meeting
        if coordinator.activeTab == .meeting, let folder = meetingViewModel.selectedFolder {
            recordingViewModel.subdirectory = folder
        } else if coordinator.activeTab == .people,
                  let person = peopleViewModel.selectedFolder {
            recordingViewModel.subdirectory = "People/\(person)/1-1"
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
                markdownTheme: appTheme.markdown,
                navigateByDate: true,
                showSkillConfig: true,
                recordingViewModel: recordingViewModel,
                skillRunner: skillRunner,
                viewModel: meetingViewModel
            )
        case .people:
            PeopleView(
                markdownTheme: appTheme.markdown,
                recordingViewModel: recordingViewModel,
                skillRunner: skillRunner,
                viewModel: peopleViewModel
            )
        case .task:
            TasksView(markdownTheme: appTheme.markdown)
        }
    }
}

private struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Réglages…") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
