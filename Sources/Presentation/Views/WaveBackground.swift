import SwiftUI

struct WaveBackground: View {
    var hue: Double = 0.60
    var saturation: Double = 1.0

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
        return [
            Color(hue: h - 0.02, saturation: 0.45 * s, brightness: 0.18),
            Color(hue: h, saturation: 0.50 * s, brightness: 0.15),
            Color(hue: h - 0.05, saturation: 0.40 * s, brightness: 0.20),
            Color(hue: h + 0.02, saturation: 0.55 * s, brightness: 0.14),

            Color(hue: h - 0.04, saturation: 0.50 * s, brightness: 0.22),
            Color(hue: h + 0.01, saturation: 0.60 * s, brightness: 0.16),
            Color(hue: h - 0.06, saturation: 0.45 * s, brightness: 0.25),
            Color(hue: h - 0.01, saturation: 0.55 * s, brightness: 0.18),

            Color(hue: h + 0.03, saturation: 0.55 * s, brightness: 0.13),
            Color(hue: h - 0.03, saturation: 0.48 * s, brightness: 0.20),
            Color(hue: h + 0.02, saturation: 0.58 * s, brightness: 0.15),
            Color(hue: h - 0.05, saturation: 0.42 * s, brightness: 0.22),

            Color(hue: h, saturation: 0.52 * s, brightness: 0.12),
            Color(hue: h - 0.02, saturation: 0.48 * s, brightness: 0.16),
            Color(hue: h + 0.03, saturation: 0.55 * s, brightness: 0.13),
            Color(hue: h - 0.04, saturation: 0.45 * s, brightness: 0.18),
        ]
    }
}
