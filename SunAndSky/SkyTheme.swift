import SwiftUI

// MARK: - SkyBand

enum SkyBand: String {
    case night        = "Night"
    case twilight     = "Twilight"
    case goldenHour   = "Golden Hour"
    case daylight     = "Daylight"
    case highSun      = "High Sun"

    /// Classify by sun altitude in degrees.
    static func classify(altitude: Double) -> SkyBand {
        switch altitude {
        case ..<(-6):   return .night
        case -6..<0:    return .twilight
        case 0..<6:     return .goldenHour
        case 6..<45:    return .daylight
        default:        return .highSun
        }
    }
}

// MARK: - SkyTheme

struct SkyTheme {
    let gradient: LinearGradient
    let label: String

    // MARK: Factory

    static func make(sunAltitude: Double) -> SkyTheme {
        let band = SkyBand.classify(altitude: sunAltitude)
        return SkyTheme(gradient: gradient(for: band, altitude: sunAltitude),
                        label: band.rawValue)
    }

    // MARK: - Gradients

    private static func gradient(for band: SkyBand, altitude: Double) -> LinearGradient {
        switch band {

        case .night:
            return LinearGradient(
                colors: [Color(hex: 0x020818), Color(hex: 0x0A1628)],
                startPoint: .top, endPoint: .bottom
            )

        case .twilight:
            // Blend from deep navy at top to amber/rose at horizon
            return LinearGradient(
                colors: [
                    Color(hex: 0x0D1B3E),
                    Color(hex: 0x3A1C6E),
                    Color(hex: 0xBF4F6F),
                    Color(hex: 0xF4913D)
                ],
                startPoint: .top, endPoint: .bottom
            )

        case .goldenHour:
            // Warm amber/peach sky
            return LinearGradient(
                colors: [
                    Color(hex: 0x3A6186),
                    Color(hex: 0xE8925A),
                    Color(hex: 0xF9D48B)
                ],
                startPoint: .top, endPoint: .bottom
            )

        case .daylight:
            // Interpolate between a cool morning blue and a vibrant midday blue
            let t = min(max((altitude - 6) / 39, 0), 1)  // 0 at 6°, 1 at 45°
            let topColor    = interpolate(from: Color(hex: 0x5B9BD5), to: Color(hex: 0x1565C0), t: t)
            let bottomColor = interpolate(from: Color(hex: 0xADD8E6), to: Color(hex: 0x42A5F5), t: t)
            return LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .top, endPoint: .bottom
            )

        case .highSun:
            return LinearGradient(
                colors: [Color(hex: 0x0D47A1), Color(hex: 0x1976D2), Color(hex: 0x64B5F6)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Color Interpolation

    private static func interpolate(from: Color, to: Color, t: Double) -> Color {
        let f = from.components
        let e = to.components
        return Color(
            red:   f.r + (e.r - f.r) * t,
            green: f.g + (e.g - f.g) * t,
            blue:  f.b + (e.b - f.b) * t,
            opacity: 1
        )
    }
}

// MARK: - Color Helpers

extension Color {
    var components: (r: Double, g: Double, b: Double) {
        // Resolve via UIColor for reliable component extraction
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        NSColor(self).usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (Double(r), Double(g), Double(b))
    }
}
