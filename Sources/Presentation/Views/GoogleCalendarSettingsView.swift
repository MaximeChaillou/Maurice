import SwiftUI

struct GoogleCalendarSettingsView: View {
    let viewModel: GoogleCalendarViewModel

    var body: some View {
        Form {
            Section("Google Calendar") {
                Text("Connectez votre calendrier pour voir vos prochaines réunions et démarrer l'enregistrement automatiquement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isConnected {
                    connectedView
                } else {
                    disconnectedView
                }
            }
        }
        .formStyle(.grouped)
    }

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connecté")
                    .fontWeight(.medium)
            }

            if let email = viewModel.connectedEmail {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                    Text(email)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Déconnecter") {
                viewModel.disconnect()
            }
            .padding(.top, 4)
        }
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                Text("Non connecté")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connexion en cours…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connecter Google Calendar") {
                    viewModel.connect()
                }
                .disabled(GoogleCalendarService.clientID.isEmpty || GoogleCalendarService.clientSecret.isEmpty)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
