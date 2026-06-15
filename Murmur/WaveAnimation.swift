import SwiftUI

/// The recording animation: a smooth, flowing mirrored waveform ribbon with a
/// soft glow, drawn with Canvas + TimelineView. Monochrome accent (minimal).
struct FlowWaveView: View {
    let levels: [CGFloat]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                FlowWaveView.draw(context, size, levels,
                                  timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private static func draw(_ context: GraphicsContext, _ size: CGSize,
                             _ levels: [CGFloat], _ t: TimeInterval) {
        let n = levels.count
        guard n > 1 else { return }
        let w = size.width, h = size.height
        let midY = h / 2
        let maxAmp = h * 0.46
        let stepX = w / CGFloat(n - 1)
        let accent = Color.accentColor

        func amp(_ i: Int) -> CGFloat {
            let flow = 0.82 + 0.18 * sin(t * 2.1 + Double(i) * 0.5)
            return max(1.0, levels[i] * maxAmp * CGFloat(flow))
        }

        var topPts: [CGPoint] = []
        var botPts: [CGPoint] = []
        for i in 0..<n {
            let x = CGFloat(i) * stepX
            let a = amp(i)
            topPts.append(CGPoint(x: x, y: midY - a))
            botPts.append(CGPoint(x: x, y: midY + a))
        }

        func appendSmooth(_ path: inout Path, _ pts: [CGPoint], start: Bool) {
            if start { path.move(to: pts[0]) } else { path.addLine(to: pts[0]) }
            for i in 0..<pts.count - 1 {
                let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2,
                                  y: (pts[i].y + pts[i + 1].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i])
            }
            path.addLine(to: pts[pts.count - 1])
        }

        var body = Path()
        appendSmooth(&body, topPts, start: true)
        appendSmooth(&body, Array(botPts.reversed()), start: false)
        body.closeSubpath()

        // Soft glow underneath.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.fill(body, with: .color(accent.opacity(0.45)))
        }
        // Gradient body — bright at the centerline, fading toward the edges.
        context.fill(body, with: .linearGradient(
            Gradient(colors: [accent.opacity(0.20), accent.opacity(0.85), accent.opacity(0.20)]),
            startPoint: CGPoint(x: w / 2, y: 0),
            endPoint: CGPoint(x: w / 2, y: h)))
        // Crisp edges.
        var topLine = Path(); appendSmooth(&topLine, topPts, start: true)
        context.stroke(topLine, with: .color(accent), lineWidth: 1.2)
        var botLine = Path(); appendSmooth(&botLine, botPts, start: true)
        context.stroke(botLine, with: .color(accent.opacity(0.7)), lineWidth: 1.0)
    }
}
