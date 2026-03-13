import SwiftUI

struct WaveBackground: View {
    var body: some View {
        MeshGradient(
            width: 4,
            height: 4,
            points: [
                // Row 0
                [0.0, 0.0], [0.35, 0.0], [0.7, 0.0], [1.0, 0.0],
                // Row 1
                [0.0, 0.25], [0.3, 0.3], [0.65, 0.2], [1.0, 0.3],
                // Row 2
                [0.0, 0.6], [0.25, 0.65], [0.7, 0.55], [1.0, 0.7],
                // Row 3
                [0.0, 1.0], [0.4, 1.0], [0.7, 1.0], [1.0, 1.0],
            ],
            colors: [
                // Row 0
                Color(hue: 0.58, saturation: 0.45, brightness: 0.18),
                Color(hue: 0.60, saturation: 0.50, brightness: 0.15),
                Color(hue: 0.55, saturation: 0.40, brightness: 0.20),
                Color(hue: 0.62, saturation: 0.55, brightness: 0.14),
                // Row 1
                Color(hue: 0.56, saturation: 0.50, brightness: 0.22),
                Color(hue: 0.61, saturation: 0.60, brightness: 0.16),
                Color(hue: 0.54, saturation: 0.45, brightness: 0.25),
                Color(hue: 0.59, saturation: 0.55, brightness: 0.18),
                // Row 2
                Color(hue: 0.63, saturation: 0.55, brightness: 0.13),
                Color(hue: 0.57, saturation: 0.48, brightness: 0.20),
                Color(hue: 0.62, saturation: 0.58, brightness: 0.15),
                Color(hue: 0.55, saturation: 0.42, brightness: 0.22),
                // Row 3
                Color(hue: 0.60, saturation: 0.52, brightness: 0.12),
                Color(hue: 0.58, saturation: 0.48, brightness: 0.16),
                Color(hue: 0.63, saturation: 0.55, brightness: 0.13),
                Color(hue: 0.56, saturation: 0.45, brightness: 0.18),
            ]
        )
        .ignoresSafeArea()
    }
}
