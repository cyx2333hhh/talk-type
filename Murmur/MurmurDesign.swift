import SwiftUI
import AppKit

enum MurmurPalette {
    static let accent = Color(red: 0.28, green: 0.78, blue: 0.68)
    static let accentBright = Color(red: 0.56, green: 0.91, blue: 0.84)
    static let recording = Color(red: 0.96, green: 0.34, blue: 0.32)
    static let success = Color(red: 0.33, green: 0.72, blue: 0.52)
    static let warning = Color(red: 0.93, green: 0.62, blue: 0.25)
    static let graphite = Color(red: 0.065, green: 0.075, blue: 0.08)

    static let surface = Color(nsColor: .controlBackgroundColor)
    static let raisedSurface = Color(nsColor: .underPageBackgroundColor)
    static let hairline = Color(nsColor: .separatorColor).opacity(0.55)
    static let quietFill = Color(nsColor: .labelColor).opacity(0.055)
}

enum MurmurMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let state = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let gentle = Animation.easeInOut(duration: 0.28)
}

/// The in-app microphone symbol. Branding uses the T mark, while recording
/// controls stay immediately recognizable as voice input.
struct VoiceCursorSymbol: View {
    var level: CGFloat = 0.12
    var tint: Color = MurmurPalette.accent
    var active = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let amount = max(0.04, min(1, level))
            let centerX = size.width / 2
            let centerY = size.height / 2
            let strokeWidth = max(1.35, size.width * 0.055)
            let bodyWidth = size.width * 0.27
            let bodyHeight = size.height * (0.40 + (active ? amount * 0.035 : 0))
            let bodyRect = CGRect(x: centerX - bodyWidth / 2,
                                  y: centerY - size.height * 0.27,
                                  width: bodyWidth,
                                  height: bodyHeight)
            let body = Path(roundedRect: bodyRect, cornerRadius: bodyWidth / 2)

            if active {
                context.fill(body, with: .color(tint.opacity(0.12 + amount * 0.08)))
            }
            context.stroke(body,
                           with: .color(tint.opacity(0.94)),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            let cursorWidth = max(1.7, size.width * 0.06)
            let cursorHeight = bodyHeight * (0.50 + (active ? amount * 0.09 : 0))
            let cursorRect = CGRect(x: centerX - cursorWidth / 2,
                                    y: bodyRect.midY - cursorHeight / 2,
                                    width: cursorWidth,
                                    height: cursorHeight)
            context.fill(Path(roundedRect: cursorRect, cornerRadius: cursorWidth / 2),
                         with: .color(.white.opacity(0.96)))

            var yoke = Path()
            let halfWidth = size.width * (0.205 + (active ? amount * 0.012 : 0))
            let shoulderY = centerY + size.height * 0.025
            let baseY = centerY + size.height * 0.225
            yoke.move(to: CGPoint(x: centerX - halfWidth, y: shoulderY))
            yoke.addCurve(to: CGPoint(x: centerX + halfWidth, y: shoulderY),
                          control1: CGPoint(x: centerX - halfWidth, y: baseY),
                          control2: CGPoint(x: centerX + halfWidth, y: baseY))
            context.stroke(yoke,
                           with: .color(tint.opacity(0.94)),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            var stand = Path()
            let standTop = centerY + size.height * 0.17
            let standBottom = centerY + size.height * 0.34
            stand.move(to: CGPoint(x: centerX, y: standTop))
            stand.addLine(to: CGPoint(x: centerX, y: standBottom))
            stand.move(to: CGPoint(x: centerX - size.width * 0.12, y: standBottom))
            stand.addLine(to: CGPoint(x: centerX + size.width * 0.12, y: standBottom))
            context.stroke(stand,
                           with: .color(tint.opacity(0.94)),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }
}

struct ShortcutKeyCap: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 10.5 : 12,
                          weight: .semibold,
                          design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, compact ? 7 : 9)
            .frame(height: compact ? 22 : 26)
            .background(MurmurPalette.quietFill, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(MurmurPalette.hairline, lineWidth: 0.5)
            }
            .accessibilityLabel("快捷键 \(text)")
    }
}
