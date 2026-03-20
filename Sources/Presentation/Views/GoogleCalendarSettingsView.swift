import SwiftUI

struct GoogleCalendarSettingsView: View {
    let viewModel: GoogleCalendarViewModel

    var body: some View {
        Form {
            Section("Google Calendar") {
                Text("Connect your calendar to see your upcoming meetings and start recording automatically.")
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
                Text("Connected")
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

            Button("Disconnect") {
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
                Text("Not connected")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connect Google Calendar") {
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
