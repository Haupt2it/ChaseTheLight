import SwiftUI

// MARK: - LightPhase (watch-optimised model — no view code)

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

    var name: String {
        switch kind {
        case .astronomicalTwilight: return "Astro Twilight"
        case .nauticalTwilight:     return "Nautical Twilight"
        case .blueHour:             return "Blue Hour"
        case .goldenHour:           return "Golden Hour"
        case .civilTwilight:        return "Civil Twilight"
        case .softLight:            return "Soft Light"
        }
    }

    var phaseColor: Color {
        switch kind {
        case .astronomicalTwilight: return Color(hex: 0x1E3A5A)
        case .nauticalTwilight:     return Color(hex: 0x2E2E80)
        case .blueHour:             return Color(hex: 0x2A6AAF)
        case .goldenHour:           return Color(hex: 0xC86420)
        case .civilTwilight:        return Color(hex: 0xAA4420)
        case .softLight:            return Color(hex: 0x1E7090)
        }
    }

    var icon: String {
        switch kind {
        case .astronomicalTwilight: return "sparkles"
        case .nauticalTwilight:     return "moon.stars.fill"
        case .blueHour:             return "building.fill"
        case .goldenHour:           return "sun.horizon.fill"
        case .civilTwilight:        return "leaf.fill"
        case .softLight:            return "sun.max.fill"
        }
    }

    // MARK: Timing helpers

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

    func morningDurationMinutes() -> Int? {
        guard let s = morningStart, let e = morningEnd, e > s else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    func eveningDurationMinutes() -> Int? {
        guard let s = eveningStart, let e = eveningEnd, e > s else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }
}

// MARK: - LightPhaseCalculator

enum LightPhaseCalculator {

    static func phases(for date: Date, latitude: Double, longitude: Double,
                       solar: SolarInfo) -> [LightPhase] {

        let thresholds: [Double] = [-18, -12, -6, -0.8333, 6, 12]
        var rising:  [Double: Date] = [:]
        var setting: [Double: Date] = [:]

        for t in thresholds {
            let (r, s) = SolarCalculator.altitudeCrossingTimes(
                for: date, latitude: latitude, longitude: longitude, altitude: t)
            rising[t]  = r
            setting[t] = s
        }

        let noon = solar.solarNoon

        return [
            LightPhase(kind: .astronomicalTwilight,
                       morningStart: rising[-18],       morningEnd: rising[-12],
                       eveningStart: setting[-12],      eveningEnd: setting[-18]),
            LightPhase(kind: .nauticalTwilight,
                       morningStart: rising[-12],       morningEnd: rising[-6],
                       eveningStart: setting[-6],       eveningEnd: setting[-12]),
            LightPhase(kind: .blueHour,
                       morningStart: rising[-6],        morningEnd: rising[-0.8333],
                       eveningStart: setting[-0.8333],  eveningEnd: setting[-6]),
            LightPhase(kind: .goldenHour,
                       morningStart: rising[-0.8333],   morningEnd: rising[6],
                       eveningStart: setting[6],        eveningEnd: setting[-0.8333]),
            LightPhase(kind: .civilTwilight,
                       morningStart: rising[6],         morningEnd: rising[12],
                       eveningStart: setting[12],       eveningEnd: setting[6]),
            LightPhase(kind: .softLight,
                       morningStart: rising[12],        morningEnd: noon,
                       eveningStart: noon,              eveningEnd: setting[12]),
        ]
    }
}
