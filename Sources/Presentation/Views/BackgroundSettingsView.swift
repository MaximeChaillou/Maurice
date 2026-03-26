import SwiftUI

struct TabInfo {
    let tab: AppTab
    let label: String
    let icon: String
}

struct BackgroundSettingsView: View {
    @Binding var appTheme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    private let tabs: [TabInfo] = [
        TabInfo(tab: .meeting, label: String(localized: "Meetings"), icon: "calendar"),
        TabInfo(tab: .people, label: String(localized: "People"), icon: "person.2"),
        TabInfo(tab: .task, label: String(localized: "Tasks"), icon: "checklist"),
    ]

    var body: some View {
        Form {
            Section("Color per tab") {
                ForEach(tabs, id: \.tab) { item in
                    HStack {
                        Label(item.label, systemImage: item.icon)
                        Spacer()
                        ColorPicker(
                            "",
                            selection: hueBinding(for: item.tab),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                }
            }

            Section {
                HStack {
                    Text("Preview")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack(spacing: 12) {
                    ForEach(tabs, id: \.tab) { item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(previewColor(for: item.tab))
                                .frame(height: 60)
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func hueBinding(for tab: AppTab) -> Binding<Color> {
        Binding(
            get: {
                Color(hue: appTheme.hue(for: tab), saturation: 0.55, brightness: 0.50)
            },
            set: { newColor in
                let nsColor = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                var h: CGFloat = 0
                nsColor.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
                appTheme.setHue(Double(h), for: tab)
            }
        )
    }

    private func previewColor(for tab: AppTab) -> Color {
        let isDark = colorScheme == .dark
        return Color(
            hue: appTheme.hue(for: tab),
            saturation: isDark ? 0.55 : 0.30,
            brightness: isDark ? 0.20 : 0.85
        )
    }
}
