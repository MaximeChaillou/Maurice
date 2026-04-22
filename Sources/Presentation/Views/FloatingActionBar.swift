import SwiftUI

struct FloatingActionBar: View {
    let viewModel: RecordingViewModel
    let onRecordTap: () -> Void
    var contextTitle: String?
    var contextSubtitle: String?
    @State private var showLiveTranscript = false
    @State private var transcriptHeight: CGFloat = 250
    @State private var dragStartHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isRecording {
                    standardRecordRow
                } else {
                    recordPill
                }
            }
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

    private var standardRecordRow: some View {
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
    }

    private var recordPill: some View {
        Button(action: onRecordTap) {
            HStack(spacing: 12) {
                micCircle

                VStack(alignment: .leading, spacing: 1) {
                    Text(pillTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = contextSubtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 5)
            .padding(.trailing, 16)
            .padding(.vertical, 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPreparing)
        .fixedSize()
        .glassEffect(.regular, in: .capsule)
        .help(String(localized: "Start recording"))
    }

    private var pillTitle: String {
        if let contextTitle {
            return String(localized: "Record \(contextTitle)")
        }
        return String(localized: "Start recording")
    }

    private var micCircle: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.88))
                .frame(width: 34, height: 34)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                        .blur(radius: 0.5)
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(color: Color.cyan.opacity(0.35), radius: 6, y: 2)

            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var recordButton: some View {
        Button(action: onRecordTap) {
            micCircle
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
