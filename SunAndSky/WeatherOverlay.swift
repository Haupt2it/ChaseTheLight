import SwiftUI

// MARK: - WeatherOverlayView

/// Composites all weather overlays (clouds, fog, rain) above the sky gradient.
/// Set allowsHitTesting(false) so taps pass through to the UI.
struct WeatherOverlayView: View {
    let weather: WeatherData?

    var body: some View {
        ZStack {
            if let w = weather {
                if w.cloudCover > 5 {
                    CloudOverlay(cloudCover: w.cloudCover)
                }
                if w.isFoggy || w.fogIntensity > 0.05 {
                    FogOverlay(intensity: w.isFoggy ? max(w.fogIntensity, 0.55) : w.fogIntensity)
                }
                if w.isRaining {
                    RainOverlay(intensity: w.rainIntensity)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CloudOverlay

private struct CloudSeed {
    let id: Int
    let relX: Double        // base X as fraction of screen width
    let relY: Double        // Y as fraction of screen height
    let relW: Double        // width as fraction of screen width
    let relH: Double        // height as fraction of screen width
    let baseOpacity: Double
    let speed: Double       // oscillation speed multiplier
    let phase: Double       // phase offset in radians
    let blur: CGFloat
}

private let cloudSeeds: [CloudSeed] = [
    CloudSeed(id: 0, relX: 0.15, relY: 0.10, relW: 0.55, relH: 0.10, baseOpacity: 0.55, speed: 1.00, phase: 0.00, blur: 22),
    CloudSeed(id: 1, relX: 0.72, relY: 0.15, relW: 0.48, relH: 0.09, baseOpacity: 0.45, speed: 0.80, phase: 1.05, blur: 18),
    CloudSeed(id: 2, relX: 0.35, relY: 0.23, relW: 0.60, relH: 0.11, baseOpacity: 0.50, speed: 1.20, phase: 2.09, blur: 24),
    CloudSeed(id: 3, relX: 0.82, relY: 0.06, relW: 0.42, relH: 0.08, baseOpacity: 0.40, speed: 0.90, phase: 3.14, blur: 16),
    CloudSeed(id: 4, relX: 0.05, relY: 0.29, relW: 0.52, relH: 0.10, baseOpacity: 0.58, speed: 1.10, phase: 4.19, blur: 26),
    CloudSeed(id: 5, relX: 0.55, relY: 0.34, relW: 0.44, relH: 0.09, baseOpacity: 0.46, speed: 0.75, phase: 5.24, blur: 20),
]

struct CloudOverlay: View {
    let cloudCover: Double

    private var visibleCount: Int {
        switch cloudCover {
        case ..<10:  return 0
        case ..<25:  return 1
        case ..<40:  return 2
        case ..<58:  return 3
        case ..<73:  return 4
        case ..<88:  return 5
        default:     return 6
        }
    }

    var body: some View {
        // 20 fps is plenty for slow cloud drift
        TimelineView(.periodic(from: .now, by: 0.05)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<min(visibleCount, cloudSeeds.count), id: \.self) { i in
                        cloudBlob(seed: cloudSeeds[i], t: t, size: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Each cloud gently oscillates horizontally with a 250-second period.
    private func cloudBlob(seed: CloudSeed, t: Double, size: CGSize) -> some View {
        let amplitude = size.width * 0.09
        let drift     = CGFloat(sin(t * 0.025 * seed.speed + seed.phase)) * CGFloat(amplitude)
        let x         = CGFloat(seed.relX) * size.width + drift
        let y         = CGFloat(seed.relY) * size.height
        let w         = CGFloat(seed.relW) * size.width
        let h         = CGFloat(seed.relH) * size.width
        let opacity   = seed.baseOpacity * min(1, cloudCover / 70)

        return Ellipse()
            .fill(Color.white)
            .frame(width: w, height: h)
            .blur(radius: seed.blur)
            .opacity(opacity)
            .position(x: x, y: y)
    }
}

// MARK: - FogOverlay

struct FogOverlay: View {
    let intensity: Double   // 0–1

    @State private var breathe: Double = 0

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(intensity * 0.25 + breathe * 0.04),
                Color.white.opacity(intensity * 0.48 + breathe * 0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 12)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathe = 1
            }
        }
    }
}

// MARK: - RainOverlay

struct RainOverlay: View {
    let intensity: Double   // 0–1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { context, size in
                let t           = tl.date.timeIntervalSinceReferenceDate
                let count       = 30 + Int(intensity * 60)
                let speed       = 380.0 + intensity * 230.0   // px / sec
                let streakLen   = CGFloat(10 + intensity * 14)
                let slant       = CGFloat(0.10)                // slight rightward lean
                let alpha       = 0.12 + intensity * 0.22

                for i in 0..<count {
                    // Deterministic but visually random placement via golden-ratio spread
                    let baseX = CGFloat(Double(i) * 0.618034 * Double(size.width))
                                .truncatingRemainder(dividingBy: size.width)
                    let prog  = ((t * speed / Double(size.height)) + Double(i) * 0.41)
                                .truncatingRemainder(dividingBy: 1.0)
                    let y     = CGFloat(prog) * size.height
                    let x     = baseX + y * slant

                    var path = Path()
                    path.move(to:    CGPoint(x: x,                   y: y))
                    path.addLine(to: CGPoint(x: x - streakLen * slant,
                                            y: y - streakLen))

                    context.stroke(
                        path,
                        with: .color(.white.opacity(alpha)),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
