import SwiftUI

struct RecordingControlBar: View {
    let viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(2)
            }

            HStack(spacing: -12) {
                if viewModel.isRecording {
                    AudioWaveformView(buffer: viewModel.audioLevelBuffer)
                        .transition(.opacity)
                } else {
                    Spacer()
                }

                recordButton
                    .zIndex(1)

                if viewModel.isRecording {
                    AudioWaveformView(buffer: viewModel.audioLevelBuffer)
                        .scaleEffect(x: -1, y: 1)
                        .transition(.opacity)
                } else {
                    Spacer()
                }
            }
            .frame(height: 64)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
    }

    private var recordButton: some View {
        Button(action: viewModel.toggleRecording) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.3), .cyan.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 64, height: 64)

                Circle()
                    .fill(.cyan.opacity(0.8))
                    .frame(width: 35, height: 35)

                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPreparing)
    }
}
