import SwiftUI

// MARK: - LightPhase

struct LightPhase: Identifiable {

    enum Kind {
        case astronomicalTwilight
        case nauticalTwilight
        case blueHour
        case goldenHour
        case civilTwilight
        case softLight
    }

    let id   = UUID()
    let kind: Kind
    let morningStart: Date?
    let morningEnd:   Date?
    let eveningStart: Date?
    let eveningEnd:   Date?

    // MARK: Metadata

    var name: String {
        switch kind {
        case .astronomicalTwilight: return "Astronomical Twilight"
        case .nauticalTwilight:     return "Nautical Twilight"
        case .blueHour:             return "Blue Hour"
        case .goldenHour:           return "Golden Hour"
        case .civilTwilight:        return "Civil Twilight"
        case .softLight:            return "Soft Light"
        }
    }

    var altRange: String {
        switch kind {
        case .astronomicalTwilight: return "−18° → −12°"
        case .nauticalTwilight:     return "−12° → −6°"
        case .blueHour:             return "−6° → 0°"
        case .goldenHour:           return "0° → 6°"
        case .civilTwilight:        return "6° → 12°"
        case .softLight:            return "12° → 45°"
        }
    }

    var phrase: String {
        switch kind {
        case .astronomicalTwilight: return "Stars brilliant, sky still dark"
        case .nauticalTwilight:     return "Deep violet blue bleeds to the horizon"
        case .blueHour:             return "Even, shadowless, cool blue light"
        case .goldenHour:           return "Warm directional light, long dramatic shadows"
        case .civilTwilight:        return "Soft diffuse warmth, gentle contrast"
        case .softLight:            return "Full color, subtle texture, gentle glow"
        }
    }

    var specialties: [(icon: String, label: String)] {
        switch kind {
        case .astronomicalTwilight: return [("sparkles", "Astrophoto"), ("camera.circle.fill", "Star Trails")]
        case .nauticalTwilight:     return [("building.columns.fill", "Architecture"), ("moon.stars.fill", "Night Sky")]
        case .blueHour:             return [("building.fill", "Cityscapes"), ("drop.fill", "Reflections")]
        case .goldenHour:           return [("person.fill", "Portraits"), ("photo.fill", "Landscapes")]
        case .civilTwilight:        return [("leaf.fill", "Nature"), ("person.fill", "Portraits")]
        case .softLight:            return [("camera.fill", "General"), ("photo.fill", "Landscapes")]
        }
    }

    /// Solid background color for the phase card — sky gradient peeks through at boxOpacity.
    var boxBackground: Color {
        switch kind {
        case .astronomicalTwilight: return Color(hex: 0x0D1B2A)
        case .nauticalTwilight:     return Color(hex: 0x1A1A4E)
        case .blueHour:             return Color(hex: 0x1B3A6B)
        case .goldenHour:           return Color(hex: 0x92400E)
        case .civilTwilight:        return Color(hex: 0x7C2D12)
        case .softLight:            return Color(hex: 0x164E63)
        }
    }

    var boxOpacity: Double {
        switch kind {
        case .astronomicalTwilight, .nauticalTwilight: return 0.90
        default: return 0.88
        }
    }

    /// Left accent bar color — a lighter shade of the box background.
    var accentBarColor: Color {
        switch kind {
        case .astronomicalTwilight: return Color(hex: 0x1E3A5A)
        case .nauticalTwilight:     return Color(hex: 0x2E2E80)
        case .blueHour:             return Color(hex: 0x2A5AA0)
        case .goldenHour:           return Color(hex: 0xC05A18)
        case .civilTwilight:        return Color(hex: 0xA83E1A)
        case .softLight:            return Color(hex: 0x1E6E90)
        }
    }

    // MARK: Timing

    func morningDurationMinutes() -> Int? {
        guard let s = morningStart, let e = morningEnd, e > s else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    func eveningDurationMinutes() -> Int? {
        guard let s = eveningStart, let e = eveningEnd, e > s else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    func isActive(at now: Date) -> Bool {
        if let s = morningStart, let e = morningEnd, now >= s && now <= e { return true }
        if let s = eveningStart, let e = eveningEnd, now >= s && now <= e { return true }
        return false
    }

    func nextWindow(after now: Date) -> (start: Date, end: Date, isMorning: Bool)? {
        if let s = morningStart, let e = morningEnd, now < e { return (s, e, true) }
        if let s = eveningStart, let e = eveningEnd, now < e { return (s, e, false) }
        return nil
    }
}

// MARK: - LightPhaseCalculator

enum LightPhaseCalculator {

    /// Build today's 6 light phases for a given location.
    static func phases(for date: Date, latitude: Double, longitude: Double,
                       solar: SolarInfo) -> [LightPhase] {

        // Altitude thresholds: -18, -12, -6, horizon (~-0.833 with refraction), 6, 12
        let thresholds: [Double] = [-18, -12, -6, -0.8333, 6, 12]
        var rising:  [Double: Date] = [:]
        var setting: [Double: Date] = [:]

        for t in thresholds {
            let (r, s) = SolarCalculator.altitudeCrossingTimes(
                for: date, latitude: latitude, longitude: longitude, altitude: t)
            rising[t]  = r
            setting[t] = s
        }

        let noon = solar.solarNoon   // midpoint — used as soft-light peak boundary

        return [
            LightPhase(kind: .astronomicalTwilight,
                       morningStart: rising[-18],      morningEnd: rising[-12],
                       eveningStart: setting[-12],     eveningEnd: setting[-18]),

            LightPhase(kind: .nauticalTwilight,
                       morningStart: rising[-12],      morningEnd: rising[-6],
                       eveningStart: setting[-6],      eveningEnd: setting[-12]),

            LightPhase(kind: .blueHour,
                       morningStart: rising[-6],       morningEnd: rising[-0.8333],
                       eveningStart: setting[-0.8333], eveningEnd: setting[-6]),

            LightPhase(kind: .goldenHour,
                       morningStart: rising[-0.8333],  morningEnd: rising[6],
                       eveningStart: setting[6],       eveningEnd: setting[-0.8333]),

            LightPhase(kind: .civilTwilight,
                       morningStart: rising[6],        morningEnd: rising[12],
                       eveningStart: setting[12],      eveningEnd: setting[6]),

            LightPhase(kind: .softLight,
                       morningStart: rising[12],       morningEnd: noon,
                       eveningStart: noon,             eveningEnd: setting[12]),
        ]
    }
}

// MARK: - LightPhaseTimelineView  (2 × 3 grid)

struct LightPhaseTimelineView: View {
    let phases:          [LightPhase]
    let now:             Date
    let timeZone:        TimeZone?
    let currentAltitude: Double

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Section header ────────────────────────────────────────
            HStack {
                Label("Light Phases", systemImage: "light.max")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(String(format: "%.1f°  now", currentAltitude))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            // ── 2 × 3 grid ────────────────────────────────────────────
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(phases) { phase in
                    PhaseGridCell(phase: phase, now: now, timeZone: timeZone)
                }
            }
        }
    }
}

// MARK: - PhaseGridCell

private struct PhaseGridCell: View {
    @EnvironmentObject private var settings: AppSettings

    let phase:    LightPhase
    let now:      Date
    let timeZone: TimeZone?

    @State private var glowPulse = false

    private var isActive: Bool { phase.isActive(at: now) }
    private var isDone:   Bool { phase.nextWindow(after: now) == nil && !isActive }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            // ── Left accent bar — lighter shade of box color ───────────
            phase.accentBarColor
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .opacity(isDone ? 0.28 : (isActive ? 1.0 : 0.70))

            // ── Content ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 7) {

                // Phase name + status badge
                HStack(alignment: .center, spacing: 4) {
                    Text(phase.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(isDone ? 0.32 : 1.0))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .shadow(color: .black.opacity(0.60), radius: 3, x: 0, y: 1)
                    Spacer(minLength: 2)
                    statusBadge
                }

                // Altitude range — white
                Text(phase.altRange)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(isDone ? 0.28 : 0.85))
                    .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)

                // Morning window
                windowLine(isRising: true,
                           start: phase.morningStart,
                           end:   phase.morningEnd,
                           dur:   phase.morningDurationMinutes())

                // Evening window
                windowLine(isRising: false,
                           start: phase.eveningStart,
                           end:   phase.eveningEnd,
                           dur:   phase.eveningDurationMinutes())

                // Evocative description — white at 80%
                Text(phase.phrase)
                    .font(.system(size: 15).italic())
                    .foregroundStyle(.white.opacity(isDone ? 0.22 : 0.80))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.vertical, 18)
        }
        // Per-phase solid color — sky gradient peeks through at set opacity
        .background {
            RoundedRectangle(cornerRadius: 13)
                .fill(phase.boxBackground.opacity(phase.boxOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(
                    isActive
                        ? Color.white.opacity(glowPulse ? 1.0 : 0.65)
                        : Color.white.opacity(isDone ? 0.05 : 0.15),
                    lineWidth: isActive ? 2.0 : 1
                )
        }
        .shadow(
            color: isActive ? Color.white.opacity(glowPulse ? 0.35 : 0.10) : .clear,
            radius: 12, x: 0, y: 0
        )
        .opacity(isDone ? 0.65 : 1.0)
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: Status badge

    @ViewBuilder
    private var statusBadge: some View {
        if isActive {
            Text("NOW")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.25), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.80), lineWidth: 1))
        } else if let n = phase.nextWindow(after: now) {
            let secs = max(0, n.start.timeIntervalSince(now))
            let h = Int(secs) / 3600; let m = (Int(secs) % 3600) / 60
            Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.30))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    // MARK: Window line

    @ViewBuilder
    private func windowLine(isRising: Bool, start: Date?, end: Date?, dur: Int?) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isRising ? "sunrise.fill" : "sunset.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(isDone ? 0.24 : 0.70))
                .frame(width: 18)

            if let s = start, let e = end {
                Text("\(fmt(s))–\(fmt(e))")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(isDone ? 0.26 : 0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                if let d = dur {
                    Text("·\(d)m")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(isDone ? 0.18 : 0.55))
                        .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                }
            } else {
                Text("n/a")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.20))
            }
        }
    }

    private func fmt(_ d: Date) -> String {
        settings.timeString(d, timeZone: timeZone, showAmPm: false)
    }
}
