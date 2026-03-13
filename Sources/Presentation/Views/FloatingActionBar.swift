import SwiftUI

struct FloatingActionBar: View {
    let isRecording: Bool
    let onRecordTap: () -> Void

    var body: some View {
        Button(action: onRecordTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRecording ? .red : .red.opacity(0.6))
                    .frame(width: 10, height: 10)
                Text(isRecording ? "Arrêter" : "Enregistrer")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
    }
}
