import SwiftUI

struct AudioWaveformView: View {
    let buffer: AudioLevelBuffer

    private let waveCount = 5
    private let pointCount = 80

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let levels = buffer.snapshot()
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawWaves(context: context, size: size, time: time, levels: levels)
            }
        }
        .frame(height: 80)
    }

    private func drawWaves(context: GraphicsContext, size: CGSize, time: Double, levels: [Float]) {
        let midY = size.height / 2
        let gradient = Gradient(colors: [.purple, .cyan])
        let linearGradient = GraphicsContext.Shading.linearGradient(
            gradient,
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: 0)
        )

        let sortedWaves = (0..<waveCount).sorted {
            abs(Double($0) - Double(waveCount - 1) / 2.0) > abs(Double($1) - Double(waveCount - 1) / 2.0)
        }

        for wave in sortedWaves {
            let points = wavePoints(wave: wave, size: size, time: time, levels: levels)
            drawWaveFill(context: context, points: points, midY: midY, shading: linearGradient)
            drawWaveStroke(context: context, points: points, shading: linearGradient)
        }
    }

    private func wavePoints(wave: Int, size: CGSize, time: Double, levels: [Float]) -> [CGPoint] {
        let midY = size.height / 2
        let w = Double(wave)
        let speed = 1.2 + w * 0.4
        let phase = w * 1.7
        let freqBase = 2.5 + w * 0.8
        let halfWave = Double(waveCount - 1) / 2.0

        var points: [CGPoint] = []
        for i in 0...pointCount {
            let x = size.width * CGFloat(i) / CGFloat(pointCount)
            let t = Double(i) / Double(pointCount)
            let level = amplitudeAt(t: t, levels: levels)

            let wave1 = 0.06 * sin(t * .pi * freqBase + time * speed + phase)
            let wave2 = 0.03 * sin(t * .pi * (freqBase + 2.3) + time * (speed * 0.7) + phase * 1.5)
            let wave3 = 0.02 * cos(t * .pi * (freqBase + 4.1) + time * (speed * 1.3) + phase * 0.6)
            let idle = wave1 + wave2 + wave3

            let spread = (w - halfWave) / Double(waveCount)
            let soundwave = level * spread
            let displacement = (idle + soundwave) * size.height * 0.45

            points.append(CGPoint(x: x, y: midY + CGFloat(displacement)))
        }
        return points
    }

    private func drawWaveFill(context: GraphicsContext, points: [CGPoint], midY: CGFloat, shading: GraphicsContext.Shading) {
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: points[0].x, y: midY))
        for p in points {
            fillPath.addLine(to: p)
        }
        fillPath.addLine(to: CGPoint(x: points[points.count - 1].x, y: midY))
        fillPath.closeSubpath()

        var fillCtx = context
        fillCtx.opacity = 0.08
        fillCtx.fill(fillPath, with: shading)
    }

    private func drawWaveStroke(context: GraphicsContext, points: [CGPoint], shading: GraphicsContext.Shading) {
        var strokePath = Path()
        for (i, p) in points.enumerated() {
            if i == 0 {
                strokePath.move(to: p)
            } else {
                strokePath.addLine(to: p)
            }
        }

        var strokeCtx = context
        strokeCtx.opacity = 0.6
        strokeCtx.stroke(strokePath, with: shading, lineWidth: 1.5)
    }

    private func amplitudeAt(t: Double, levels: [Float]) -> Double {
        guard !levels.isEmpty else { return 0 }

        let floatIndex = t * Double(levels.count - 1)
        let low = Int(floatIndex)
        let high = min(low + 1, levels.count - 1)
        let frac = floatIndex - Double(low)

        let interpolated = Double(levels[low]) * (1 - frac) + Double(levels[high]) * frac
        return min(interpolated * 80.0, 1.0)
    }
}
