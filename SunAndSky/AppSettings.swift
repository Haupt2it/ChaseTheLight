import Foundation
import Combine

// MARK: - SatelliteRegion

enum SatelliteRegion: String, CaseIterable, Identifiable {
    case americas    = "Americas"
    case europe      = "Europe/Africa"
    case asiaPacific = "Asia/Pacific"

    var id: String { rawValue }

    /// Short label for the segmented picker.
    var pickerLabel: String {
        switch self {
        case .americas:    return "Americas"
        case .europe:      return "Europe"
        case .asiaPacific: return "Asia/Pacific"
        }
    }

    /// Source description shown below the picker.
    var sourceDescription: String {
        switch self {
        case .americas:    return "GOES-East CONUS · NESDIS/NOAA"
        case .europe:      return "Meteosat Full Disk · EUMETSAT"
        case .asiaPacific: return "Himawari Full Disk · JMA"
        }
    }

    var imageURL: URL {
        switch self {
        case .americas:
            return URL(string:
                "https://cdn.star.nesdis.noaa.gov/GOES16/ABI/CONUS/GEOCOLOR/latest.jpg")!
        case .europe:
            // Meteosat SEVIRI full-disk GeoColor via EUMETSAT EUMETVIEW WMS
            return URL(string:
                "https://eumetview.eumetsat.int/geoserver/wms?SERVICE=WMS&VERSION=1.3.0" +
                "&REQUEST=GetMap&LAYERS=msg_fes%3Argb_eview" +
                "&BBOX=-81%2C-81%2C81%2C81&WIDTH=1024&HEIGHT=1024" +
                "&CRS=EPSG%3A4326&STYLES=&FORMAT=image%2Fjpeg")!
        case .asiaPacific:
            // Himawari full-disk true-color via JMA MSC Web
            return URL(string:
                "https://www.data.jma.go.jp/mscweb/data/himawari/img/fd/fd_010.jpg")!
        }
    }
}

// MARK: - AppSettings

final class AppSettings: ObservableObject {

    // MARK: Published

    @Published var use24HourTime: Bool {
        didSet { UserDefaults.standard.set(use24HourTime, forKey: Keys.use24HourTime) }
    }
    @Published var useCelsius: Bool {
        didSet { UserDefaults.standard.set(useCelsius, forKey: Keys.useCelsius) }
    }
    @Published var satelliteRegion: SatelliteRegion {
        didSet { UserDefaults.standard.set(satelliteRegion.rawValue, forKey: Keys.satelliteRegion) }
    }
    @Published var showSatelliteCard: Bool {
        didSet { UserDefaults.standard.set(showSatelliteCard, forKey: Keys.showSatelliteCard) }
    }
    @Published var showForecastStrip: Bool {
        didSet { UserDefaults.standard.set(showForecastStrip, forKey: Keys.showForecastStrip) }
    }

    // MARK: Notification alert settings

    @Published var sunriseAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(sunriseAlertEnabled, forKey: Keys.sunriseAlertEnabled) }
    }
    @Published var sunriseLeadMinutes: Int {
        didSet { UserDefaults.standard.set(sunriseLeadMinutes, forKey: Keys.sunriseLeadMinutes) }
    }
    @Published var sunsetAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(sunsetAlertEnabled, forKey: Keys.sunsetAlertEnabled) }
    }
    @Published var sunsetLeadMinutes: Int {
        didSet { UserDefaults.standard.set(sunsetLeadMinutes, forKey: Keys.sunsetLeadMinutes) }
    }
    @Published var goldenHourAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(goldenHourAlertEnabled, forKey: Keys.goldenHourAlertEnabled) }
    }
    @Published var blueHourAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(blueHourAlertEnabled, forKey: Keys.blueHourAlertEnabled) }
    }

    // MARK: Init

    init() {
        let ud = UserDefaults.standard
        use24HourTime   = ud.bool(forKey: Keys.use24HourTime)  // false = 12h by default
        useCelsius      = ud.bool(forKey: Keys.useCelsius)      // false = °F by default
        satelliteRegion = SatelliteRegion(
            rawValue: ud.string(forKey: Keys.satelliteRegion) ?? "") ?? .americas
        // Bool keys default false — use object check so these default to true on first launch
        showSatelliteCard = ud.object(forKey: Keys.showSatelliteCard) as? Bool ?? true
        showForecastStrip = ud.object(forKey: Keys.showForecastStrip) as? Bool ?? true
        // Notification settings (default off; lead time defaults to 15 min)
        sunriseAlertEnabled    = ud.bool(forKey: Keys.sunriseAlertEnabled)
        sunriseLeadMinutes     = ud.object(forKey: Keys.sunriseLeadMinutes) as? Int ?? 15
        sunsetAlertEnabled     = ud.bool(forKey: Keys.sunsetAlertEnabled)
        sunsetLeadMinutes      = ud.object(forKey: Keys.sunsetLeadMinutes) as? Int ?? 15
        goldenHourAlertEnabled = ud.bool(forKey: Keys.goldenHourAlertEnabled)
        blueHourAlertEnabled   = ud.bool(forKey: Keys.blueHourAlertEnabled)
    }

    // MARK: Formatting helpers

    /// Format a Date as a time string honouring the user's 12/24-hour preference.
    /// - Parameters:
    ///   - date: The date to format.
    ///   - timeZone: Optional time zone override.
    ///   - showAmPm: When false, AM/PM is omitted even in 12-hour mode (e.g. compact labels).
    func timeString(_ date: Date, timeZone: TimeZone? = nil, showAmPm: Bool = true) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if use24HourTime {
            f.dateFormat = "HH:mm"
        } else {
            f.dateFormat = showAmPm ? "h:mm a" : "h:mm"
            f.amSymbol = "AM"; f.pmSymbol = "PM"
        }
        if let tz = timeZone { f.timeZone = tz }
        return f.string(from: date)
    }

    /// Format a temperature value (stored in °C) honouring the user's unit preference.
    func temperatureString(_ celsius: Double) -> String {
        if useCelsius {
            return String(format: "%.0f°C", celsius)
        } else {
            return String(format: "%.0f°F", celsius * 9 / 5 + 32)
        }
    }

    // MARK: Private

    private enum Keys {
        static let use24HourTime   = "use24HourTime"
        static let useCelsius      = "useCelsius"
        static let satelliteRegion = "satelliteRegion"
        static let showSatelliteCard       = "showSatelliteCard"
        static let showForecastStrip       = "showForecastStrip"
        static let sunriseAlertEnabled     = "sunriseAlertEnabled"
        static let sunriseLeadMinutes      = "sunriseLeadMinutes"
        static let sunsetAlertEnabled      = "sunsetAlertEnabled"
        static let sunsetLeadMinutes       = "sunsetLeadMinutes"
        static let goldenHourAlertEnabled  = "goldenHourAlertEnabled"
        static let blueHourAlertEnabled    = "blueHourAlertEnabled"
    }
}
