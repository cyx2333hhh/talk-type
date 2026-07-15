import SwiftUI

/// A single continuous audio trace. The curve is driven only by recent input
/// levels, so its motion communicates sound instead of adding ambient effects.
struct VoiceTraceView: View {
    let levels: [CGFloat]
    let level: CGFloat
    var tint = MurmurPalette.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let midY = size.height / 2

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline,
                           with: .color(Color.primary.opacity(0.085)),
                           style: StrokeStyle(lineWidth: 0.7, lineCap: .round))

            let points = tracePoints(in: size)
            let trace = smoothPath(points)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 2.2))
                glow.stroke(trace,
                            with: .color(tint.opacity(0.18)),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            }
            context.stroke(trace,
                           with: .color(tint.opacity(0.92)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.11), value: levels)
        .accessibilityHidden(true)
    }

    private func tracePoints(in size: CGSize) -> [CGPoint] {
        let pointCount = 31
        let recent = Array(levels.suffix(pointCount))
        let fallback = max(0.03, min(1, level))
        let midY = size.height / 2

        return (0..<pointCount).map { index in
            let progress = CGFloat(index) / CGFloat(pointCount - 1)
            let source = index < recent.count ? recent[index] : fallback
            let normalized = max(0.025, min(1, source))
            let edgeEnvelope = pow(sin(.pi * progress), 0.58)
            let direction = sin(progress * .pi * 5.2)
            let amplitude = (1.4 + normalized * size.height * 0.38) * edgeEnvelope
            return CGPoint(x: progress * size.width,
                           y: midY + direction * amplitude)
        }
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        guard let first = points.first else { return Path() }
        var path = Path()
        path.move(to: first)

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(x: (previous.x + current.x) / 2,
                                   y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midpoint, control: previous)
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }
}
