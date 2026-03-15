import SwiftUI

struct AddItemSheet: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var onCreate: () -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            Divider()

            HStack {
                Button("Annuler") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Créer") { submit() }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 320)
    }

    private func submit() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onCreate()
        dismiss()
    }
}
