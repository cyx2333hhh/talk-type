import SwiftUI

/// A quiet, premium spectrum for dictation state.
/// It avoids decorative assistant-orb styling and behaves like a system status
/// indicator: low contrast, audio-reactive, and compact.
struct SpectralWaveView: View {
    let levels: [CGFloat]
    let level: CGFloat

    private let barCount = 19

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(context, size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize, time: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }

        let accent = Color.accentColor
        let height = size.height
        let width = size.width
        let midY = height / 2
        let gap: CGFloat = 4
        let barWidth = max(2.4, (width - gap * CGFloat(barCount - 1)) / CGFloat(barCount))
        let recent = Array(levels.suffix(barCount))
        let fallback = max(0.03, min(1, level))

        for i in 0..<barCount {
            let source = i < recent.count ? recent[i] : fallback
            let progress = CGFloat(i) / CGFloat(max(1, barCount - 1))
            let centerWeight = 0.58 + 0.42 * sin(.pi * progress)
            let shimmer = CGFloat(0.88 + 0.12 * sin(time * 2.1 + Double(i) * 0.58))
            let normalized = max(0.035, min(1, source))
            let visual = min(1, normalized * centerWeight * shimmer)
            let barHeight = max(3.2, min(height * 0.92, 3.2 + visual * height * 0.82))
            let x = CGFloat(i) * (barWidth + gap)
            let y = midY - barHeight / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            let opacity = 0.22 + min(0.56, visual * 0.62)

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 1.6))
                layer.fill(path, with: .color(accent.opacity(opacity * 0.28)))
            }

            context.fill(path, with: .linearGradient(
                Gradient(colors: [
                    accent.opacity(opacity * 0.52),
                    accent.opacity(opacity),
                    accent.opacity(opacity * 0.52),
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
        }
    }
}
