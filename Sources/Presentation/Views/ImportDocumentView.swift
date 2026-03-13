import SwiftUI
import UniformTypeIdentifiers

struct ImportDocumentView: View {
    let targetPath: String
    let runner: SkillRunner
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                pickFile()
            } label: {
                Label("Choisir un fichier", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func pickFile() {
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
        runner.runImport(
            source: fileURL.path,
            targetPath: targetPath,
            workingDirectory: AppSettings.rootDirectory
        )
        onDismiss()
    }
}
