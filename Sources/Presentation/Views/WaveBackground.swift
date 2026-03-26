import SwiftUI

struct WaveBackground: View {
    var hue: Double = 0.60
    var saturation: Double = 1.0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 4,
            height: 4,
            points: [
                [0.0, 0.0], [0.35, 0.0], [0.7, 0.0], [1.0, 0.0],
                [0.0, 0.25], [0.3, 0.3], [0.65, 0.2], [1.0, 0.3],
                [0.0, 0.6], [0.25, 0.65], [0.7, 0.55], [1.0, 0.7],
                [0.0, 1.0], [0.4, 1.0], [0.7, 1.0], [1.0, 1.0],
            ],
            colors: meshColors
        )
        .ignoresSafeArea()
    }

    private var meshColors: [Color] {
        let h = hue
        let s = saturation
        let isDark = colorScheme == .dark
        let satScale: Double = isDark ? 1.0 : 0.45
        let bBase: Double = isDark ? 0.0 : 0.72
        let bScale: Double = isDark ? 1.0 : 0.18
        return [
            Color(hue: h - 0.02, saturation: 0.45 * s * satScale, brightness: bBase + 0.18 * bScale),
            Color(hue: h, saturation: 0.50 * s * satScale, brightness: bBase + 0.15 * bScale),
            Color(hue: h - 0.05, saturation: 0.40 * s * satScale, brightness: bBase + 0.20 * bScale),
            Color(hue: h + 0.02, saturation: 0.55 * s * satScale, brightness: bBase + 0.14 * bScale),

            Color(hue: h - 0.04, saturation: 0.50 * s * satScale, brightness: bBase + 0.22 * bScale),
            Color(hue: h + 0.01, saturation: 0.60 * s * satScale, brightness: bBase + 0.16 * bScale),
            Color(hue: h - 0.06, saturation: 0.45 * s * satScale, brightness: bBase + 0.25 * bScale),
            Color(hue: h - 0.01, saturation: 0.55 * s * satScale, brightness: bBase + 0.18 * bScale),

            Color(hue: h + 0.03, saturation: 0.55 * s * satScale, brightness: bBase + 0.13 * bScale),
            Color(hue: h - 0.03, saturation: 0.48 * s * satScale, brightness: bBase + 0.20 * bScale),
            Color(hue: h + 0.02, saturation: 0.58 * s * satScale, brightness: bBase + 0.15 * bScale),
            Color(hue: h - 0.05, saturation: 0.42 * s * satScale, brightness: bBase + 0.22 * bScale),

            Color(hue: h, saturation: 0.52 * s * satScale, brightness: bBase + 0.12 * bScale),
            Color(hue: h - 0.02, saturation: 0.48 * s * satScale, brightness: bBase + 0.16 * bScale),
            Color(hue: h + 0.03, saturation: 0.55 * s * satScale, brightness: bBase + 0.13 * bScale),
            Color(hue: h - 0.04, saturation: 0.45 * s * satScale, brightness: bBase + 0.18 * bScale),
        ]
    }
}
