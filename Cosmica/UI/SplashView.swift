import SwiftUI

/// Cold-launch splash. Rendered as an overlay on top of `RootView` by `CosmicaApp`
/// for ~1.7 s at start; fades out on its own. Shows the shipping version + build
/// number pulled from the app bundle so QA / TestFlight testers can always name
/// the exact build without digging in Settings.
///
/// v3.0.5 — a tiny Big Bang: a point of light pulses, bursts (flash + shockwave),
/// and the particles settle into a slowly turning spiral galaxy in the app icon's
/// palette while the wordmark fades in. Reduce Motion gets the settled galaxy
/// with no burst.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// Seconds into the animation when the point of light bursts.
    private static let burstAt: Double = 0.25
    /// How long particles take to travel to their place in the galaxy.
    private static let settle: Double = 0.65

    var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 3 : context.date.timeIntervalSince(start)
            let wordIn = Self.clamp((t - 0.6) / 0.4)
            ZStack {
                Color.black.ignoresSafeArea()
                Canvas { gc, size in
                    Self.draw(gc, size: size, t: t)
                }
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    Spacer()
                    Text("COSMICA")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .tracking(8 + 22 * (1 - wordIn))
                        .foregroundStyle(.white)
                        .shadow(color: Color.purple.opacity(0.8), radius: 18)
                        .opacity(wordIn)
                    Text(Self.versionLine)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(Self.clamp((t - 0.9) / 0.3))
                }
                .padding(.bottom, 90)

                // Burst flash
                Color.white
                    .opacity(0.35 * Self.pulse(t, at: Self.burstAt, width: 0.12))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Drawing

    private static func draw(_ gc: GraphicsContext, size: CGSize, t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let radius = min(size.width, size.height) * 0.42
        let progress = clamp((t - burstAt) / settle)
        let travel = easeOutBack(progress)
        let spin = t * 0.22                  // slow galaxy rotation, radians/s

        // Shockwave ring
        if t > burstAt && progress < 1 {
            let r = radius * 1.35 * easeOut(progress)
            let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.6, width: r * 2, height: r * 1.2))
            gc.stroke(ring, with: .color(Color(red: 0.85, green: 0.7, blue: 1).opacity(0.7 * (1 - progress))), lineWidth: 3)
        }

        // Particles: soft glow pass, then sharp pass
        if t > burstAt {
            gc.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                drawParticles(layer, center: center, radius: radius, travel: travel, spin: spin, scale: 2.2, alpha: 0.55)
            }
            drawParticles(gc, center: center, radius: radius, travel: travel, spin: spin, scale: 1, alpha: 1)
        }

        // Core: a point that pulses before the burst, then the galaxy's bright heart
        let before = clamp(t / burstAt)
        let coreR = t < burstAt ? 4 + 6 * before : 10 + 26 * easeOut(progress)
        let coreA = t < burstAt ? 0.6 + 0.4 * sin(before * .pi * 3) : 0.95
        let core = Path(ellipseIn: CGRect(x: center.x - coreR * 2.5, y: center.y - coreR * 2.5,
                                          width: coreR * 5, height: coreR * 5))
        gc.fill(core, with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.85).opacity(coreA),
                              Color(red: 1, green: 0.6, blue: 0.85).opacity(coreA * 0.5), .clear]),
            center: center, startRadius: 0, endRadius: coreR * 2.5))
    }

    private static func drawParticles(_ gc: GraphicsContext, center: CGPoint, radius: Double,
                                      travel: Double, spin: Double, scale: Double, alpha: Double) {
        let c = cos(spin), s = sin(spin)
        for p in particles {
            // galaxy-space target (tilted disc), rotated by the slow spin
            let x = p.x * radius * travel, y = p.y * radius * travel
            let rx = x * c - y * s
            let ry = (x * s + y * c) * 0.55
            let size = p.size * scale
            let rect = CGRect(x: center.x + rx - size / 2, y: center.y + ry - size / 2, width: size, height: size)
            gc.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(alpha * p.brightness)))
        }
    }

    // MARK: - Particle field (deterministic, built once)

    private struct Particle {
        let x: Double, y: Double, size: Double, brightness: Double, color: Color
    }

    private static let particles: [Particle] = {
        var seed: UInt64 = 0xC051CA
        func rand() -> Double {           // small LCG: same galaxy every launch
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(UInt64(1) << 53)
        }
        let pink = (1.0, 0.43, 0.84), purple = (0.65, 0.41, 1.0), cyan = (0.31, 0.73, 0.9)
        func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
            Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
        }
        return (0..<320).map { i -> Particle in
            let u = pow(rand(), 0.85)                       // 0 = core, 1 = arm tip
            let theta = u * 2.6 * .pi + Double(i % 2) * .pi + (rand() - 0.5) * 0.5
            let r = 0.12 + 0.88 * u + (rand() - 0.5) * 0.08
            let knot = rand() < 0.08                       // a few bright star-forming knots
            let color = knot ? Color(red: 1, green: 0.9, blue: 0.97)
                : (u < 0.45 ? mix(pink, purple, u / 0.45) : mix(purple, cyan, (u - 0.45) / 0.55))
            return Particle(x: r * cos(theta), y: r * sin(theta),
                            size: knot ? 5 + rand() * 3 : 1.6 + rand() * 2.2,
                            brightness: knot ? 1 : 0.55 + rand() * 0.45,
                            color: color)
        }
    }()

    // MARK: - Easing

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
    private static func pulse(_ t: Double, at: Double, width: Double) -> Double {
        guard t >= at else { return 0 }
        return max(0, 1 - (t - at) / width)
    }

    /// `v2.0.0 (14)` — CFBundleShortVersionString + CFBundleVersion from the running build.
    /// Static so a fresh SplashView on every launch doesn't re-read Info.plist.
    static let versionLine: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }()
}
