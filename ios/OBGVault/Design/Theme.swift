import SwiftUI

/// Dark, high-contrast look: near-black surfaces, hairline borders, one sharp accent.
enum Theme {
    static let bg = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let raised = Color(red: 0.11, green: 0.11, blue: 0.125)
    static let hairline = Color.white.opacity(0.09)
    static let text = Color.white
    static let muted = Color.white.opacity(0.52)
    static let faint = Color.white.opacity(0.32)
    static let accent = Color(red: 0.72, green: 1.0, blue: 0.24) // signal lime
    static let danger = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let warn = Color(red: 1.0, green: 0.72, blue: 0.2)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// Small uppercase, tracked label: "LEDGER", "REQUESTS".
struct Eyebrow: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text.uppercased()).font(Theme.mono(11, .semibold)).tracking(1.6).foregroundStyle(Theme.muted)
            Spacer()
            if let trailing { Text(trailing.uppercased()).font(Theme.mono(11)).tracking(1.2).foregroundStyle(Theme.faint) }
        }
        .padding(.horizontal, 4)
    }
}

struct Pill: View {
    let text: String
    var color: Color = Theme.accent
    var pulsing = false
    @State private var on = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
                .opacity(pulsing && on ? 0.25 : 1)
                .animation(pulsing ? .easeInOut(duration: 0.8).repeatForever() : .default, value: on)
            Text(text.uppercased()).font(Theme.mono(10, .semibold)).tracking(1.2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3)))
        .onAppear { on = true }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Check: View {
    let ok: Bool
    var body: some View {
        Image(systemName: ok ? "checkmark" : "xmark")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(ok ? .black : Theme.danger)
            .frame(width: 22, height: 22)
            .background(ok ? Theme.accent : Theme.danger.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Dark text field with a hairline border.
struct Field: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(Theme.mono(10, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
            TextField("", text: $text, prompt: Text(label).foregroundStyle(Theme.faint))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(12)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
        }
    }
}

extension String {
    /// 0x1234…abcd
    var shortHex: String { count > 14 ? "\(prefix(6))…\(suffix(4))" : self }
}

struct Screen<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle.uppercased()).font(Theme.mono(11, .semibold)).tracking(2).foregroundStyle(Theme.accent)
                    Text(title).font(.system(size: 34, weight: .heavy)).tracking(-0.8).foregroundStyle(Theme.text)
                }
                .padding(.top, 8)
                content
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
    }
}
