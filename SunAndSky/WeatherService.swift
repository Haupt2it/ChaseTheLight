import Foundation
import Combine
import CoreLocation
import WeatherKit

// MARK: - Light Quality

/// Photography light-quality rating based on cloud cover at sunrise / sunset.
enum LightQuality {
    case great  // 20–60 %: interesting cloud texture without blocking sun
    case good   // 0–20 %:  clear sky, clean light
    case poor   // > 60 %:  mostly overcast, flat or blocked light

    init(cloudCover: Double) {
        switch cloudCover {
        case 20..<60: self = .great
        case ..<20:   self = .good
        default:      self = .poor
        }
    }

    var label: String {
        switch self { case .great: return "Great"; case .good: return "Good"; case .poor: return "Poor" }
    }
}

// MARK: - HourlySnapshot

/// Weather conditions for a single hour of the day.
struct HourlySnapshot {
    let hour:        Int     // 0–23 local time
    let cloudCover:  Double  // 0–100 %
    let weatherCode: Int
    let temperature: Double  // °C

    var lightQuality: LightQuality { LightQuality(cloudCover: cloudCover) }

    var conditionLabel: String { weatherConditionLabel(weatherCode) }
    var sfSymbol: String       { weatherSFSymbol(weatherCode) }
}

// MARK: - WeatherData

struct WeatherData {
    let cloudCover:  Double   // 0–100 %
    let weatherCode: Int
    let visibility:  Double   // metres
    let temperature: Double   // °C
    let humidity:    Double   // %
    let windSpeed:   Double   // km/h
    let hourlySnapshots: [HourlySnapshot]   // 24 entries, index == local hour

    /// Snapshot for the local hour closest to a given Date.
    func snapshot(at date: Date) -> HourlySnapshot? {
        let h = Calendar.current.component(.hour, from: date)
        return hourlySnapshots.first { $0.hour == h }
    }
}

extension WeatherData {

    var conditionLabel: String { weatherConditionLabel(weatherCode) }
    var sfSymbol:       String { weatherSFSymbol(weatherCode) }

    var visibilityLabel: String {
        if visibility >= 10000 { return "> 10 km" }
        if visibility >= 1000  { return String(format: "%.0f km", visibility / 1000) }
        return String(format: "%.0f m", visibility)
    }

    var temperatureLabel: String { String(format: "%.0f°C", temperature) }
    var humidityLabel:    String { "\(Int(humidity))%" }
    var windSpeedLabel:   String { "\(Int(windSpeed)) km/h" }

    var isRaining: Bool {
        switch weatherCode {
        case 51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99: return true
        default: return false
        }
    }

    var isSnowing: Bool {
        switch weatherCode {
        case 71, 73, 75, 77, 85, 86: return true
        default: return false
        }
    }

    var isFoggy: Bool { weatherCode == 45 || weatherCode == 48 }

    var fogIntensity: Double {
        guard visibility < 10000 else { return 0 }
        return max(0, min(1, 1 - visibility / 10000))
    }

    var rainIntensity: Double {
        guard isRaining else { return 0 }
        switch weatherCode {
        case 51, 61, 80:             return 0.30
        case 53, 63, 81:             return 0.60
        case 55, 65, 82, 95, 96, 99: return 1.00
        default:                     return 0.50
        }
    }

    var cloudOpacityScale: Double { min(1, cloudCover / 75) }
    var sunDimFactor:      Double { cloudCover / 100 * 0.85 }
}

// MARK: - WeatherService

@MainActor
final class WeatherService: ObservableObject {

    @Published private(set) var weather:      WeatherData?
    @Published private(set) var fetchError:   String?
    @Published private(set) var activeSource: WeatherSource = .openMeteo

    private var refreshTask:  Task<Void, Never>?
    private var storedLat:    Double        = 0
    private var storedLon:    Double        = 0
    private var storedSource: WeatherSource = .openMeteo
    /// Incremented on every restart so stale in-flight fetches discard their results.
    private var generation:   Int           = 0

    /// Start (or restart) continuous weather fetching for a location and source.
    func start(latitude: Double, longitude: Double, source: WeatherSource = .openMeteo) {
        storedLat    = latitude
        storedLon    = longitude
        storedSource = source
        restartTask()
    }

    /// Switch source immediately and re-fetch without changing the location.
    func changeSource(_ source: WeatherSource) {
        guard storedLat != 0 || storedLon != 0 else { return }
        storedSource = source
        restartTask()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Task management

    private func restartTask() {
        refreshTask?.cancel()
        generation += 1
        let gen = generation
        refreshTask = Task {
            while !Task.isCancelled {
                await fetch(generation: gen)
                try? await Task.sleep(nanoseconds: 900_000_000_000) // 15 min
            }
        }
    }

    // MARK: - Dispatch

    /// Reads storedLat/Lon/Source at the moment of the call so it always uses
    /// the latest values even if changeSource() was called mid-sleep.
    private func fetch(generation gen: Int) async {
        let lat = storedLat
        let lon = storedLon
        let src = storedSource
        switch src {
        case .openMeteo:  await fetchOpenMeteo(latitude: lat, longitude: lon, generation: gen)
        case .weatherKit: await fetchWeatherKit(latitude: lat, longitude: lon, generation: gen)
        case .nws:        await fetchNWS(latitude: lat, longitude: lon, generation: gen)
        }
    }

    /// Only apply results if this fetch's generation still matches the current one.
    private func applyIfCurrent(generation gen: Int, apply: () -> Void) {
        guard gen == generation else { return }
        apply()
    }

    // MARK: - Open-Meteo

    private func fetchOpenMeteo(latitude: Double, longitude: Double, generation gen: Int) async {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",      value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude",     value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current",       value: "cloud_cover,weather_code,visibility,temperature_2m,relative_humidity_2m,wind_speed_10m"),
            URLQueryItem(name: "hourly",        value: "cloud_cover,weather_code,temperature_2m"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone",      value: "auto"),
        ]
        guard let url = comps.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded   = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let c         = decoded.current
            let h         = decoded.hourly

            let snapshots = zip(zip(h.cloud_cover, h.weather_code), h.temperature_2m).enumerated().map { i, pair in
                let ((cc, wc), temp) = pair
                return HourlySnapshot(hour: i, cloudCover: cc, weatherCode: wc, temperature: temp)
            }

            let result = WeatherData(
                cloudCover:      c.cloud_cover,
                weatherCode:     c.weather_code,
                visibility:      c.visibility,
                temperature:     c.temperature_2m,
                humidity:        c.relative_humidity_2m,
                windSpeed:       c.wind_speed_10m,
                hourlySnapshots: snapshots
            )
            applyIfCurrent(generation: gen) {
                weather      = result
                activeSource = .openMeteo
                fetchError   = nil
            }
        } catch {
            applyIfCurrent(generation: gen) { fetchError = error.localizedDescription }
        }
    }

    // MARK: - WeatherKit
    // NOTE: Requires the WeatherKit capability in your Apple Developer account and
    // Xcode project (Signing & Capabilities → + → WeatherKit).
    // Without the entitlement, calls fail and fall back to Open-Meteo.

    private func fetchWeatherKit(latitude: Double, longitude: Double, generation gen: Int) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let wk     = WeatherKit.WeatherService.shared
            let result = try await wk.weather(for: location)
            let cur    = result.currentWeather

            let snapshots: [HourlySnapshot] = result.hourlyForecast.forecast.prefix(24).map { hour in
                let h = Calendar.current.component(.hour, from: hour.date)
                return HourlySnapshot(
                    hour:        h,
                    cloudCover:  hour.cloudCover * 100,
                    weatherCode: wkConditionToWMO(hour.condition),
                    temperature: hour.temperature.converted(to: .celsius).value
                )
            }

            let wkData = WeatherData(
                cloudCover:      cur.cloudCover * 100,
                weatherCode:     wkConditionToWMO(cur.condition),
                visibility:      cur.visibility.converted(to: .meters).value,
                temperature:     cur.temperature.converted(to: .celsius).value,
                humidity:        cur.humidity * 100,
                windSpeed:       cur.wind.speed.converted(to: .kilometersPerHour).value,
                hourlySnapshots: snapshots
            )
            applyIfCurrent(generation: gen) {
                weather      = wkData
                activeSource = .weatherKit
                fetchError   = nil
            }
        } catch {
            // Entitlement not configured or service unavailable — fall back to Open-Meteo
            await fetchOpenMeteo(latitude: latitude, longitude: longitude, generation: gen)
        }
    }

    // MARK: - NWS (US only)
    // Falls back to Open-Meteo automatically for non-US coordinates.

    private func fetchNWS(latitude: Double, longitude: Double, generation gen: Int) async {
        do {
            // Step 1 — resolve grid point
            let pointURL = URL(string: "https://api.weather.gov/points/\(String(format: "%.4f,%.4f", latitude, longitude))")!
            var pointReq = URLRequest(url: pointURL)
            pointReq.setValue("(ChaseTheLight, support@chasethelight.app)", forHTTPHeaderField: "User-Agent")
            let (pointData, _) = try await URLSession.shared.data(for: pointReq)
            let pointResp      = try JSONDecoder().decode(NWSPointsResponse.self, from: pointData)

            guard let forecastURL = URL(string: pointResp.properties.forecastHourly) else {
                await fetchOpenMeteo(latitude: latitude, longitude: longitude, generation: gen); return
            }

            // Step 2 — hourly forecast
            var fcReq = URLRequest(url: forecastURL)
            fcReq.setValue("(ChaseTheLight, support@chasethelight.app)", forHTTPHeaderField: "User-Agent")
            let (fcData, _) = try await URLSession.shared.data(for: fcReq)
            let fcResp      = try JSONDecoder().decode(NWSHourlyResponse.self, from: fcData)

            let periods = fcResp.properties.periods
            guard let first = periods.first else {
                await fetchOpenMeteo(latitude: latitude, longitude: longitude, generation: gen); return
            }

            // Build hourly snapshots
            let isoFmt  = ISO8601DateFormatter()
            let snapshots: [HourlySnapshot] = periods.prefix(24).compactMap { period in
                let date = isoFmt.date(from: period.startTime)
                let h    = date.map { Calendar.current.component(.hour, from: $0) } ?? 0
                let (cc, wc) = nwsForecastToWeather(period.shortForecast)
                return HourlySnapshot(
                    hour:        h,
                    cloudCover:  cc,
                    weatherCode: wc,
                    temperature: nwsToCelsius(period.temperature, unit: period.temperatureUnit)
                )
            }

            let (cloudCover, wmoCode) = nwsForecastToWeather(first.shortForecast)
            let windKph: Double = {
                let parts = first.windSpeed.components(separatedBy: " ")
                return (Double(parts.first ?? "0") ?? 0) * 1.60934
            }()

            let nwsData = WeatherData(
                cloudCover:      cloudCover,
                weatherCode:     wmoCode,
                visibility:      16093,   // NWS hourly doesn't report visibility; default 10 mi
                temperature:     nwsToCelsius(first.temperature, unit: first.temperatureUnit),
                humidity:        first.relativeHumidity?.value ?? 50,
                windSpeed:       windKph,
                hourlySnapshots: snapshots
            )
            applyIfCurrent(generation: gen) {
                weather      = nwsData
                activeSource = .nws
                fetchError   = nil
            }
        } catch {
            // NWS is US-only; non-US or network errors fall back to Open-Meteo
            await fetchOpenMeteo(latitude: latitude, longitude: longitude, generation: gen)
        }
    }

    // MARK: - WeatherKit condition → WMO code

    private func wkConditionToWMO(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear:                                          return 0
        case .mostlyClear:                                   return 1
        case .partlyCloudy, .breezy, .windy, .hot, .frigid: return 2
        case .mostlyCloudy, .cloudy:                         return 3
        case .foggy, .haze, .smoky, .blowingDust:           return 45
        case .drizzle, .freezingDrizzle:                    return 51
        case .rain, .sunShowers:                             return 61
        case .heavyRain:                                     return 65
        case .flurries, .sunFlurries:                        return 71
        case .snow, .blowingSnow:                            return 73
        case .heavySnow, .blizzard:                          return 75
        case .sleet, .wintryMix, .freezingRain:             return 77
        case .hail:                                          return 96
        case .isolatedThunderstorms, .scatteredThunderstorms: return 95
        case .thunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:                     return 99
        @unknown default:                                    return 2
        }
    }

    // MARK: - NWS helpers

    private func nwsToCelsius(_ temp: Double, unit: String) -> Double {
        unit.uppercased() == "F" ? (temp - 32) * 5 / 9 : temp
    }

    private func nwsForecastToWeather(_ forecast: String) -> (cloudCover: Double, wmoCode: Int) {
        let f = forecast.lowercased()
        if f.contains("thunderstorm")                              { return (90, 95) }
        if f.contains("heavy rain") || f.contains("heavy shower") { return (85, 65) }
        if f.contains("rain") || f.contains("shower") || f.contains("drizzle") { return (75, 61) }
        if f.contains("heavy snow") || f.contains("blizzard")     { return (85, 75) }
        if f.contains("snow") || f.contains("flurries")           { return (75, 71) }
        if f.contains("sleet") || f.contains("wintry") || f.contains("freezing") { return (80, 77) }
        if f.contains("fog") || f.contains("mist")                { return (80, 45) }
        if f.contains("overcast")                                  { return (95, 3)  }
        if f.contains("mostly cloudy")                             { return (75, 3)  }
        if f.contains("partly cloudy") || f.contains("partly sunny") || f.contains("increasing clouds") { return (40, 2) }
        if f.contains("mostly clear") || f.contains("mostly sunny") { return (15, 1) }
        if f.contains("clear") || f.contains("sunny") || f.contains("fair") { return (5, 0) }
        return (50, 2)
    }
}

// MARK: - Open-Meteo JSON models

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let cloud_cover:           Double
        let weather_code:          Int
        let visibility:            Double
        let temperature_2m:        Double
        let relative_humidity_2m:  Double
        let wind_speed_10m:        Double
    }
    struct Hourly: Decodable {
        let cloud_cover:    [Double]
        let weather_code:   [Int]
        let temperature_2m: [Double]
    }
    let current: Current
    let hourly:  Hourly
}

// MARK: - NWS JSON models

private struct NWSPointsResponse: Decodable {
    struct Properties: Decodable {
        let forecastHourly: String
    }
    let properties: Properties
}

private struct NWSHourlyResponse: Decodable {
    struct Properties: Decodable {
        struct Period: Decodable {
            let startTime:         String
            let temperature:       Double
            let temperatureUnit:   String
            let windSpeed:         String
            let shortForecast:     String
            let relativeHumidity:  NWSValue?
        }
        let periods: [Period]
    }
    let properties: Properties
}

private struct NWSValue: Decodable {
    let value: Double?
}

// MARK: - Shared WMO helpers (used by WeatherData and HourlySnapshot)

private func weatherConditionLabel(_ code: Int) -> String {
    switch code {
    case 0:          return "Clear"
    case 1:          return "Mainly Clear"
    case 2:          return "Partly Cloudy"
    case 3:          return "Overcast"
    case 45, 48:     return "Fog"
    case 51, 53:     return "Drizzle"
    case 55:         return "Heavy Drizzle"
    case 61:         return "Light Rain"
    case 63:         return "Rain"
    case 65:         return "Heavy Rain"
    case 71:         return "Light Snow"
    case 73:         return "Snow"
    case 75:         return "Heavy Snow"
    case 77:         return "Snow Grains"
    case 80, 81:     return "Showers"
    case 82:         return "Heavy Showers"
    case 85, 86:     return "Snow Showers"
    case 95, 96, 99: return "Thunderstorm"
    default:         return "Unknown"
    }
}

private func weatherSFSymbol(_ code: Int) -> String {
    switch code {
    case 0, 1:                   return "sun.max.fill"
    case 2:                      return "cloud.sun.fill"
    case 3:                      return "cloud.fill"
    case 45, 48:                 return "cloud.fog.fill"
    case 51, 53, 55:             return "cloud.drizzle.fill"
    case 61, 63, 80, 81:         return "cloud.rain.fill"
    case 65, 82:                 return "cloud.heavyrain.fill"
    case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
    case 95, 96, 99:             return "cloud.bolt.rain.fill"
    default:                     return "cloud.fill"
    }
}
