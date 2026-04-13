import SwiftUI

enum PersonSection: String, CaseIterable, Identifiable {
    // Folders first (alphabetical), then files (alphabetical)
    case oneOnOne = "1-1"
    case assessment = "Assessment"
    case objectifs = "Goals"
    case jobDescription = "Job description"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: "person.text.rectangle"
        case .jobDescription: "doc.text"
        case .oneOnOne: "person.2"
        case .assessment: "checkmark.seal"
        case .objectifs: "target"
        }
    }

    var localizedName: String {
        switch self {
        case .profile: String(localized: "Profile")
        case .jobDescription: String(localized: "Job description")
        case .oneOnOne: "1-1"
        case .assessment: String(localized: "Assessment")
        case .objectifs: String(localized: "Goals")
        }
    }
}

struct PeopleView: View {
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?

    @State var viewModel: PeopleContentViewModel

    @State private var folderToDelete: FolderItem?
    @State private var selectedSection: PersonSection = .oneOnOne
    @State private var selectedCategory: String = ""
    @State private var shouldAddPersonAfterCategory = false
    @State private var pendingCategoryName = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 240)
                .clipped()

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { viewModel.loadFolders() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onChange(of: viewModel.selectedPerson) {
            selectedSection = .oneOnOne
            updateRecordingSubdirectory()
        }
        .onChange(of: selectedSection) {
            updateRecordingSubdirectory()
        }
    }

    private func updateRecordingSubdirectory() {
        if selectedSection == .oneOnOne, let person = viewModel.selectedPerson {
            recordingViewModel?.subdirectory = "People/\(person)/1-1"
        } else {
            recordingViewModel?.subdirectory = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            personList
                .offset(x: viewModel.selectedPerson != nil ? -240 : 0)

            sectionList
                .offset(x: viewModel.selectedPerson != nil ? 0 : 240)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPerson)
    }

    // MARK: - Person list

    private var personList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("People")
                    .font(.headline)
                Spacer()
                Button {
                    if viewModel.categoryNames.isEmpty {
                        shouldAddPersonAfterCategory = true
                        viewModel.isAddingCategory = true
                    } else {
                        selectedCategory = viewModel.categoryNames.first ?? ""
                        viewModel.isAddingFolder = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add a person")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.categories) { category in
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.horizontal, 12)

                        ForEach(category.people) { person in
                            Button {
                                viewModel.selectedPerson = person.relativePath
                            } label: {
                                Text(person.name)
                                    .font(.body)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                    .background(
                                        viewModel.selectedPerson == person.relativePath
                                            ? Color.accentColor.opacity(0.2)
                                            : Color.clear,
                                        in: .rect(cornerRadius: 6)
                                    )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    folderToDelete = person
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .deletionAlert(
                "Delete person?",
                item: $folderToDelete,
                message: { String(localized: "The person '\($0.name)' and all their content will be deleted.") },
                onDelete: { viewModel.deletePerson($0) }
            )
        }
        .sheet(isPresented: $viewModel.isAddingFolder) {
            AddPersonSheet(viewModel: viewModel, selectedCategory: $selectedCategory)
        }
        .sheet(
            isPresented: $viewModel.isAddingCategory,
            onDismiss: {
                if shouldAddPersonAfterCategory && !pendingCategoryName.isEmpty {
                    shouldAddPersonAfterCategory = false
                    selectedCategory = pendingCategoryName
                    pendingCategoryName = ""
                    viewModel.isAddingFolder = true
                } else {
                    shouldAddPersonAfterCategory = false
                    pendingCategoryName = ""
                }
            },
            content: {
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
        })
    }

    // MARK: - Section list

    private var sectionList: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.selectedPerson = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text(viewModel.currentPerson?.name ?? "")
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

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(PersonSection.allCases) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            Label(section.localizedName, systemImage: section.icon)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                                .background(
                                    selectedSection == section
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear,
                                    in: .rect(cornerRadius: 6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let person = viewModel.currentPerson {
            PersonDetailView(
                personName: person.name,
                personURL: person.url,
                activeSection: selectedSection,
                markdownTheme: markdownTheme,
                recordingViewModel: recordingViewModel,
                consoleViewModel: consoleViewModel
            )
            .id(person.relativePath)
        } else if viewModel.categories.isEmpty {
            ContentUnavailableView(
                "No people",
                systemImage: "person.2",
                description: Text("Add people to organize your 1-1 notes, assessments, and goals.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No person selected",
                systemImage: "person.2",
                description: Text("Select a person from the list.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Add person sheet

private struct AddPersonSheet: View {
    @Bindable var viewModel: PeopleContentViewModel
    @Binding var selectedCategory: String

    var body: some View {
        VStack(spacing: 0) {
            Text("New person")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                personFieldsSection
                calendarLinkSection
            }
            .padding(16)

            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var personFieldsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Person name")
                TextField("", text: $viewModel.newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Category")
                categoryMenu

                Button {
                    viewModel.isAddingFolder = false
                    viewModel.isAddingCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.semibold))
                        Text("New category")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var calendarLinkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text("Google Calendar 1-1 event name (optional)")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)

            TextField("", text: $viewModel.newCalendarEventName)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()

            Text("Used to automatically link the 1-1 Google Calendar event to this person.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                viewModel.isAddingFolder = false
                viewModel.newFolderName = ""
                viewModel.newCalendarEventName = ""
            }
            .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Create") {
                viewModel.createPerson(
                    name: viewModel.newFolderName,
                    inCategory: selectedCategory,
                    calendarEventName: viewModel.newCalendarEventName
                )
                viewModel.newFolderName = ""
                viewModel.newCalendarEventName = ""
                viewModel.isAddingFolder = false
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespaces).isEmpty
                      || selectedCategory.isEmpty)
        }
        .padding(16)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(viewModel.categoryNames, id: \.self) { name in
                Button(name) { selectedCategory = name }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedCategory.isEmpty ? " " : selectedCategory)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
