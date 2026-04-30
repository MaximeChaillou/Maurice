import SwiftUI

// MARK: - Tab Screen Layout

/// Two-column layout shared by Meetings and People: a glass sidebar on the left
/// and a detail pane on the right.
struct TabScreenLayout<Sidebar: View, Detail: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            sidebar()
            detail()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
    }
}

// MARK: - Glass Sidebar

struct GlassSidebar<Content: View>: View {
    let title: LocalizedStringKey
    var addHelp: LocalizedStringKey?
    var onAdd: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .tracking(-0.2)
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(Color.primary.opacity(0.06), in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .help(addHelp ?? "")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 248)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Sidebar Section Label

struct SidebarSectionLabel: View {
    let title: LocalizedStringKey

    init(title: String) {
        self.title = LocalizedStringKey(title)
    }

    init(title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.system(size: 9.5, weight: .bold))
            .kerning(1.1)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    enum Leading {
        case emoji(String)
        case symbol(String)
        case initials(String, gradient: [Color])
        case none
    }

    let title: String
    var subtitle: String?
    var trailing: String?
    var leading: Leading = .none
    var dot: Bool = false
    var active: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                leadingView
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? .primary : .secondary)
                            .lineLimit(1)
                        if dot {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 5, height: 5)
                        }
                    }
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 10.5, weight: active ? .semibold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(active ? AnyShapeStyle(Color.cyan) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5)
                        }
                }
            }
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: 14))
                .frame(width: 22)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
        case .initials(let initials, let gradient):
            Text(initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        }
                }
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Tab Doc Header (defined in TabDocHeader.swift)

// MARK: - Tab Content Card

struct TabContentCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: 14))
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Tab Detail Scaffold

/// Standard detail layout: a doc header on top, a glass content card below.
struct TabDetailScaffold<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            header()
            TabContentCard(content: content)
        }
    }
}

// MARK: - Sidebar Empty State

struct SidebarEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Initials Helpers

enum AvatarColors {
    /// Deterministic gradient for a given seed string (e.g. person name).
    /// Returns a pair of Colors usable in a LinearGradient.
    static func gradient(for seed: String) -> [Color] {
        let palette: [(Color, Color)] = [
            (Color(red: 0.49, green: 0.78, blue: 0.83), Color(red: 0.23, green: 0.55, blue: 0.61)),
            (Color(red: 0.83, green: 0.66, blue: 0.49), Color(red: 0.61, green: 0.42, blue: 0.23)),
            (Color(red: 0.64, green: 0.64, blue: 0.72), Color(red: 0.37, green: 0.37, blue: 0.47)),
            (Color(red: 0.83, green: 0.64, blue: 0.78), Color(red: 0.61, green: 0.30, blue: 0.52)),
            (Color(red: 0.63, green: 0.78, blue: 0.62), Color(red: 0.35, green: 0.54, blue: 0.35)),
            (Color(red: 0.78, green: 0.66, blue: 0.49), Color(red: 0.54, green: 0.42, blue: 0.23)),
            (Color(red: 0.49, green: 0.69, blue: 0.83), Color(red: 0.23, green: 0.45, blue: 0.61))
        ]
        let hash = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let pair = palette[abs(hash) % palette.count]
        return [pair.0, pair.1]
    }

    /// Up to two initials taken from the first two whitespace-separated chunks.
    static func initials(for name: String) -> String {
        let parts = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .prefix(2)
        let chars = parts.compactMap { $0.first.map { String($0) } }
        let combined = chars.joined()
        return combined.isEmpty ? "?" : combined.uppercased()
    }
}
