import SwiftUI

struct FloatingActionBar: View {
    let viewModel: RecordingViewModel
    let onRecordTap: () -> Void
    @State private var showLiveTranscript = false
    @State private var transcriptHeight: CGFloat = 250
    @State private var dragStartHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: -12) {
                if viewModel.isRecording {
                    AudioWaveformView(buffer: viewModel.audioLevelBuffer)
                        .frame(height: 64)
                        .mask(waveformEdgeMask(fadeSide: .leading))
                        .transition(.opacity)
                } else {
                    Spacer()
                }

                recordButton
                    .zIndex(1)

                if viewModel.isRecording {
                    AudioWaveformView(buffer: viewModel.audioLevelBuffer)
                        .frame(height: 64)
                        .scaleEffect(x: -1, y: 1)
                        .mask(waveformEdgeMask(fadeSide: .trailing))
                        .transition(.opacity)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)

            if viewModel.isRecording {
                if let meeting = viewModel.subdirectory {
                    Text(meeting)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLiveTranscript.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showLiveTranscript ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                        Text("Live transcript")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(showLiveTranscript ? String(localized: "Hide live transcript") : String(localized: "Show live transcript"))
                .padding(.bottom, 4)
            }
        }
        .overlay(alignment: .bottom) {
            if showLiveTranscript && viewModel.isRecording {
                liveTranscriptPanel
                    .offset(y: -100)
            }
        }
        .onChange(of: viewModel.isRecording) {
            if !viewModel.isRecording {
                showLiveTranscript = false
            }
        }
    }

    private var recordButton: some View {
        Button(action: onRecordTap) {
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
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPreparing)
        .help(viewModel.isRecording ? String(localized: "Stop recording") : String(localized: "Start recording"))
    }

    private func waveformEdgeMask(fadeSide: HorizontalEdge) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.08),
                .init(color: .white, location: 1)
            ],
            startPoint: fadeSide == .leading ? .leading : .trailing,
            endPoint: fadeSide == .leading ? .trailing : .leading
        )
    }

    private var liveTranscriptPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let new = dragStartHeight - value.translation.height
                            transcriptHeight = min(max(new, 100), 500)
                        }
                        .onEnded { _ in
                            dragStartHeight = transcriptHeight
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        NSCursor.resizeUpDown.push()
                    case .ended:
                        NSCursor.pop()
                    }
                }

            ScrollView {
                BubbleListView(
                    entries: viewModel.entries.map(\.text),
                    volatileText: viewModel.volatileText,
                    autoScroll: true
                )
            }
        }
        .frame(height: transcriptHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}
