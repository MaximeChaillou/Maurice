import SwiftUI

enum PersonSection: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case jobDescription = "Job description"
    case oneOnOne = "1-1"
    case assessment = "Assessment"
    case objectifs = "Goals"

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
    var skillRunner: SkillRunner?

    @State var viewModel: PeopleContentViewModel

    @State private var folderToDelete: FolderItem?
    @State private var selectedSection: PersonSection = .profile
    @State private var selectedCategory: String = ""

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
            selectedSection = .profile
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

            List(selection: $viewModel.selectedPerson) {
                ForEach(viewModel.categories) { category in
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()

                    ForEach(category.people) { person in
                        Text(person.name)
                            .font(.body)
                            .lineLimit(1)
                            .padding(.vertical, 2)
                            .tag(person.relativePath)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    folderToDelete = person
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .deletionAlert(
                "Delete person?",
                item: $folderToDelete,
                message: { String(localized: "The person '\($0.name)' and all their content will be deleted.") },
                onDelete: { viewModel.deletePerson($0) }
            )
        }
        .sheet(isPresented: $viewModel.isAddingFolder) {
            addPersonSheet
        }
        .sheet(isPresented: $viewModel.isAddingCategory) {
            AddItemSheet(
                title: "New category",
                placeholder: "Category name",
                text: $viewModel.newCategoryName,
                onCreate: {
                    viewModel.createCategory(name: viewModel.newCategoryName)
                    viewModel.newCategoryName = ""
                    viewModel.isAddingCategory = false
                },
                onCancel: {
                    viewModel.isAddingCategory = false
                    viewModel.newCategoryName = ""
                }
            )
        }
    }

    // MARK: - Add person sheet

    private var addPersonSheet: some View {
        VStack(spacing: 0) {
            Text("New person")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                TextField("Person name", text: $viewModel.newFolderName)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(viewModel.categoryNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                Button {
                    viewModel.isAddingFolder = false
                    viewModel.isAddingCategory = true
                } label: {
                    Label("New category", systemImage: "folder.badge.plus")
                }
            }
            .padding(16)

            Divider()

            HStack {
                Button("Cancel") {
                    viewModel.isAddingFolder = false
                    viewModel.newFolderName = ""
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    viewModel.createPerson(name: viewModel.newFolderName, inCategory: selectedCategory)
                    viewModel.newFolderName = ""
                    viewModel.isAddingFolder = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespaces).isEmpty
                          || selectedCategory.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 320)
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

            List(selection: $selectedSection) {
                ForEach(PersonSection.allCases) { section in
                    Label(section.localizedName, systemImage: section.icon)
                        .foregroundStyle(.white)
                        .tag(section)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
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
                skillRunner: skillRunner
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
