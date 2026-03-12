import Foundation

@Observable
@MainActor
final class TranscriptListViewModel {
    private let storage: TranscriptionStorage
    let navigation: DirectoryNavigation

    private(set) var folders: [Folder] = []
    private(set) var transcripts: [StoredTranscript] = []
    private(set) var errorMessage: String?

    init(storage: TranscriptionStorage) {
        self.storage = storage
        self.navigation = DirectoryNavigation(rootDirectory: AppSettings.transcriptsDirectory)
    }

    func load() {
        Task {
            do {
                let contents = try await storage.listDirectory(navigation.currentDirectory)
                folders = contents.folders
                transcripts = contents.transcripts
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func navigateInto(_ folder: Folder) {
        navigation.navigateInto(folder)
        load()
    }

    func goBack() {
        navigation.goBack()
        load()
    }

    func delete(_ transcript: StoredTranscript) {
        Task {
            do {
                try await storage.delete(transcript)
                transcripts.removeAll { $0.id == transcript.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func rename(_ transcript: StoredTranscript, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            do {
                let updated = try await storage.rename(transcript, to: newName)
                if let index = transcripts.firstIndex(where: { $0.id == transcript.id }) {
                    transcripts[index] = updated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
