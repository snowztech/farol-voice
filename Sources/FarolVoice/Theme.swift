import AppKit
import SwiftUI

/// Farol's Beam theme, mixed the way Farol mixes its panels, so the two apps look like one family.
enum Theme {
    private static let backgroundColor = NSColor(srgbRed: 0x0d / 255, green: 0x10 / 255, blue: 0x18 / 255, alpha: 1)
    private static let foregroundColor = NSColor(srgbRed: 0xdf / 255, green: 0xe3 / 255, blue: 0xec / 255, alpha: 1)

    private static func mixed(_ amount: CGFloat) -> Color {
        Color(nsColor: backgroundColor.blended(withFraction: amount, of: foregroundColor) ?? backgroundColor)
    }

    static let window = backgroundColor
    static let background = Color(nsColor: backgroundColor)
    static let surface = mixed(0.035)
    static let raised = mixed(0.085)
    static let line = mixed(0.11)
    static let text = Color(nsColor: foregroundColor)
    static let muted = mixed(0.55)
    static let control = mixed(0.42)
    /// The lighthouse's beam. Used only for what's alive right now, so it stays meaningful.
    static let beam = Color(red: 0x71 / 255, green: 0xad / 255, blue: 0xff / 255)
    static let warning = Color(red: 0xea / 255, green: 0xc6 / 255, blue: 0x72 / 255)
}

struct Heading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}

/// A small heading between rows, a step above them, with no rule of its own.
struct GroupTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .padding(.top, 22)
            .padding(.bottom, 2)
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var note: String? = nil
    var detail: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 13))
                    if let note {
                        Text(note).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                    }
                }
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            control
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// A tab at the top of Settings, with the quiet highlight Farol uses for what's selected.
struct TabItem: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 15, weight: .regular)).frame(height: 18)
                Text(title).font(.system(size: 11, weight: selected ? .medium : .regular))
            }
            .foregroundStyle(selected || hovering ? Theme.text : Theme.muted)
            .frame(width: 72)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Theme.raised : hovering ? Theme.surface : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Plain words that light up under the mouse. The prominent kind is for the one thing to do next.
struct QuietButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: prominent ? .medium : .regular))
                .foregroundStyle(prominent || hovering ? Theme.text : Theme.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(prominent ? Theme.raised : hovering ? Theme.surface : .clear))
                .overlay {
                    if prominent { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .onHover { hovering = $0 }
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
    }
}

/// Lays out chips left to right, wrapping when a line is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let placed = positions(of: subviews, width: width)
        return CGSize(width: proposal.width ?? placed.width, height: placed.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = positions(of: subviews, width: bounds.width)
        for (subview, point) in zip(subviews, placed.points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func positions(of subviews: Subviews, width: CGFloat) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            widest = max(widest, x - spacing)
            line = max(line, size.height)
        }
        return (points, widest, y + line)
    }
}
