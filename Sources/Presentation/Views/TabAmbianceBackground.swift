import SwiftUI

enum TabAmbiance: CaseIterable, Hashable {
    case home
    case meetings
    case people
    case tasks

    static func resolve(showHome: Bool, activeTab: AppTab) -> TabAmbiance {
        guard !showHome else { return .home }
        switch activeTab {
        case .meeting: return .meetings
        case .people: return .people
        case .task: return .tasks
        }
    }
}

struct TabAmbianceBackground: View {
    let ambiance: TabAmbiance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ForEach(TabAmbiance.allCases, id: \.self) { entry in
                AmbianceLayer(palette: entry.palette(isDark: colorScheme == .dark))
                    .opacity(entry == ambiance ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: ambiance)
    }
}

private struct AmbianceLayer: View {
    let palette: AmbiancePalette

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                radialBlob(
                    stops: [
                        .init(color: palette.baseInner, location: 0),
                        .init(color: palette.baseMid, location: 0.55),
                        .init(color: palette.baseOuter, location: 1),
                    ],
                    centerFraction: CGPoint(x: 0.5, y: 0.5),
                    radiusFraction: CGSize(width: 0.9, height: 0.7),
                    in: size
                )

                radialBlob(
                    stops: [
                        .init(color: palette.highlight1, location: 0),
                        .init(color: palette.highlight1.opacity(0), location: 0.6),
                    ],
                    centerFraction: palette.highlight1Center,
                    radiusFraction: CGSize(width: 0.7, height: 0.55),
                    in: size
                )

                radialBlob(
                    stops: [
                        .init(color: palette.highlight2, location: 0),
                        .init(color: palette.highlight2.opacity(0), location: 0.65),
                    ],
                    centerFraction: palette.highlight2Center,
                    radiusFraction: CGSize(width: 0.6, height: 0.5),
                    in: size
                )
            }
        }
    }

    private func radialBlob(
        stops: [Gradient.Stop],
        centerFraction: CGPoint,
        radiusFraction: CGSize,
        in size: CGSize
    ) -> some View {
        Rectangle()
            .fill(EllipticalGradient(
                stops: stops,
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 1
            ))
            .frame(
                width: size.width * radiusFraction.width * 2,
                height: size.height * radiusFraction.height * 2
            )
            .position(
                x: size.width * centerFraction.x,
                y: size.height * centerFraction.y
            )
    }
}

private struct AmbiancePalette {
    let baseInner: Color
    let baseMid: Color
    let baseOuter: Color
    let highlight1: Color
    let highlight1Center: CGPoint
    let highlight2: Color
    let highlight2Center: CGPoint
}

private extension TabAmbiance {
    func palette(isDark: Bool) -> AmbiancePalette {
        isDark ? darkPalette : lightPalette
    }

    var lightPalette: AmbiancePalette {
        switch self {
        case .home:
            AmbiancePalette(
                baseInner: Color(rgb: 0xEEEAE4),
                baseMid: Color(rgb: 0xE4DFD7),
                baseOuter: Color(rgb: 0xDAD4CA),
                highlight1: Color(red: 255, green: 248, blue: 236, alpha: 0.85),
                highlight1Center: CGPoint(x: 0.78, y: 0.18),
                highlight2: Color(red: 218, green: 212, blue: 205, alpha: 0.55),
                highlight2Center: CGPoint(x: 0.15, y: 0.85)
            )
        case .meetings:
            AmbiancePalette(
                baseInner: Color(rgb: 0xE6ECF1),
                baseMid: Color(rgb: 0xDCE4EB),
                baseOuter: Color(rgb: 0xCFD8E1),
                highlight1: Color(red: 200, green: 230, blue: 240, alpha: 0.65),
                highlight1Center: CGPoint(x: 0.22, y: 0.18),
                highlight2: Color(red: 180, green: 210, blue: 230, alpha: 0.40),
                highlight2Center: CGPoint(x: 0.85, y: 0.85)
            )
        case .people:
            AmbiancePalette(
                baseInner: Color(rgb: 0xECEDE6),
                baseMid: Color(rgb: 0xE2E4DB),
                baseOuter: Color(rgb: 0xD5D8CE),
                highlight1: Color(red: 220, green: 235, blue: 220, alpha: 0.70),
                highlight1Center: CGPoint(x: 0.28, y: 0.22),
                highlight2: Color(red: 240, green: 220, blue: 205, alpha: 0.50),
                highlight2Center: CGPoint(x: 0.82, y: 0.80)
            )
        case .tasks:
            AmbiancePalette(
                baseInner: Color(rgb: 0xE8E7EC),
                baseMid: Color(rgb: 0xDCDCE4),
                baseOuter: Color(rgb: 0xCDCED6),
                highlight1: Color(red: 228, green: 220, blue: 240, alpha: 0.60),
                highlight1Center: CGPoint(x: 0.75, y: 0.20),
                highlight2: Color(red: 210, green: 218, blue: 230, alpha: 0.50),
                highlight2Center: CGPoint(x: 0.15, y: 0.82)
            )
        }
    }

    var darkPalette: AmbiancePalette {
        switch self {
        case .home:
            AmbiancePalette(
                baseInner: Color(rgb: 0x2A2622),
                baseMid: Color(rgb: 0x221E1B),
                baseOuter: Color(rgb: 0x1A1715),
                highlight1: Color(red: 90, green: 70, blue: 50, alpha: 0.35),
                highlight1Center: CGPoint(x: 0.78, y: 0.18),
                highlight2: Color(red: 40, green: 35, blue: 30, alpha: 0.60),
                highlight2Center: CGPoint(x: 0.15, y: 0.85)
            )
        case .meetings:
            AmbiancePalette(
                baseInner: Color(rgb: 0x1E2430),
                baseMid: Color(rgb: 0x1A1F29),
                baseOuter: Color(rgb: 0x151921),
                highlight1: Color(red: 60, green: 100, blue: 130, alpha: 0.35),
                highlight1Center: CGPoint(x: 0.22, y: 0.18),
                highlight2: Color(red: 35, green: 50, blue: 70, alpha: 0.55),
                highlight2Center: CGPoint(x: 0.85, y: 0.85)
            )
        case .people:
            AmbiancePalette(
                baseInner: Color(rgb: 0x232723),
                baseMid: Color(rgb: 0x1F231F),
                baseOuter: Color(rgb: 0x181B18),
                highlight1: Color(red: 60, green: 90, blue: 70, alpha: 0.35),
                highlight1Center: CGPoint(x: 0.28, y: 0.22),
                highlight2: Color(red: 80, green: 55, blue: 45, alpha: 0.45),
                highlight2Center: CGPoint(x: 0.82, y: 0.80)
            )
        case .tasks:
            AmbiancePalette(
                baseInner: Color(rgb: 0x22222A),
                baseMid: Color(rgb: 0x1D1D25),
                baseOuter: Color(rgb: 0x16161D),
                highlight1: Color(red: 70, green: 60, blue: 95, alpha: 0.35),
                highlight1Center: CGPoint(x: 0.75, y: 0.20),
                highlight2: Color(red: 45, green: 55, blue: 75, alpha: 0.50),
                highlight2Center: CGPoint(x: 0.15, y: 0.82)
            )
        }
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    init(red: Int, green: Int, blue: Int, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: alpha
        )
    }
}
