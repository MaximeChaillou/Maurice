import Foundation

@Observable
@MainActor
final class RecordingContext {
    private let recordingViewModel: RecordingViewModel
    private let calendarViewModel: GoogleCalendarViewModel
    private let meetingViewModel: FolderContentViewModel
    private let peopleViewModel: FolderContentViewModel
    private let navigationCoordinator: NavigationCoordinator

    init(
        recordingViewModel: RecordingViewModel,
        calendarViewModel: GoogleCalendarViewModel,
        meetingViewModel: FolderContentViewModel,
        peopleViewModel: FolderContentViewModel,
        navigationCoordinator: NavigationCoordinator
    ) {
        self.recordingViewModel = recordingViewModel
        self.calendarViewModel = calendarViewModel
        self.meetingViewModel = meetingViewModel
        self.peopleViewModel = peopleViewModel
        self.navigationCoordinator = navigationCoordinator
    }

    func handleRecordTap() {
        if recordingViewModel.isRecording {
            recordingViewModel.toggleRecording()
            return
        }

        // Priority: Google Calendar > context (displayed meeting) > new meeting
        Task {
            if let event = await calendarViewModel.currentEvent() {
                if let linked = await findLinkedFolder(for: event) {
                    recordingViewModel.subdirectory = linked
                } else {
                    let created = meetingViewModel.createFolderWithName(event.summary)
                    await writeFrontmatter(for: event, in: created)
                    recordingViewModel.subdirectory = created
                }
                navigationCoordinator.activeTab = .meeting
            } else if navigationCoordinator.activeTab == .meeting,
                      let folder = meetingViewModel.selectedFolder {
                recordingViewModel.subdirectory = folder
            } else if navigationCoordinator.activeTab == .people,
                      let person = peopleViewModel.selectedFolder {
                recordingViewModel.subdirectory = "People/\(person)/1-1"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                let name = "Enregistrement \(formatter.string(from: Date()))"
                let created = meetingViewModel.createFolderWithName(name)
                recordingViewModel.subdirectory = created
                navigationCoordinator.activeTab = .meeting
            }

            recordingViewModel.toggleRecording()
        }
    }

    // MARK: - Private

    nonisolated private func findLinkedFolder(for event: GoogleCalendarEvent) async -> String? {
        await Task.detached {
            let fm = FileManager.default

            // Search in Meetings
            let meetingsDir = AppSettings.meetingsDirectory
            if let folders = try? fm.contentsOfDirectory(at: meetingsDir, includingPropertiesForKeys: nil) {
                for folder in folders where folder.hasDirectoryPath {
                    let config = MeetingConfig.load(from: folder)
                    if let linkedName = config.calendarEventName,
                       linkedName.localizedCaseInsensitiveCompare(event.summary) == .orderedSame {
                        return folder.lastPathComponent
                    }
                }
            }

            // Search in People/*/1-1
            let peopleDir = AppSettings.peopleDirectory
            if let people = try? fm.contentsOfDirectory(at: peopleDir, includingPropertiesForKeys: nil) {
                for person in people where person.hasDirectoryPath {
                    let oneOnOneDir = person.appendingPathComponent("1-1", isDirectory: true)
                    guard fm.fileExists(atPath: oneOnOneDir.path) else { continue }
                    let config = MeetingConfig.load(from: oneOnOneDir)
                    if let linkedName = config.calendarEventName,
                       linkedName.localizedCaseInsensitiveCompare(event.summary) == .orderedSame {
                        return "People/\(person.lastPathComponent)/1-1"
                    }
                }
            }

            return nil
        }.value
    }

    nonisolated private func writeFrontmatter(for event: GoogleCalendarEvent, in folderName: String) async {
        await Task.detached {
            let folderURL = AppSettings.meetingsDirectory.appendingPathComponent(folderName, isDirectory: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fileName = formatter.string(from: Date()) + ".md"
            let fileURL = folderURL.appendingPathComponent(fileName)

            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let existing = try? String(contentsOf: fileURL, encoding: .utf8),
                  existing.isEmpty else { return }

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"

            var yaml = "---\n"
            yaml += "title: \(event.summary)\n"
            yaml += "date: \(timeFormatter.string(from: event.start))\n"
            if !event.attendees.isEmpty {
                yaml += "participants:\n"
                for attendee in event.attendees {
                    if let name = attendee.displayName {
                        yaml += "  - \(name) (\(attendee.email))\n"
                    } else {
                        yaml += "  - \(attendee.email)\n"
                    }
                }
            }
            yaml += "---\n\n"

            try? yaml.write(to: fileURL, atomically: true, encoding: .utf8)
        }.value
    }
}
