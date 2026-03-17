import SwiftUI

enum PersonSection: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case jobDescription = "Job description"
    case oneOnOne = "1-1"
    case assessment = "Assessment"
    case objectifs = "Objectifs"

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
}

struct PeopleView: View {
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var skillRunner: SkillRunner?

    @State var viewModel: FolderContentViewModel

    @State private var folderToDelete: FolderItem?
    @State private var selectedSection: PersonSection = .profile

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
        .alert("Erreur", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onChange(of: viewModel.selectedFolder) {
            selectedSection = .profile
            updateRecordingSubdirectory()
        }
        .onChange(of: selectedSection) {
            updateRecordingSubdirectory()
        }
    }

    private func updateRecordingSubdirectory() {
        if selectedSection == .oneOnOne, let person = viewModel.selectedFolder {
            recordingViewModel?.subdirectory = "People/\(person)/1-1"
        } else {
            recordingViewModel?.subdirectory = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            personList
                .offset(x: viewModel.selectedFolder != nil ? -240 : 0)

            sectionList
                .offset(x: viewModel.selectedFolder != nil ? 0 : 240)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedFolder)
    }

    // MARK: - Person list

    private var personList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Personnes")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddingFolder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: $viewModel.selectedFolder) {
                ForEach(viewModel.folders) { folder in
                    Text(folder.name)
                        .font(.body)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                        .tag(folder.name)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
            .deletionAlert(
                "Supprimer la personne ?",
                item: $folderToDelete,
                message: { "La personne « \($0.name) » et tout son contenu seront supprimés." },
                onDelete: { viewModel.deleteFolder($0) }
            )
        }
        .sheet(isPresented: $viewModel.isAddingFolder) {
            AddItemSheet(
                title: "Nouvelle personne",
                placeholder: "Nom de la personne",
                text: $viewModel.newFolderName,
                onCreate: { createPerson() },
                onCancel: { viewModel.isAddingFolder = false; viewModel.newFolderName = "" }
            )
        }
    }

    // MARK: - Section list

    private var sectionList: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.selectedFolder = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text(viewModel.selectedFolder ?? "")
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
                    Label(section.rawValue, systemImage: section.icon)
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
        if let folder = viewModel.currentFolder {
            PersonDetailView(
                personName: folder.name,
                personURL: folder.url,
                activeSection: selectedSection,
                markdownTheme: markdownTheme,
                recordingViewModel: recordingViewModel,
                skillRunner: skillRunner
            )
            .id(folder.name)
        } else {
            ContentUnavailableView(
                "Aucune personne sélectionnée",
                systemImage: "person.2",
                description: Text("Sélectionnez une personne dans la liste.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Person creation

    private func createPerson() {
        let name = viewModel.newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let personURL = viewModel.directory.appendingPathComponent(name, isDirectory: true)
        viewModel.newFolderName = ""
        viewModel.isAddingFolder = false

        Task {
            await Task.detached {
                let fm = FileManager.default
                try? fm.createDirectory(at: personURL, withIntermediateDirectories: true)
                for sub in ["1-1", "assessment", "objectifs"] {
                    try? fm.createDirectory(
                        at: personURL.appendingPathComponent(sub, isDirectory: true),
                        withIntermediateDirectories: true
                    )
                }
                let profileURL = personURL.appendingPathComponent("profile.md")
                if !fm.fileExists(atPath: profileURL.path) {
                    try? "# \(name)\n".write(to: profileURL, atomically: true, encoding: .utf8)
                }
                let jobDescURL = personURL.appendingPathComponent("job-description.md")
                if !fm.fileExists(atPath: jobDescURL.path) {
                    fm.createFile(atPath: jobDescURL.path, contents: nil)
                }
            }.value
            viewModel.loadFolders()
            viewModel.selectedFolder = name
        }
    }
}
