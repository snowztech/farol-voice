import AppKit
import SwiftUI

/// The mic state stays visible: this shows for as long as the mic is open.
final class Pill {
    /// The newest mic level from 0 to 1, read by the drawing rather than published, so 20 updates a second cost SwiftUI nothing.
    var level: Double {
        get { signal.target }
        set { signal.target = newValue }
    }

    private let signal = VoiceSignal()
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

    func showListening() {
        signal.target = 0
        present(PillView(content: .listening, signal: signal), accessibility: "Listening")
    }

    func showWorking() {
        present(PillView(content: .working, signal: signal), accessibility: "Transcribing")
    }

    func flash(_ text: String, for seconds: TimeInterval = 3) {
        present(PillView(content: .message(text), signal: signal), accessibility: text)
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
private final class VoiceSignal {
    var target = 0.0
    private(set) var shown = 0.0

    func step() -> Double {
        shown += (target - shown) * (target > shown ? 0.45 : 0.14)
        return shown
    }
}

private struct PillView: View {
    enum Content {
        case listening
        case working
        case message(String)
    }

    let content: Content
    let signal: VoiceSignal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barCount = 7
    /// Tallest in the middle, so a voice reads as one shape and not a row of meters.
    private static let shape: [Double] = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45]
    private static let barWidth: CGFloat = 2.5
    private static let barGap: CGFloat = 2.5
    private static let height: CGFloat = 16
    private static let lowest: CGFloat = 3
    private static let beamSeconds = 1.3

    var body: some View {
        Group {
            switch content {
            case .listening: bars(sweeping: false)
            case .working: bars(sweeping: true)
            case .message(let text): Text(text).foregroundStyle(.white).lineLimit(1)
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color(white: 0.09), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .fixedSize()
        .padding(1)
    }

    private func bars(sweeping: Bool) -> some View {
        let width = CGFloat(Self.barCount) * Self.barWidth + CGFloat(Self.barCount - 1) * Self.barGap
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: sweeping && reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let level = sweeping ? 0 : signal.step()
                for bar in 0..<Self.barCount {
                    let x = CGFloat(bar) * (Self.barWidth + Self.barGap)
                    let height = sweeping ? Self.lowest : barHeight(bar, level: level, time: time)
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: Self.barWidth, height: height)
                    let opacity = sweeping ? beamOpacity(bar, time: time) : 0.6 + 0.4 * level
                    context.fill(Path(roundedRect: rect, cornerRadius: Self.barWidth / 2), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .frame(width: width, height: Self.height)
    }

    private func barHeight(_ bar: Int, level: Double, time: TimeInterval) -> CGFloat {
        // A little independent movement keeps it reading as a voice. With Reduce Motion, the height follows only the real level.
        let wobble = reduceMotion ? 1 : 0.78 + 0.22 * sin(time * 7 + Double(bar) * 1.4)
        return Self.lowest + (Self.height - Self.lowest) * CGFloat(level * Self.shape[bar] * wobble)
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
