import SwiftUI

struct PeopleView: View {
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?
    var calendarViewModel: GoogleCalendarViewModel?
    var now: Date = Date()

    @State var viewModel: PeopleContentViewModel

    @State private var folderToDelete: FolderItem?
    @State private var personSubpath: String = ""
    @State private var selectedCategory: String = ""
    @State private var shouldAddPersonAfterCategory = false
    @State private var pendingCategoryName = ""

    @State private var oneOnOneConfig = MeetingConfig()
    @State private var oneOnOneActiveFileURL: URL?

    private var isEditingOneOnOne: Bool {
        personSubpath.hasPrefix("1-1/")
    }

    var body: some View {
        TabScreenLayout {
            sidebar
        } detail: {
            detailPane
        }
        .onAppear {
            viewModel.loadFolders()
            Task { await loadOneOnOneConfig() }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onChange(of: viewModel.selectedPerson) {
            personSubpath = ""
            updateRecordingSubdirectory()
            Task {
                await loadOneOnOneConfig()
                await resolveDefaultSubpath()
            }
        }
        .onChange(of: personSubpath) {
            updateRecordingSubdirectory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingConfigDidChange)) { notif in
            guard let person = viewModel.currentPerson else { return }
            let dir = person.url.appendingPathComponent("1-1", isDirectory: true)
            guard notif.affectsMeetingConfig(for: dir) else { return }
            Task { await loadOneOnOneConfig() }
        }
    }

    private func updateRecordingSubdirectory() {
        if isEditingOneOnOne, let person = viewModel.selectedPerson {
            recordingViewModel?.subdirectory = "People/\(person)/1-1"
        } else {
            recordingViewModel?.subdirectory = nil
        }
    }

    private func resolveDefaultSubpath() async {
        guard let person = viewModel.currentPerson else { return }
        let resolved = await FolderPathExplorerView.resolveDefaultSubpath(
            in: person.url,
            preferredFolders: ["1-1"]
        )
        if viewModel.currentPerson?.relativePath == person.relativePath {
            personSubpath = resolved
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        GlassSidebar(
            title: "People",
            addHelp: "Add a person",
            onAdd: { handleAddPerson() },
            content: {
                if viewModel.categories.isEmpty {
                    SidebarEmptyState(
                        systemImage: "person.2",
                        title: "No people",
                        description: "Add people to organize your 1-1 notes, assessments, and goals."
                    )
                } else {
                    ForEach(viewModel.categories) { category in
                        SidebarSectionLabel(title: category.name)
                        ForEach(category.people) { person in
                            personRow(person)
                        }
                    }
                }
            }
        )
        .deletionAlert(
            "Delete person?",
            item: $folderToDelete,
            message: { String(localized: "The person '\($0.name)' and all their content will be deleted.") },
            onDelete: { viewModel.deletePerson($0) }
        )
        .sheet(isPresented: $viewModel.isAddingFolder) {
            AddPersonSheet(viewModel: viewModel, selectedCategory: $selectedCategory)
        }
        .sheet(isPresented: $viewModel.isAddingCategory, onDismiss: handleCategorySheetDismiss) {
            categorySheet
        }
    }

    private func personRow(_ person: FolderItem) -> some View {
        let isActive = viewModel.selectedPerson == person.relativePath
        let leading: SidebarRow.Leading
        if let emoji = person.icon, !emoji.isEmpty {
            leading = .emoji(emoji)
        } else {
            leading = .initials(
                AvatarColors.initials(for: person.name),
                gradient: AvatarColors.gradient(for: person.relativePath)
            )
        }
        return SidebarRow(
            title: person.name,
            leading: leading,
            active: isActive,
            onTap: { viewModel.selectedPerson = person.relativePath }
        )
        .contextMenu {
            Button(role: .destructive) {
                folderToDelete = person
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleAddPerson() {
        if viewModel.categoryNames.isEmpty {
            shouldAddPersonAfterCategory = true
            viewModel.isAddingCategory = true
        } else {
            selectedCategory = viewModel.categoryNames.first ?? ""
            viewModel.isAddingFolder = true
        }
    }

    private func handleCategorySheetDismiss() {
        if shouldAddPersonAfterCategory && !pendingCategoryName.isEmpty {
            shouldAddPersonAfterCategory = false
            selectedCategory = pendingCategoryName
            pendingCategoryName = ""
            viewModel.isAddingFolder = true
        } else {
            shouldAddPersonAfterCategory = false
            pendingCategoryName = ""
        }
    }

    private var categorySheet: some View {
        AddItemSheet(
            title: "New category",
            subtitle: shouldAddPersonAfterCategory
                ? "People are organized by category (e.g. team, department). Create one first."
                : nil,
            placeholder: "Category name",
            text: $viewModel.newCategoryName,
            onCreate: {
                pendingCategoryName = viewModel.newCategoryName.trimmingCharacters(in: .whitespaces)
                viewModel.createCategory(name: viewModel.newCategoryName)
                viewModel.newCategoryName = ""
                viewModel.isAddingCategory = false
            },
            onCancel: {
                shouldAddPersonAfterCategory = false
                pendingCategoryName = ""
                viewModel.isAddingCategory = false
                viewModel.newCategoryName = ""
            }
        )
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let person = viewModel.currentPerson {
            TabDetailScaffold {
                personDocHeader(person)
            } content: {
                personContentCard(for: person)
            }
            .id(person.relativePath)
        } else if viewModel.categories.isEmpty {
            ContentUnavailableView(
                "No people",
                systemImage: "person.2",
                description: Text("Add people to organize your 1-1 notes, assessments, and goals.")
            )
        } else {
            ContentUnavailableView(
                "No person selected",
                systemImage: "person.2",
                description: Text("Select a person from the list.")
            )
        }
    }

    private func personDocHeader(_ person: FolderItem) -> some View {
        let event = isEditingOneOnOne
            ? LinkedEventInfo.findUpcomingEvent(
                named: oneOnOneConfig.calendarEventName,
                in: calendarViewModel?.upcomingEvents ?? [],
                after: now
            )
            : nil
        let status = LinkedEventInfo.statusLabel(event: event, now: now)
        return TabDocHeader(
            icon: personIcon(for: person),
            title: person.name,
            statusLabel: status,
            statusAccent: status != nil,
            metaItems: personMetaItems(for: person, event: event),
            onIconChange: { emoji in viewModel.updatePersonIcon(person, icon: emoji) },
            onTitleChange: { newName in
                _ = viewModel.renamePerson(person, to: newName)
            },
            trailingActions: {
                if isEditingOneOnOne {
                    MeetingActionsBar(
                        folderURL: person.url.appendingPathComponent("1-1", isDirectory: true),
                        folderDisplayName: "1-1",
                        consoleViewModel: consoleViewModel,
                        config: $oneOnOneConfig,
                        activeFilePath: oneOnOneActiveFileURL?.path
                    )
                }
            }
        )
    }

    private func personIcon(for person: FolderItem) -> TabHeaderIcon {
        if let emoji = person.icon, !emoji.isEmpty {
            return .emoji(emoji)
        }
        return .initials(
            AvatarColors.initials(for: person.name),
            gradient: AvatarColors.gradient(for: person.relativePath)
        )
    }

    private func personMetaItems(
        for person: FolderItem,
        event: GoogleCalendarEvent?
    ) -> [TabMetaItem] {
        var meta: [TabMetaItem] = []
        if let timeLabel = LinkedEventInfo.timeLabel(event: event) {
            meta.append(TabMetaItem(systemImage: "calendar", label: timeLabel))
        }
        if isEditingOneOnOne {
            meta.append(.googleCalendarStatus(
                config: $oneOnOneConfig,
                configURL: person.url.appendingPathComponent("1-1", isDirectory: true)
            ))
        }
        if let category = personCategory(for: person) {
            meta.append(TabMetaItem(systemImage: "person.2", label: category))
        }
        return meta
    }

    private func personCategory(for person: FolderItem) -> String? {
        for category in viewModel.categories where category.people.contains(where: { $0.id == person.id }) {
            return category.name
        }
        return nil
    }

    private func personContentCard(for person: FolderItem) -> some View {
        FolderPathExplorerView(
            rootURL: person.url,
            rootSegment: personBreadcrumbSegment(currentPerson: person),
            subpath: $personSubpath,
            markdownTheme: markdownTheme,
            onActiveFileChange: { url in oneOnOneActiveFileURL = url }
        )
        .id(person.relativePath)
    }
}

// MARK: - Breadcrumb segment

extension PeopleView {
    fileprivate func personBreadcrumbSegment(currentPerson: FolderItem) -> BreadcrumbSegment {
        let groups: [BreadcrumbSiblingGroup] = viewModel.categories.map { category in
            BreadcrumbSiblingGroup(
                id: category.id,
                title: category.name,
                siblings: category.people.map { person in
                    BreadcrumbSibling(
                        id: person.relativePath,
                        label: person.name,
                        leading: .initials(
                            AvatarColors.initials(for: person.name),
                            gradient: AvatarColors.gradient(for: person.relativePath)
                        ),
                        active: person.relativePath == currentPerson.relativePath
                    )
                }
            )
        }
        return BreadcrumbSegment(
            id: "person",
            label: currentPerson.name,
            kind: .folder,
            revealURL: currentPerson.url,
            popoverTitle: String(localized: "People"),
            emptyMessage: String(localized: "No people"),
            groups: groups,
            onPick: { relativePath in
                viewModel.selectedPerson = relativePath
            }
        )
    }
}

// MARK: - 1-1 helpers

extension PeopleView {
    fileprivate func loadOneOnOneConfig() async {
        guard let person = viewModel.currentPerson else { return }
        let dir = person.url.appendingPathComponent("1-1", isDirectory: true)
        oneOnOneConfig = await Task.detached {
            MeetingConfigStore.shared.config(for: dir)
        }.value
    }
}
