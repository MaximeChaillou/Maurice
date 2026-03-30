import SwiftUI

@main
struct MauriceApp: App {
    @State private var recordingViewModel: RecordingViewModel
    @State private var memoryListViewModel = MemoryListViewModel()
    @State private var consoleViewModel = ConsoleViewModel()
    @State private var coordinator = NavigationCoordinator()
    @State private var appTheme = AppTheme.load()
    @AppStorage(AppSettings.appearanceModeKey) private var appearanceMode = "system"
    @State private var meetingViewModel = FolderContentViewModel(directory: AppSettings.meetingsDirectory)
    @State private var peopleViewModel = PeopleContentViewModel(directory: AppSettings.peopleDirectory)
    @State private var searchService = SemanticSearchService()
    @State private var showSearch = false
    @State private var showOnboarding = !AppSettings.onboardingCompleted
    @State private var lastFileSystemReload = Date.distantPast
    @State private var calendarViewModel = GoogleCalendarViewModel()
    @State private var recordingContext: RecordingContext
    private let fileWatcher = FileWatcher(path: AppSettings.rootDirectory.path)

    init() {
        IssueLogger.installCrashHandlers()
        AppSettings.applyLanguage()
        let storage = FileTranscriptionStorage()

        let useCase = RecordingUseCase(
            transcription: SpeechRecognitionService(),
            storage: storage
        )

        let recVM = RecordingViewModel(recordingUseCase: useCase)
        let nav = NavigationCoordinator()
        let calVM = GoogleCalendarViewModel()
        let meetVM = FolderContentViewModel(directory: AppSettings.meetingsDirectory)
        let pplVM = PeopleContentViewModel(directory: AppSettings.peopleDirectory)

        _recordingViewModel = State(initialValue: recVM)
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
                    saturation: coordinator.showHome ? 0 : 1
                )
                .animation(.easeInOut(duration: 0.6), value: coordinator.activeTab)
                .animation(.easeInOut(duration: 0.6), value: coordinator.showHome)

                VStack(spacing: 0) {
                    FloatingTabBar(
                        activeTab: $coordinator.activeTab,
                        isHomeActive: coordinator.showHome,
                        onHomeTap: { coordinator.showHome = true },
                        onTabTap: { coordinator.showHome = false },
                        onSearchTap: { showSearch = true }
                    )
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    Group {
                        if coordinator.showHome {
                            HomeView(calendarViewModel: calendarViewModel, coordinator: coordinator, hasMeetings: !meetingViewModel.folders.isEmpty)
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
                }
                .overlay(alignment: .bottomTrailing) {
                    ConsolePanel(viewModel: consoleViewModel)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 25)
                }
            }
            .onAppear {
                fileWatcher.start()
                Task.detached {
                    OnboardingFileSetup.copyMissingTemplates(to: AppSettings.rootDirectory)
                }
                #if DEBUG
                Self.applyDebugIconOverlay()
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
                let now = Date()
                guard now.timeIntervalSince(lastFileSystemReload) > 2.0 else { return }
                lastFileSystemReload = now
                meetingViewModel.loadFolders()
                peopleViewModel.loadFolders()
                memoryListViewModel.load()
            }
            .onChange(of: recordingViewModel.isRecording) {
                if !recordingViewModel.isRecording {
                    meetingViewModel.loadFolders()
                    peopleViewModel.loadFolders()
                }
            }
            .onChange(of: appTheme) { appTheme.saveAsync() }
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
                        onOpenPerson: { relativePath in
                            peopleViewModel.loadFolders()
                            peopleViewModel.selectedPerson = relativePath
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
            .preferredColorScheme(resolvedColorScheme)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                    reloadAfterDirectoryChange()
                }
                .interactiveDismissDisabled()
            }
            .withErrorBanner()
        }
        .defaultSize(width: 1100, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsMenuButton()
            }
            CommandGroup(after: .textEditing) {
                Button("Search...") {
                    showSearch = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Find in file...") {
                    sendFindAction(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("Memory") {
                MemoryMenuButton()
            }
        }

        Window("Settings", id: "settings") {
            SettingsView(appTheme: $appTheme, calendarViewModel: calendarViewModel) {
                reloadAfterDirectoryChange()
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            .preferredColorScheme(resolvedColorScheme)
            .withErrorBanner()
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)

        Window("Memory", id: "memory") {
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
            .preferredColorScheme(resolvedColorScheme)
            .withErrorBanner()
        }
        .defaultSize(width: 800, height: 550)
        .windowResizability(.contentMinSize)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: - Find actions

    private func sendFindAction(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = Int(action.rawValue)
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
    }

    // MARK: - Reload after directory change

    private func reloadAfterDirectoryChange() {
        meetingViewModel.resetDirectory(AppSettings.meetingsDirectory)
        peopleViewModel.resetDirectory(AppSettings.peopleDirectory)
        memoryListViewModel.reloadDirectory()
        appTheme = AppTheme.load()
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch coordinator.activeTab {
        case .meeting:
            FolderContentView(
                emptyIcon: "calendar",
                emptyTitle: "No meeting selected",
                markdownTheme: appTheme.markdown,
                navigateByDate: true,
                showSkillConfig: true,
                recordingViewModel: recordingViewModel,
                consoleViewModel: consoleViewModel,
                viewModel: meetingViewModel
            )
        case .people:
            PeopleView(
                markdownTheme: appTheme.markdown,
                recordingViewModel: recordingViewModel,
                consoleViewModel: consoleViewModel,
                viewModel: peopleViewModel
            )
        case .task:
            TasksView(markdownTheme: appTheme.markdown)
        }
    }

    // MARK: - Debug icon overlay

    #if DEBUG
    private static func applyDebugIconOverlay() {
        guard let appIcon = NSApp.applicationIconImage else { return }
        let size = appIcon.size
        let newIcon = NSImage(size: size)
        newIcon.lockFocus()
        appIcon.draw(in: NSRect(origin: .zero, size: size))

        let bannerHeight = size.height * 0.22
        let bannerRect = NSRect(x: 0, y: 0, width: size.width, height: bannerHeight)
        NSColor(red: 0.9, green: 0.3, blue: 0.0, alpha: 0.85).setFill()
        bannerRect.fill()

        let fontSize = bannerHeight * 0.55
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white,
        ]
        let text = "DEBUG" as NSString
        let textSize = text.size(withAttributes: attrs)
        let textPoint = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (bannerHeight - textSize.height) / 2
        )
        text.draw(at: textPoint, withAttributes: attrs)

        newIcon.unlockFocus()
        NSApp.applicationIconImage = newIcon
    }
    #endif
}

private struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings...") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

private struct MemoryMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    @State private var showFolderPicker = false

    var body: some View {
        Button("Open memory") {
            openWindow(id: "memory")
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])

        Button("Update memory from folder…") {
            showFolderPicker = true
        }
        .task(id: showFolderPicker) {
            guard showFolderPicker else { return }
            defer { showFolderPicker = false }
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = String(localized: "Choose a folder to import into Memory")
            panel.prompt = String(localized: "Import")
            guard panel.runModal() == .OK, let source = panel.url else { return }
            let destination = AppSettings.memoryDirectory
            await Task.detached {
                try? MemoryImporter.importFolder(from: source, to: destination)
            }.value
            NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
        }
    }
}
