import SwiftUI

/// v4.0 design system (plan phase 4, "layer palettes"). One card / button / row
/// vocabulary used everywhere, and a colour world per prestige layer so the player
/// always knows where they are: Big Bang violet, Cosmos cyan, Multiverse indigo,
/// Omniverse gold. Views should use these instead of styling their own.
enum DSLayer: CaseIterable {
    case core, bigBang, cosmos, multiverse, omniverse

    /// Main accent (titles, icons, progress).
    var accent: Color {
        switch self {
        case .core:       return Color(red: 0.93, green: 0.36, blue: 0.95)
        case .bigBang:    return Color(red: 0.72, green: 0.45, blue: 1.00)
        case .cosmos:     return Color(red: 0.30, green: 0.88, blue: 1.00)
        case .multiverse: return Color(red: 0.52, green: 0.46, blue: 1.00)
        case .omniverse:  return Color(red: 1.00, green: 0.80, blue: 0.38)
        }
    }

    /// Second stop for gradients (buttons, hero numbers).
    var accent2: Color {
        switch self {
        case .core:       return Color(red: 1.00, green: 0.55, blue: 0.35)
        case .bigBang:    return Color(red: 1.00, green: 0.45, blue: 0.70)
        case .cosmos:     return Color(red: 0.60, green: 0.55, blue: 1.00)
        case .multiverse: return Color(red: 1.00, green: 0.48, blue: 0.27)
        case .omniverse:  return Color(red: 0.35, green: 0.95, blue: 0.85)
        }
    }

    /// Deep tint behind everything on the layer's screens.
    var depth: Color {
        switch self {
        case .core:       return Color(red: 0.06, green: 0.03, blue: 0.10)
        case .bigBang:    return Color(red: 0.09, green: 0.03, blue: 0.14)
        case .cosmos:     return Color(red: 0.02, green: 0.07, blue: 0.12)
        case .multiverse: return Color(red: 0.05, green: 0.04, blue: 0.14)
        case .omniverse:  return Color(red: 0.11, green: 0.08, blue: 0.02)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

enum DS {
    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24
    }
    static let radius: CGFloat = 16
    static let gutter: CGFloat = 16

    /// Type scale (Dynamic Type aware: built on text styles).
    enum Typo {
        static let hero = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        static let title = Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.subheadline
        static let caption = Font.caption
        static let number = Font.system(.subheadline, design: .rounded).weight(.semibold)
    }
}

// MARK: - Card

private struct DSCardModifier: ViewModifier {
    let layer: DSLayer
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(DS.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                            .fill(LinearGradient(colors: [layer.accent.opacity(highlighted ? 0.22 : 0.10), .clear],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                            .strokeBorder(layer.accent.opacity(highlighted ? 0.55 : 0.18), lineWidth: 1)
                    )
            }
            .padding(.horizontal, DS.gutter)
    }
}

extension View {
    /// The one card style: material + a faint wash and hairline in the layer's accent.
    func dsCard(_ layer: DSLayer = .core, highlighted: Bool = false) -> some View {
        modifier(DSCardModifier(layer: layer, highlighted: highlighted))
    }
}

// MARK: - Buttons

/// Full-width primary action in the layer's gradient.
struct DSPrimaryButtonStyle: ButtonStyle {
    let layer: DSLayer
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typo.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, DS.Space.m)
            .background(isEnabled ? AnyShapeStyle(layer.gradient) : AnyShapeStyle(Color.gray.opacity(0.3)),
                        in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .shadow(color: isEnabled ? layer.accent.opacity(0.45) : .clear, radius: configuration.isPressed ? 4 : 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .padding(.horizontal, DS.gutter)
    }
}

/// Compact price / buy pill.
struct DSPillButtonStyle: ButtonStyle {
    let layer: DSLayer
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typo.number)
            .monospacedDigit()
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(isEnabled ? AnyShapeStyle(layer.gradient) : AnyShapeStyle(Color.gray.opacity(0.28)),
                        in: Capsule())
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Rows & headers

/// Section title with an optional trailing note.
struct DSSectionHeader: View {
    let title: String
    var note: String? = nil
    var layer: DSLayer = .core

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(DS.Typo.title).foregroundStyle(.white)
            Spacer()
            if let note { Text(note).font(DS.Typo.caption).foregroundStyle(layer.accent) }
        }
        .padding(.horizontal, DS.gutter)
        .padding(.top, DS.Space.s)
    }
}

/// Navigation row into a layer: glowing icon, title, one-line status, optional badge.
struct DSLinkRow: View {
    let layer: DSLayer
    let symbol: String
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                Circle().fill(layer.accent.opacity(0.18)).frame(width: 42, height: 42)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(layer.gradient)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Typo.headline).foregroundStyle(.white)
                Text(subtitle).font(DS.Typo.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: DS.Space.s)
            if let badge {
                Text(badge)
                    .font(.caption.bold()).monospacedDigit()
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(layer.accent.opacity(0.22), in: Capsule())
                    .foregroundStyle(layer.accent)
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .dsCard(layer)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Label / value line inside a card.
struct DSStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(DS.Typo.body).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(DS.Typo.number).foregroundStyle(.white).monospacedDigit()
        }
    }
}

// MARK: - Layer background

/// Slowly drifting nebula in the layer's colours over deep space. Respects Reduce Motion.
struct DSLayerBackground: View {
    let layer: DSLayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                layer.depth
                RadialGradient(colors: [layer.accent.opacity(0.28), .clear],
                               center: UnitPoint(x: 0.25 + 0.08 * sin(t / 9), y: 0.18 + 0.05 * cos(t / 11)),
                               startRadius: 10, endRadius: 420)
                RadialGradient(colors: [layer.accent2.opacity(0.18), .clear],
                               center: UnitPoint(x: 0.85 + 0.06 * cos(t / 13), y: 0.75 + 0.06 * sin(t / 7)),
                               startRadius: 10, endRadius: 380)
                DSStarDust(seed: 7, count: 70, twinkle: t)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

/// Deterministic star specks (same sky every launch), gently twinkling.
private struct DSStarDust: View {
    let seed: UInt64
    let count: Int
    let twinkle: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = DSSplitMix(seed)
            for i in 0..<count {
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height
                let r = CGFloat(0.6 + rng.next() * 1.4)
                let phase = rng.next() * 6.28
                let a = 0.25 + 0.45 * (0.5 + 0.5 * sin(twinkle * (0.6 + Double(i % 5) * 0.15) + phase))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a)))
            }
        }
    }
}

private struct DSSplitMix {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(UInt64(1) << 53)
    }
}
