import SwiftUI

private struct MCPServer: Identifiable {
    let name: String
    let detail: String
    let isConnected: Bool
    var id: String { name }
}

struct MCPServersView: View {
    @State private var servers: [MCPServer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("MCP Servers") {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Vérification des serveurs…")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if servers.isEmpty {
                    Text("Aucun serveur MCP détecté")
                        .foregroundStyle(.secondary)
                    Text("Configurez des serveurs MCP dans .claude/settings.json pour étendre les capacités de l'assistant.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(servers) { server in
                        serverRow(server)
                    }
                }
            }

            Section {
                Button("Rafraîchir") {
                    Task { await loadServers() }
                }
                .disabled(isLoading)
                .help("Rafraîchir l'état des serveurs")
            }
        }
        .formStyle(.grouped)
        .task { await loadServers() }
    }

    private func serverRow(_ server: MCPServer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: server.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(server.isConnected ? .green : .red)
                Text(server.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(server.isConnected ? "Connecté" : "Déconnecté")
                    .font(.caption)
                    .foregroundStyle(server.isConnected ? .green : .red)
            }
            if !server.detail.isEmpty {
                Text(server.detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func loadServers() async {
        isLoading = true
        errorMessage = nil

        let output = await runClaudeMCPList()

        if let output {
            servers = parseMCPList(output)
        } else {
            errorMessage = "Impossible d'exécuter « claude mcp list ». Vérifiez que Claude Code est installé."
        }

        isLoading = false
    }

    private func runClaudeMCPList() async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["claude", "mcp", "list"]
            process.currentDirectoryURL = AppSettings.rootDirectory

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8))
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func parseMCPList(_ output: String) -> [MCPServer] {
        output.components(separatedBy: "\n")
            .filter { $0.contains(" - ") }
            .compactMap { line -> MCPServer? in
                // Format: "Name: command args - ✓ Connected" or "Name: url - ✗ Failed"
                guard let dashRange = line.range(of: " - ", options: .backwards) else { return nil }
                let prefix = String(line[line.startIndex..<dashRange.lowerBound])
                let statusPart = String(line[dashRange.upperBound...])
                let isConnected = statusPart.contains("✓")

                let parts = prefix.split(separator: ":", maxSplits: 1)
                let name = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? prefix
                let detail = parts.count > 1
                    ? String(parts[1]).trimmingCharacters(in: .whitespaces)
                    : ""

                return MCPServer(name: name, detail: detail, isConnected: isConnected)
            }
    }
}
