import Foundation
import Combine

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

    @Published private(set) var weather: WeatherData?
    @Published private(set) var fetchError: String?

    private var refreshTask: Task<Void, Never>?

    func start(latitude: Double, longitude: Double) {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetch(latitude: latitude, longitude: longitude)
                try? await Task.sleep(nanoseconds: 900_000_000_000) // 15 min
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Network

    private func fetch(latitude: Double, longitude: Double) async {
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

            // Build 24 hourly snapshots; index == local hour 0–23
            let snapshots = zip(zip(h.cloud_cover, h.weather_code), h.temperature_2m).enumerated().map { i, pair in
                let ((cc, wc), temp) = pair
                return HourlySnapshot(hour: i, cloudCover: cc, weatherCode: wc, temperature: temp)
            }

            weather = WeatherData(
                cloudCover:      c.cloud_cover,
                weatherCode:     c.weather_code,
                visibility:      c.visibility,
                temperature:     c.temperature_2m,
                humidity:        c.relative_humidity_2m,
                windSpeed:       c.wind_speed_10m,
                hourlySnapshots: snapshots
            )
            fetchError = nil
        } catch {
            fetchError = error.localizedDescription
        }
    }
}

// MARK: - JSON model

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
