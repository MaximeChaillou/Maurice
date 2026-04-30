import SwiftUI

struct MeetingsView: View {
    let emptyIcon: String
    let emptyTitle: LocalizedStringKey
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var navigateByDate: Bool = false
    var groupByDate: Bool = false
    var showSkillConfig: Bool = false
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?
    var calendarViewModel: GoogleCalendarViewModel?
    var now: Date = Date()

    @State var viewModel: MeetingsViewModel

    @State private var folderToDelete: FolderItem?
    @State private var entryDeleteAction: EntryDeleteAction?
    @State private var showTranscripts = false

    var body: some View {
        TabScreenLayout {
            sidebar
        } detail: {
            detailPane
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onAppear {
            viewModel.loadFolders()
            reloadCurrentMeetingConfig()
        }
        .onChange(of: viewModel.folders.map(\.name), initial: true) {
            autoSelectFirstSidebarFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            guard notif.affectsPath(viewModel.directory) else { return }
            viewModel.loadFolders()
            if let folder = viewModel.currentFolder {
                viewModel.selectFileAtIndex(in: folder)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingConfigDidChange)) { notif in
            guard let folder = viewModel.currentFolder,
                  notif.affectsMeetingConfig(for: folder.url) else { return }
            reloadCurrentMeetingConfig()
        }
    }

    private func reloadCurrentMeetingConfig() {
        guard let folder = viewModel.currentFolder else { return }
        let url = folder.url
        let name = folder.name
        Task { await viewModel.loadMeetingConfig(for: name, from: url) }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        GlassSidebar(
            title: "Meetings",
            addHelp: "New meeting",
            onAdd: { viewModel.isAddingFolder = true },
            content: {
                if viewModel.folders.isEmpty {
                    SidebarEmptyState(
                        systemImage: "calendar",
                        title: "No meetings",
                        description: "Click + to create your first recurring meeting (e.g. standup, 1-1)."
                    )
                } else if groupByDate {
                    groupedFolders
                } else {
                    ForEach(viewModel.folders) { folder in
                        folderRow(folder)
                    }
                }
            }
        )
        .sheet(isPresented: $viewModel.isAddingFolder) {
            AddItemSheet(
                title: "New meeting",
                placeholder: "Meeting name",
                text: $viewModel.newFolderName,
                onCreate: { viewModel.createFolder() },
                onCancel: { viewModel.isAddingFolder = false; viewModel.newFolderName = "" }
            )
        }
        .deletionAlert(
            "Delete folder?",
            item: $folderToDelete,
            message: { String(localized: "The folder '\($0.name)' and all its content will be permanently deleted.") },
            onDelete: { viewModel.deleteFolder($0) }
        )
        .onChange(of: viewModel.selectedFolder) { handleFolderSelection() }
    }

    @ViewBuilder
    private var groupedFolders: some View {
        let buckets = bucketedFolders()
        ForEach(MeetingDateSection.allCases, id: \.self) { section in
            if let folders = buckets[section], !folders.isEmpty {
                SidebarSectionLabel(title: section.title)
                ForEach(folders) { folder in
                    folderRow(folder)
                }
            }
        }
    }

    /// Picks the first folder in the same order as the sidebar (respecting
    /// `groupByDate` bucket order) and selects it when nothing is selected.
    private func autoSelectFirstSidebarFolder() {
        guard viewModel.selectedFolder == nil, !viewModel.folders.isEmpty else { return }
        let first: FolderItem? = groupByDate
            ? MeetingDateSection.allCases.lazy.compactMap { bucketedFolders()[$0]?.first }.first
            : viewModel.folders.first
        if let first { viewModel.selectedFolder = first.name }
    }

    private func bucketedFolders() -> [MeetingDateSection: [FolderItem]] {
        Dictionary(grouping: viewModel.folders) { folder in
            MeetingDateSection.bucket(
                lastActivity: folder.dateEntries.first?.date ?? folder.files.first?.date,
                hasEventToday: folderHasUpcomingEventToday(folder),
                now: now
            )
        }
    }

    private func folderHasUpcomingEventToday(_ folder: FolderItem) -> Bool {
        guard let event = upcomingEvent(for: folder) else { return false }
        return Calendar.current.isDateInToday(event.start)
    }

    private func folderRow(_ folder: FolderItem) -> some View {
        let isActive = viewModel.selectedFolder == folder.name
        let trailing = folderTrailingLabel(for: folder)
        return SidebarRow(
            title: folder.name,
            trailing: trailing,
            leading: folder.icon.map { .emoji($0) } ?? .symbol("calendar"),
            dot: folderHasUpcomingEvent(folder),
            active: isActive,
            onTap: { viewModel.selectedFolder = folder.name }
        )
        .contextMenu { folderContextMenu(folder) }
    }

    private func folderTrailingLabel(for folder: FolderItem) -> String? {
        if let event = upcomingEvent(for: folder),
           let label = SidebarDateFormatter.upcomingLabel(event: event, now: now) {
            return label
        }
        if let lastDate = folder.dateEntries.first?.date ?? folder.files.first?.date {
            return SidebarDateFormatter.relativeLabel(date: lastDate, now: now)
        }
        return nil
    }

    private func folderHasUpcomingEvent(_ folder: FolderItem) -> Bool {
        upcomingEvent(for: folder) != nil
    }

    private func upcomingEvent(for folder: FolderItem) -> GoogleCalendarEvent? {
        guard let calendarViewModel else { return nil }
        let config = MeetingConfigStore.shared.config(for: folder.url)
        guard let eventName = config.calendarEventName, !eventName.isEmpty else { return nil }
        return calendarViewModel.upcomingEvents.first { event in
            event.summary.localizedCaseInsensitiveCompare(eventName) == .orderedSame
                && event.end > now
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: FolderItem) -> some View {
        moveMenu(for: folder)
        Divider()
        Button(role: .destructive) {
            folderToDelete = folder
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleFolderSelection() {
        viewModel.selectedFile = nil
        recordingViewModel?.subdirectory = viewModel.selectedFolder
        if let folder = viewModel.currentFolder {
            let url = folder.url
            let folderName = folder.name
            Task {
                await viewModel.loadMeetingConfig(for: folderName, from: url)
            }
            if navigateByDate {
                viewModel.fileIndex = 0
                viewModel.selectFileAtIndex(in: folder)
            }
        }
    }

    // MARK: - Detail pane

    @ViewBuilder
    private var detailPane: some View {
        if let folder = viewModel.currentFolder {
            TabDetailScaffold {
                docHeader(for: folder)
            } content: {
                detailContent(for: folder)
            }
        } else if viewModel.folders.isEmpty {
            ContentUnavailableView(
                "No meetings",
                systemImage: "calendar",
                description: Text("Click + to create your first recurring meeting (e.g. standup, 1-1).")
            )
        } else {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text("Select an item from the list.")
            )
        }
    }

    private func docHeader(for folder: FolderItem) -> some View {
        let icon: TabHeaderIcon = folder.icon.map { .emoji($0) } ?? .symbol("calendar")
        let event = LinkedEventInfo.findUpcomingEvent(
            named: viewModel.meetingConfig.calendarEventName,
            in: calendarViewModel?.upcomingEvents ?? [],
            after: now
        )
        let status = LinkedEventInfo.statusLabel(event: event, now: now)
        return TabDocHeader(
            icon: icon,
            title: folder.name,
            statusLabel: status,
            statusAccent: status != nil,
            metaItems: buildMetaItems(for: folder, event: event),
            onIconChange: { emoji in updateFolderIcon(emoji) },
            onTitleChange: { newName in
                _ = viewModel.renameFolder(folder, to: newName)
            },
            trailingActions: {
                if showSkillConfig {
                    MeetingActionsBar(
                        folderURL: folder.url,
                        folderDisplayName: folder.name,
                        consoleViewModel: consoleViewModel,
                        config: $viewModel.meetingConfig,
                        activeFilePath: activeFile(for: folder)?.path
                    )
                    .onChange(of: viewModel.meetingConfig.icon) {
                        viewModel.updateCurrentFolderIcon(viewModel.meetingConfig.icon)
                    }
                }
            }
        )
    }

    private func buildMetaItems(for folder: FolderItem, event: GoogleCalendarEvent?) -> [TabMetaItem] {
        var meta: [TabMetaItem] = []
        if let timeLabel = LinkedEventInfo.timeLabel(event: event) {
            meta.append(TabMetaItem(systemImage: "calendar", label: timeLabel))
        }
        meta.append(.googleCalendarStatus(
            config: $viewModel.meetingConfig,
            configURL: folder.url
        ))
        if folder.fileCount > 0 {
            meta.append(TabMetaItem(
                systemImage: "doc.text",
                label: String(localized: "\(folder.fileCount) files")
            ))
        }
        return meta
    }

    private func updateFolderIcon(_ emoji: String) {
        guard let folder = viewModel.currentFolder else { return }
        viewModel.meetingConfig.icon = emoji
        MeetingConfigStore.shared.update(viewModel.meetingConfig, for: folder.url)
        viewModel.updateCurrentFolderIcon(emoji)
    }

    private func activeFile(for folder: FolderItem) -> URL? {
        if navigateByDate, !folder.dateEntries.isEmpty {
            let entries = folder.dateEntries
            let safeIndex = min(viewModel.fileIndex, entries.count - 1)
            let entry = entries[max(safeIndex, 0)]
            if showTranscripts, let transcript = entry.transcriptFile {
                return transcript.url
            }
            return entry.noteFile?.url ?? entry.transcriptFile?.url
        }
        if folder.files.count == 1 { return folder.files.first?.url }
        return viewModel.selectedFile
    }

    @ViewBuilder
    private func detailContent(for folder: FolderItem) -> some View {
        if navigateByDate, !folder.dateEntries.isEmpty {
            dateNavigationDetail(for: folder)
        } else if folder.files.count == 1, let file = folder.files.first {
            FolderFileDetailView(file: file, markdownTheme: markdownTheme)
                .id(file.id)
        } else {
            fileListDetail(for: folder)
        }
    }
}

// MARK: - Move menu

extension MeetingsView {
    @ViewBuilder
    func moveMenu(for folder: FolderItem) -> some View {
        let destinations = MeetingsViewModel.listMoveDestinations(excluding: folder)
        let sections = Dictionary(grouping: destinations, by: \.section)
        let sortedKeys = sections.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if destinations.isEmpty {
            Button {} label: {
                Label("Move content to…", systemImage: "folder.badge.arrow.right")
            }
            .disabled(true)
        } else {
            Menu {
                ForEach(sortedKeys, id: \.self) { section in
                    Section(section) {
                        if let items = sections[section] {
                            ForEach(items) { dest in
                                Button {
                                    viewModel.moveFolderContent(folder, to: dest.url)
                                } label: { Text(dest.name) }
                            }
                        }
                    }
                }
            } label: {
                Label("Move content to…", systemImage: "folder.badge.arrow.right")
            }
        }
    }
}

// MARK: - Date navigation

extension MeetingsView {
    func dateNavigationDetail(for folder: FolderItem) -> some View {
        let entries = folder.dateEntries
        let safeIndex = min(viewModel.fileIndex, entries.count - 1)
        let entry = entries[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                BreadcrumbBar(segments: meetingBreadcrumb(folder: folder, entry: entry))
                Spacer(minLength: 8)
                TranscriptPill(entry: entry, showTranscripts: $showTranscripts)
                EntryMoreMenu(entry: entry, entryDeleteAction: $entryDeleteAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider().opacity(0.5)
            DateEntryContentView(
                entry: entry, markdownTheme: markdownTheme, showTranscripts: $showTranscripts
            )
        }
        .onChange(of: viewModel.fileIndex) { showTranscripts = false }
        .entryDeleteAlert(action: $entryDeleteAction) { action in
            switch action {
            case .note(let e): viewModel.deleteDateEntry(e, noteOnly: true)
            case .transcript(let e): viewModel.deleteDateEntry(e, transcriptOnly: true)
            case .both(let e): viewModel.deleteDateEntry(e)
            }
        }
    }

    fileprivate func meetingBreadcrumb(
        folder: FolderItem,
        entry: MeetingDateEntry
    ) -> [BreadcrumbSegment] {
        [folderBreadcrumbSegment(activeFolder: folder),
         fileBreadcrumbSegment(folder: folder, entry: entry)]
    }

    private func folderBreadcrumbSegment(activeFolder: FolderItem) -> BreadcrumbSegment {
        BreadcrumbSegment(
            id: "folder",
            label: activeFolder.name,
            kind: .folder,
            popoverTitle: String(localized: "Meetings"),
            emptyMessage: String(localized: "No meetings"),
            groups: [BreadcrumbSiblingGroup(
                id: "all", title: nil,
                siblings: viewModel.folders.map { f in
                    BreadcrumbSibling(
                        id: f.name,
                        label: f.name,
                        sub: f.fileCount > 0 ? String(localized: "\(f.fileCount) files") : nil,
                        leading: f.icon.map { .emoji($0) } ?? .symbol("calendar"),
                        active: f.name == activeFolder.name
                    )
                }
            )],
            onPick: { name in viewModel.selectedFolder = name }
        )
    }

    private func fileBreadcrumbSegment(
        folder: FolderItem,
        entry: MeetingDateEntry
    ) -> BreadcrumbSegment {
        let ext = showTranscripts && entry.hasTranscript ? "transcript" : "md"
        return BreadcrumbSegment(
            id: "file",
            label: "\(entry.dateString).\(ext)",
            kind: .file,
            popoverTitle: String(localized: "Occurrences"),
            emptyMessage: String(localized: "No other entries"),
            groups: [BreadcrumbSiblingGroup(
                id: "entries", title: nil,
                siblings: folder.dateEntries.map { e in
                    BreadcrumbSibling(
                        id: e.dateString,
                        label: "\(e.dateString).md",
                        sub: dateSubtitle(for: e.date),
                        leading: .symbol("doc.text"),
                        active: e.dateString == entry.dateString
                    )
                }
            )],
            onPick: { dateString in
                if let idx = folder.dateEntries.firstIndex(where: { $0.dateString == dateString }) {
                    viewModel.fileIndex = idx
                }
            }
        )
    }

    private func dateSubtitle(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

// MARK: - File list

extension MeetingsView {
    func fileListDetail(for folder: FolderItem) -> some View {
        HStack(spacing: 0) {
            fileList(for: folder)
                .frame(width: 200)

            Divider().opacity(0.5)

            if let url = viewModel.selectedFile,
               let file = folder.files.first(where: { $0.url == url }) {
                FolderFileDetailView(file: file, markdownTheme: markdownTheme)
                    .id(file.id)
            } else {
                ContentUnavailableView(
                    "No file selected",
                    systemImage: "doc.text",
                    description: Text("Select a file from the list.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func fileList(for folder: FolderItem) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(folder.files) { file in
                    SidebarRow(
                        title: file.name,
                        subtitle: file.date.formatted(.dateTime.day().month(.abbreviated).year()),
                        leading: .symbol("doc.text"),
                        active: viewModel.selectedFile == file.url,
                        onTap: { viewModel.selectedFile = file.url }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }
}
