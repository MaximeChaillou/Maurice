import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum ImportDocumentHelper {
    static func pickFile(targetPath: String, consoleViewModel: ConsoleViewModel) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .pdf, .plainText, .rtf, .html,
            UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
            UTType("com.microsoft.word.doc") ?? .data,
            .png, .jpeg
        ]

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        consoleViewModel.sendImportSkill(
            source: fileURL.path,
            targetPath: targetPath
        )
    }
}
