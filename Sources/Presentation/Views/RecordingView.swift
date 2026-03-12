import SwiftUI

struct RecordingView: View {
    let viewModel: RecordingViewModel
    @State private var showDebugPanel = false

    var body: some View {
        VStack(spacing: 0) {
            transcriptionArea
            Divider()
            controlBar
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .automatic) {
                Button {
                    showDebugPanel.toggle()
                } label: {
                    Image(systemName: "ladybug")
                }
                .help("Debug panel")
                .popover(isPresented: $showDebugPanel) {
                    debugPanel
                }
            }
            #endif
        }
    }

    #if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug")
                .font(.headline)

            Button {
                viewModel.simulateFromFile()
                showDebugPanel = false
            } label: {
                Label("Lancer audio de test", systemImage: "play.circle.fill")
            }
            .disabled(viewModel.isRecording || viewModel.isPreparing)

            Text("Joue un fichier audio en francais\net lance la transcription.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 240)
    }
    #endif

    private var transcriptionArea: some View {
        ScrollView {
            if viewModel.finalText.isEmpty && viewModel.volatileText.isEmpty && !viewModel.isRecording {
                ContentUnavailableView(
                    "No transcription yet",
                    systemImage: "waveform",
                    description: Text("Press the record button to start transcribing.")
                )
                .frame(maxHeight: .infinity)
            } else if viewModel.finalText.isEmpty && viewModel.volatileText.isEmpty {
                Text("Listening…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                BubbleListView(
                    entries: viewModel.entries.map(\.text),
                    volatileText: viewModel.volatileText,
                    autoScroll: true
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var controlBar: some View {
        RecordingControlBar(viewModel: viewModel)
    }
}
