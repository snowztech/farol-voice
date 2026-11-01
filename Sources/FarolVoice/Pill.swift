import AppKit
import SwiftUI

enum WaveSize: String, CaseIterable, Identifiable {
    case compact, large

    var id: String { rawValue }
    var title: String { self == .compact ? "Compact" : "Large" }
    var barWidth: CGFloat { self == .compact ? 2.5 : 3.5 }
    var barGap: CGFloat { self == .compact ? 2.5 : 3.5 }
    var tallest: CGFloat { self == .compact ? 16 : 28 }
    var lowest: CGFloat { self == .compact ? 3 : 4 }
    var pillHeight: CGFloat { self == .compact ? 30 : 46 }
    var padding: CGFloat { self == .compact ? 14 : 20 }
    var textSize: CGFloat { self == .compact ? 11.5 : 13 }
}

/// The mic state stays visible: this shows for as long as the mic is open.
final class Pill {
    /// The newest mic level from 0 to 1, read by the drawing rather than published, so 20 updates a second cost SwiftUI nothing.
    var level: Double {
        get { signal.target }
        set { signal.target = newValue }
    }

    private let signal = VoiceSignal()
    private let preferences: Preferences
    private var hideLater: DispatchWorkItem?
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.alphaValue = 0
        return panel
    }()

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func showListening() {
        signal.target = 0
        present(PillView(content: .listening, signal: signal, size: preferences.waveSize), accessibility: "Listening")
    }

    func showWorking() {
        present(PillView(content: .working, signal: signal, size: preferences.waveSize), accessibility: "Transcribing")
    }

    func flash(_ text: String, for seconds: TimeInterval = 3) {
        present(PillView(content: .message(text), signal: signal, size: preferences.waveSize), accessibility: text)
        let later = DispatchWorkItem { [weak self] in self?.hide() }
        hideLater = later
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: later)
    }

    /// Fast on purpose, since this appears every time you talk.
    private func present(_ view: PillView, accessibility: String) {
        hideLater?.cancel()
        let host = NSHostingView(rootView: view)
        host.setAccessibilityLabel("Farol Voice: \(accessibility)")
        panel.contentView = host
        let size = host.fittingSize
        let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.minY + 24, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        fade(to: 1, over: 0.12, curve: CAMediaTimingFunction(controlPoints: 0.165, 0.84, 0.44, 1))
    }

    func hide() {
        hideLater?.cancel()
        fade(to: 0, over: 0.1, curve: CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)) { [weak self] in
            guard let self, panel.alphaValue == 0 else { return }
            panel.orderOut(nil)
            // Removing the view stops its animation, so nothing draws between uses.
            panel.contentView = nil
        }
    }

    private func fade(to alpha: CGFloat, over duration: TimeInterval, curve: CAMediaTimingFunction, then done: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = curve
            panel.animator().alphaValue = alpha
        }, completionHandler: done)
    }
}

/// Between updates, the bars ease toward the latest level: quick to rise with your voice, slower to fall.
final class VoiceSignal {
    var target = 0.0
    private(set) var shown = 0.0

    func step() -> Double {
        shown += (target - shown) * (target > shown ? 0.45 : 0.14)
        return shown
    }
}

struct PillView: View {
    enum Content {
        case listening
        case working
        case message(String)
    }

    let content: Content
    let signal: VoiceSignal
    var size = WaveSize.compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barCount = 7
    /// Tallest in the middle, so a voice reads as one shape and not a row of meters.
    private static let shape: [Double] = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45]
    private static let beamSeconds = 1.3

    var body: some View {
        ZStack {
            switch content {
            case .listening: bars(sweeping: false)
            case .working: bars(sweeping: true)
            case .message(let text): Text(text).foregroundStyle(Theme.text).lineLimit(1)
            }
        }
        .font(.system(size: size.textSize, weight: .medium))
        .padding(.horizontal, size.padding)
        .frame(height: size.pillHeight)
        .background {
            // A Capsule's outline drew stray straight segments at its sides here, so the rounding is explicit.
            let shape = RoundedRectangle(cornerRadius: size.pillHeight / 2, style: .circular)
            shape.fill(Theme.background)
            shape.strokeBorder(Theme.line, lineWidth: 1)
        }
        .fixedSize()
        // Room for the rounded edge, since the window's size can round down by a fraction of a point.
        .padding(2)
    }

    private func bars(sweeping: Bool) -> some View {
        let width = CGFloat(Self.barCount) * size.barWidth + CGFloat(Self.barCount - 1) * size.barGap
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: sweeping && reduceMotion)) { timeline in
            Canvas { context, canvas in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let level = sweeping ? 0 : signal.step()
                for bar in 0..<Self.barCount {
                    let x = CGFloat(bar) * (size.barWidth + size.barGap)
                    let height = sweeping ? size.lowest : barHeight(bar, level: level, time: time)
                    let rect = CGRect(x: x, y: (canvas.height - height) / 2, width: size.barWidth, height: height)
                    let opacity = sweeping ? beamOpacity(bar, time: time) : 0.6 + 0.4 * level
                    // The beam's blue while it thinks, and plain while it listens, like the two colors in Farol's icon.
                    let color = sweeping ? Theme.beam : Theme.text
                    context.fill(Path(roundedRect: rect, cornerRadius: size.barWidth / 2), with: .color(color.opacity(opacity)))
                }
            }
        }
        .frame(width: width, height: size.tallest)
    }

    private func barHeight(_ bar: Int, level: Double, time: TimeInterval) -> CGFloat {
        // A little independent movement keeps it reading as a voice. With Reduce Motion, the height follows only the real level.
        let wobble = reduceMotion ? 1 : 0.78 + 0.22 * sin(time * 7 + Double(bar) * 1.4)
        return size.lowest + (size.tallest - size.lowest) * CGFloat(level * Self.shape[bar] * wobble)
    }

    /// Farol means lighthouse: while it thinks, a soft beam passes across the bars at a steady pace.
    private func beamOpacity(_ bar: Int, time: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.5 }
        let progress = time.truncatingRemainder(dividingBy: Self.beamSeconds) / Self.beamSeconds
        let beam = progress * Double(Self.barCount + 3) - 1.5
        let distance = Double(bar) - beam
        return 0.22 + 0.78 * exp(-distance * distance / 2.2)
    }
}
