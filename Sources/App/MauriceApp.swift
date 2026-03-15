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
    @State private var showHome = true
    @State private var calendarViewModel = GoogleCalendarViewModel()
    @State private var recordingContext: RecordingContext

    init() {
        let storage = FileTranscriptionStorage()

        let useCase = RecordingUseCase(
            transcription: SpeechRecognitionService(),
            storage: storage
        )

        let recVM = RecordingViewModel(recordingUseCase: useCase)
        let nav = NavigationCoordinator()
        let calVM = GoogleCalendarViewModel()
        let meetVM = FolderContentViewModel(directory: AppSettings.meetingsDirectory)
        let pplVM = FolderContentViewModel(directory: AppSettings.peopleDirectory)

        _recordingViewModel = State(initialValue: recVM)
        _transcriptListViewModel = State(initialValue: TranscriptListViewModel(storage: storage))
        _coordinator = State(initialValue: nav)
        _calendarViewModel = State(initialValue: calVM)
        _meetingViewModel = State(initialValue: meetVM)
        _peopleViewModel = State(initialValue: pplVM)
        _recordingContext = State(initialValue: RecordingContext(
            recordingViewModel: recVM,
            calendarViewModel: calVM,
            meetingViewModel: meetVM,
            peopleViewModel: pplVM,
            navigationCoordinator: nav
        ))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                WaveBackground(
                    hue: appTheme.hue(for: coordinator.activeTab),
                    saturation: showHome ? 0 : 1
                )
                .animation(.easeInOut(duration: 0.6), value: coordinator.activeTab)
                .animation(.easeInOut(duration: 0.6), value: showHome)

                VStack(spacing: 0) {
                    FloatingTabBar(
                        activeTab: $coordinator.activeTab,
                        isHomeActive: showHome,
                        onHomeTap: { showHome = true },
                        onTabTap: { showHome = false },
                        onSearchTap: { showSearch = true }
                    )
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    Group {
                        if showHome {
                            HomeView(calendarViewModel: calendarViewModel)
                        } else {
                            tabContent
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    FloatingActionBar(
                        viewModel: recordingViewModel,
                        onRecordTap: { recordingContext.handleRecordTap() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(alignment: .trailing) {
                        AskButton(runner: skillRunner)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .onAppear { transcriptListViewModel.load() }
            .onChange(of: recordingViewModel.isRecording) {
                if !recordingViewModel.isRecording {
                    transcriptListViewModel.load()
                }
            }
            .onChange(of: appTheme) { appTheme.saveAsync() }
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
            .withErrorBanner()
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
            CommandMenu("Mémoire") {
                MemoryMenuButton()
            }
        }

        Window("Réglages", id: "settings") {
            SettingsView(appTheme: $appTheme, calendarViewModel: calendarViewModel) {
                memoryListViewModel.reloadDirectory()
                transcriptListViewModel.load()
                appTheme = AppTheme.load()
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            .withErrorBanner()
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)

        Window("Mémoire", id: "memory") {
            ZStack {
                WaveBackground(hue: appTheme.memoryTabHue)

                MemoryContentView(
                    viewModel: memoryListViewModel,
                    markdownTheme: appTheme.markdown
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(16)
            }
            .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            .withErrorBanner()
        }
        .defaultSize(width: 800, height: 550)
        .windowResizability(.contentMinSize)
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

private struct MemoryMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Ouvrir la mémoire") {
            openWindow(id: "memory")
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}
