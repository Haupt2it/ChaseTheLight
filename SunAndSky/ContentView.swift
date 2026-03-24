import SwiftUI
import CoreLocation
import Combine
import UIKit
import MapKit

// MARK: - ContentView

struct ContentView: View {

    @StateObject private var location          = LocationManager()
    @StateObject private var weatherService    = WeatherService()
    @StateObject private var satelliteService  = SatelliteService()

    @State private var searchText  = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var isGeocoding = false

    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var pinnedPlaceName: String = ""
    @State private var locationTimeZone: TimeZone?

    @State private var solar: SolarInfo?
    @State private var now = Date()

    private let timer    = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeCoordinate: CLLocationCoordinate2D? { pinnedCoordinate ?? location.coordinate }
    private var activePlaceName:  String { pinnedPlaceName.isEmpty ? location.placeName : pinnedPlaceName }
    private var activeTimeZone:   TimeZone? { locationTimeZone ?? location.timeZone }
    private var cloudCover:       Double { weatherService.weather?.cloudCover ?? 0 }

    var body: some View {
        ZStack {
            // 1. Sky gradient
            if let solar {
                SkyTheme.make(sunAltitude: solar.altitude).gradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: solar.altitude)
            } else {
                Color(hex: 0x0A1628).ignoresSafeArea()
            }

            // 2. Weather overlays (clouds / fog / rain)
            WeatherOverlayView(weather: weatherService.weather)

            // 3. Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // ── Arc hero + location header ────────────────────
                    if isSearching {
                        headerArea
                            .padding(.top, 56)
                    } else {
                        arcHeroSection
                            .transition(.opacity)
                        headerArea
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    if let solar {
                        // ── 3. Sunrise / Sunset hero ──────────────────
                        sunHeroSection(solar: solar)
                            .padding(.top, 20)

                        // ── 4. Solar Noon and Day Length ──────────────
                        solarInfoGrid(solar: solar)
                            .padding(.top, 12)
                            .padding(.horizontal, 24)

                        // ── 5. Light Phase Timeline ───────────────────
                        if let coord = activeCoordinate {
                            LightPhaseTimelineView(
                                phases: LightPhaseCalculator.phases(
                                    for: now,
                                    latitude:  coord.latitude,
                                    longitude: coord.longitude,
                                    solar:     solar
                                ),
                                now:             now,
                                timeZone:        activeTimeZone,
                                currentAltitude: solar.altitude
                            )
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                        }

                        // ── 8. Current Conditions ─────────────────────
                        if let weather = weatherService.weather {
                            Text("Current Conditions")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                            CurrentConditionsCard(weather: weather, solar: solar, timeZone: activeTimeZone)
                                .padding(.top, 6)
                                .padding(.horizontal, 24)
                        }

                        // ── 9. Live Satellite ─────────────────────────
                        SatelliteCard(
                            image:       satelliteService.image,
                            captureTime: satelliteService.captureTime,
                            isLoading:   satelliteService.isLoading,
                            coordinate:  activeCoordinate,
                            timeZone:    activeTimeZone,
                            placeName:   activePlaceName
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        Spacer().frame(height: 48)
                    } else {
                        loadingState.padding(.top, 60)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            location.requestLocation()
            satelliteService.start()
        }
        .onReceive(location.$coordinate) { coord in
            guard pinnedCoordinate == nil, let coord else { return }
            recalculate(coord: coord)
            weatherService.start(latitude: coord.latitude, longitude: coord.longitude)
        }
        .onReceive(timer) { date in
            now = date
            recalculate(coord: activeCoordinate)
        }
    }

    // MARK: - Arc Hero

    private var arcHeroSection: some View {
        ZStack(alignment: .center) {
            // ── Full sky arc canvas ────────────────────────────────────
            if let solar {
                SunArcView(
                    altitude:   solar.altitude,
                    azimuth:    solar.azimuth,
                    cloudCover: cloudCover,
                    solar:      solar,
                    now:        now,
                    latitude:   activeCoordinate?.latitude  ?? 0,
                    longitude:  activeCoordinate?.longitude ?? 0
                )
            } else {
                // Pre-location placeholder: deep night sky
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x020818), Color(hex: 0x0A1628)],
                        startPoint: .top, endPoint: .bottom
                    ))
            }

            // ── Title + tagline float in the sky zone ─────────────────
            // Arc horizon is at 68% of height = ~204pt; sky centre ≈ 102pt.
            // ZStack centre = 150pt → offset up ≈ 50pt to land in sky zone.
            VStack(spacing: 8) {
                Text("Chase the Light")
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.70), radius: 6,  x: 0, y: 3)
                    .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 0)
                    .multilineTextAlignment(.center)

                Text("Sun, sky, and the perfect moment \u{2014} all in one place.")
                    .font(.system(size: 17).italic())
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.60), radius: 5, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .offset(y: -50)
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
        .clipped()
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 8) {
            if isSearching {
                searchBar.transition(.move(edge: .top).combined(with: .opacity))
            } else {
                locationLabel.transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: isSearching)
    }

    private var locationLabel: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if !activePlaceName.isEmpty {
                    Text(activePlaceName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Button {
                    searchText = ""; searchError = nil; isSearching = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }

            Text(localTimeStr(now))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(localDateStr(now))
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.7))

            if let solar {
                HStack(spacing: 0) {
                    Text(SkyTheme.make(sunAltitude: solar.altitude).label).pill()
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.white.opacity(0.65))
                        Text(String(format: "%.1f°", solar.altitude))
                            .foregroundStyle(.white)
                        Text("·").foregroundStyle(.white.opacity(0.35))
                        Image(systemName: "safari.fill")
                            .foregroundStyle(.white.opacity(0.65))
                        Text(String(format: "%.0f° %@", solar.azimuth,
                                    compassPoint(solar.azimuth)))
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 15, weight: .medium))
                }
            }

            if pinnedCoordinate != nil {
                Button { clearPin() } label: {
                    Label("Use my location", systemImage: "location.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .padding(.top, 2)
            }
        }
    }

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: isGeocoding ? "circle.dotted" : "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                    .symbolEffect(.rotate, isActive: isGeocoding)
                TextField("Search city...", text: $searchText)
                    .foregroundStyle(.white).tint(.white)
                    .submitLabel(.search).onSubmit { geocodeSearch() }
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
                    }
                }
                Button("Cancel") { isSearching = false; searchError = nil }
                    .foregroundStyle(.white).font(.subheadline)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            if let error = searchError {
                Text(error).font(.caption).foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Sunrise / Sunset hero

    private func sunHeroSection(solar: SolarInfo) -> some View {
        let w = weatherService.weather
        let rise = solar.sunrise
        let set  = solar.sunset

        // Determine each card's state relative to now
        let riseState: SunHeroCard.CardState
        let setStates: SunHeroCard.CardState
        if let r = rise, let s = set {
            if now < r       { riseState = .next;  setStates = .idle }
            else if now < s  { riseState = .done;  setStates = .next }
            else             { riseState = .done;  setStates = .done }
        } else {
            riseState = .idle; setStates = .idle
        }

        return HStack(spacing: 12) {
            SunHeroCard(
                title:     "Sunrise",
                time:      rise.map { timeString($0) } ?? "—",
                snapshot:  rise.flatMap { w?.snapshot(at: $0) },
                isSunrise: true,
                state:     riseState
            )
            SunHeroCard(
                title:     "Sunset",
                time:      set.map { timeString($0) } ?? "—",
                snapshot:  set.flatMap { w?.snapshot(at: $0) },
                isSunrise: false,
                state:     setStates
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Solar Noon / Day Length grid

    private func solarInfoGrid(solar: SolarInfo) -> some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 12) {
            StatCard(title: "Solar Noon", value: solar.solarNoon.map { timeString($0) } ?? "—", icon: "sun.max.fill")
            StatCard(title: "Day Length", value: dayLengthString(solar.dayLength),               icon: "clock.fill")
        }
    }

    // MARK: - Loading / denied

    private var loadingState: some View {
        VStack(spacing: 16) {
            switch location.status {
            case .denied:
                Image(systemName: "location.slash.fill").font(.system(size: 48)).foregroundStyle(.white.opacity(0.6))
                Text("Location access denied.\nEnable it in Settings to see solar data.")
                    .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7)).font(.subheadline)
            default:
                ProgressView().tint(.white)
                Text("Locating...").foregroundStyle(.white.opacity(0.7)).font(.subheadline)
            }
        }
    }

    // MARK: - Geocoding

    private func geocodeSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isGeocoding = true; searchError = nil

        Task { @MainActor in
            do {
                guard let req = MKGeocodingRequest(addressString: query) else {
                    isGeocoding = false
                    searchError = "Could not create geocoding request."; return
                }
                let items = try await req.mapItems
                isGeocoding = false
                guard let item = items.first else {
                    searchError = "No results for \"\(query)\". Try a different city name."; return
                }
                let loc     = item.location
                let city    = item.addressRepresentations?.cityName ?? item.name ?? query
                let country = item.addressRepresentations?.regionName ?? ""
                pinnedPlaceName  = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
                pinnedCoordinate = loc.coordinate
                locationTimeZone = item.timeZone as TimeZone?
                isSearching = false; searchText = ""
                recalculate(coord: loc.coordinate)
                weatherService.start(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            } catch {
                isGeocoding = false
                searchError = "Could not find \"\(query)\": \(error.localizedDescription)"
            }
        }
    }

    private func clearPin() {
        pinnedCoordinate = nil; pinnedPlaceName = ""; locationTimeZone = nil
        recalculate(coord: location.coordinate)
        if let c = location.coordinate {
            weatherService.start(latitude: c.latitude, longitude: c.longitude)
        }
    }

    private func recalculate(coord: CLLocationCoordinate2D?) {
        guard let coord else { return }
        solar = SolarCalculator.solarInfo(for: now, latitude: coord.latitude, longitude: coord.longitude)
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        fmt.amSymbol = "AM"; fmt.pmSymbol = "PM"
        if let tz = activeTimeZone { fmt.timeZone = tz }
        return fmt.string(from: date)
    }

    private func localTimeStr(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm a"
        fmt.amSymbol = "AM"; fmt.pmSymbol = "PM"
        if let tz = activeTimeZone { fmt.timeZone = tz }
        return fmt.string(from: date)
    }

    private func localDateStr(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EEEE, MMMM d"
        if let tz = activeTimeZone { fmt.timeZone = tz }
        return fmt.string(from: date)
    }

    private func dayLengthString(_ seconds: TimeInterval) -> String {
        if seconds == 0     { return "Polar Night" }
        if seconds >= 86400 { return "Midnight Sun" }
        let h = Int(seconds) / 3600; let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func compassPoint(_ az: Double) -> String {
        ["N","NE","E","SE","S","SW","W","NW"][Int((az + 22.5) / 45) % 8]
    }
}

// MARK: - CurrentConditionsCard

private struct CurrentConditionsCard: View {
    let weather:  WeatherData
    let solar:    SolarInfo?
    let timeZone: TimeZone?

    var body: some View {
        VStack(spacing: 0) {
            // ── Current conditions row ────────────────────────────────
            HStack {
                // Condition icon + temp (first stat)
                VStack(spacing: 5) {
                    Image(systemName: weather.sfSymbol)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.multicolor)
                    Text(weather.temperatureLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(weather.conditionLabel)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "cloud.fill",    label: "Cloud",      value: "\(Int(weather.cloudCover))%")
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "humidity.fill", label: "Humidity",   value: weather.humidityLabel)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "wind",          label: "Wind",       value: weather.windSpeedLabel)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "eye.fill",      label: "Visibility", value: weather.visibilityLabel)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)

            Divider().overlay(.white.opacity(0.25)).padding(.horizontal, 14)

            // ── 24-hour forecast strip section header ─────────────────
            HStack {
                Text("24-Hour Forecast")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            forecastStrip

            // ── Day summary ──────────────────────────────────────────
            Divider().overlay(.white.opacity(0.25)).padding(.horizontal, 14)
            Text(daySummary)
                .font(.system(size: 17))
                .italic()
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    private var forecastStrip: some View {
        let cal  = Calendar.current
        let now2 = Date()
        let nowHour     = cal.component(.hour, from: now2)
        let slots       = stride(from: 0, to: 24, by: 2).map { $0 }
        let currentSlot = slots.last(where: { $0 <= nowHour }) ?? 0
        let today       = cal.startOfDay(for: now2)
        let rise        = solar?.sunrise
        let set         = solar?.sunset

        func lightWindow(for h: Int) -> ForecastCell.LightWindow? {
            guard let rise, let set else { return nil }
            guard let ss = cal.date(byAdding: .hour, value: h,     to: today),
                  let se = cal.date(byAdding: .hour, value: h + 2, to: today) else { return nil }
            if ss < rise.addingTimeInterval(3600) && se > rise              { return .golden }
            if ss < set  && se > set.addingTimeInterval(-3600)              { return .golden }
            if ss < rise && se > rise.addingTimeInterval(-1200)             { return .blue }
            if ss < set.addingTimeInterval(1200) && se > set               { return .blue }
            return nil
        }

        let sunriseHour = rise.map { cal.component(.hour, from: $0) }
        let sunsetHour  = set.map  { cal.component(.hour, from: $0) }

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(slots, id: \.self) { h in
                        if let snap = weather.hourlySnapshots.first(where: { $0.hour == h }) {
                            ForecastCell(
                                snapshot:     snap,
                                isCurrent:    h == currentSlot,
                                isSunrise:    sunriseHour.map { abs($0 - h) <= 1 } ?? false,
                                isSunset:     sunsetHour.map  { abs($0 - h) <= 1 } ?? false,
                                lightWindow:  lightWindow(for: h)
                            )
                            .id(h)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .onAppear { proxy.scrollTo(currentSlot, anchor: .center) }
        }
    }

    private var daySummary: String {
        let rainCodes: Set<Int> = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]
        let rainyHours = weather.hourlySnapshots.filter { rainCodes.contains($0.weatherCode) }.count
        let conditionPhrase: String
        if rainyHours > 4          { conditionPhrase = "a rainy day" }
        else if weather.cloudCover > 60 { conditionPhrase = "mostly overcast skies" }
        else if weather.cloudCover >= 25 { conditionPhrase = "partly cloudy skies" }
        else                        { conditionPhrase = "mostly clear skies" }

        if let sunset = solar?.sunset {
            let h = Calendar.current.component(.hour, from: sunset)
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "h:mm a"
            fmt.amSymbol = "AM"; fmt.pmSymbol = "PM"
            if let tz = timeZone { fmt.timeZone = tz }
            let tf = fmt.string(from: sunset)
            if let snap = weather.hourlySnapshots.first(where: { $0.hour == h }) {
                switch snap.lightQuality {
                case .great: return "Expect \(conditionPhrase) with a stunning golden hour at \(tf)"
                case .good:  return "Expect \(conditionPhrase) — clean sunset light at \(tf)"
                case .poor:  return "Expect \(conditionPhrase) today"
                }
            }
        }
        return "Expect \(conditionPhrase) today"
    }
}

// MARK: - ForecastCell

private struct ForecastCell: View {

    enum LightWindow { case golden, blue }

    let snapshot:    HourlySnapshot
    let isCurrent:   Bool
    let isSunrise:   Bool
    let isSunset:    Bool
    let lightWindow: LightWindow?

    var body: some View {
        VStack(spacing: 0) {
            // ── Period badge row (golden / blue / empty) ──────────────
            Group {
                if let lw = lightWindow {
                    Text(lw == .golden ? "Golden" : "Blue")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x77AAFF))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(
                            Capsule().fill((lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x77AAFF)).opacity(0.18))
                        )
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .frame(height: 20)
            .padding(.top, 8)

            // ── Time label ────────────────────────────────────────────
            Text(timeLabel)
                .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? .white : .white.opacity(0.75))
                .padding(.top, 4)

            // ── Weather icon (with sunrise/sunset badge) ──────────────
            ZStack(alignment: .topTrailing) {
                Image(systemName: snapshot.sfSymbol)
                    .font(.system(size: 22))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 30, height: 28)
                if isSunrise || isSunset {
                    Image(systemName: isSunrise ? "sunrise.fill" : "sunset.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: 0xFFB347))
                        .offset(x: 5, y: -4)
                }
            }
            .padding(.top, 4)

            // ── Temperature ───────────────────────────────────────────
            Text(String(format: "%.0f°", snapshot.temperature))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 3)

            // ── Cloud cover ───────────────────────────────────────────
            HStack(spacing: 2) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.50))
                Text("\(Int(snapshot.cloudCover))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .frame(width: 76)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.22))
            } else if let lw = lightWindow {
                let c = lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x5577FF)
                RoundedRectangle(cornerRadius: 11).fill(c.opacity(0.13))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(c.opacity(0.35), lineWidth: 1))
            } else if isSunrise || isSunset {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(hex: 0xFFB347).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color(hex: 0xFFB347).opacity(0.35), lineWidth: 1))
            }
        }
    }

    private var timeLabel: String {
        let h = snapshot.hour
        if h == 0  { return "12 AM" }
        if h < 12  { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

private struct WeatherMiniStat: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SatelliteCard

private struct SatelliteCard: View {
    let image:       UIImage?
    let captureTime: Date?
    let isLoading:   Bool
    let coordinate:  CLLocationCoordinate2D?
    let timeZone:    TimeZone?
    let placeName:   String

    @State private var isExpanded = false

    var body: some View {
        Button { isExpanded = true } label: { cardContent }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $isExpanded) {
                SatelliteFullScreen(image: image, captureTime: captureTime,
                                    coordinate: coordinate, timeZone: timeZone,
                                    placeName: placeName)
            }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x5BB8FF))
                Text("Live Satellite")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.75)
                } else if let t = captureTime {
                    Text(fmtTime(t, tz: timeZone))
                        .font(.system(size: 15)).foregroundStyle(.white.opacity(0.60))
                }
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption).foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            // ── Thumbnail (cropped to ~500-mile radius) ───────────────
            thumbnailContent
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let img = image {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
                    .clipped()
                compassRose.padding(10)
            }
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
            .clipped()
        } else {
            placeholderView
        }
    }

    // MARK: Compass rose

    private var compassRose: some View {
        VStack(spacing: 1) {
            Text("N")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
            ZStack {
                Circle().stroke(.white.opacity(0.45), lineWidth: 1).frame(width: 20, height: 20)
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Helpers

    private func fmtTime(_ date: Date, tz: TimeZone?) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"; f.pmSymbol = "PM"
        if let tz { f.timeZone = tz }
        return f.string(from: date)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color(hex: 0x0A1628))
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
            .overlay {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "satellite")
                            .font(.title2).foregroundStyle(.white.opacity(0.4))
                        Text("Loading satellite image…")
                            .font(.system(size: 17)).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
    }
}

// MARK: - SatelliteFullScreen

private struct SatelliteFullScreen: View {
    let image:       UIImage?
    let captureTime: Date?
    let coordinate:  CLLocationCoordinate2D?
    let timeZone:    TimeZone?
    let placeName:   String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let isLandscape   = geo.size.width > geo.size.height
            let safeTop       = geo.safeAreaInsets.top
            let safeBottom    = geo.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                Color.black

                // ── Full CONUS zoomable image — edge to edge ───────────
                if image != nil {
                    ZoomableImageView(image: image, coordinate: coordinate,
                                      placeName: placeName)
                } else {
                    Color(hex: 0x0A1628)
                        .overlay {
                            VStack(spacing: 14) {
                                Image(systemName: "satellite")
                                    .font(.largeTitle).foregroundStyle(.white.opacity(0.4))
                                Text("No image available")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                }

                // ── Top bar — floats above image, clears notch ─────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Live Satellite")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        if let t = captureTime {
                            Text("Captured " + fmtCapture(t))
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    Spacer()
                    // Close button — minimum 50pt touch target
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.90))
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 20)
                .padding(.top, safeTop + 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)

                // ── Scale indicator (landscape only) ──────────────────
                if isLandscape {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(.white.opacity(0.75))
                                    .frame(width: 88, height: 2)
                                Text("≈ 500 mi")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.88))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 9))
                            .padding(.horizontal, 20)
                            .padding(.bottom, safeBottom + 12)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func fmtCapture(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, h:mm a"
        f.amSymbol = "AM"; f.pmSymbol = "PM"
        if let tz = timeZone { f.timeZone = tz }
        return f.string(from: date)
    }
}

// MARK: - ZoomableImageView

private final class SatelliteScrollView: UIScrollView, UIScrollViewDelegate {

    private let imageView  = UIImageView()
    private var storedCoordinate: CLLocationCoordinate2D?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 8.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator   = false

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage?, coordinate: CLLocationCoordinate2D?, placeName: String) {
        imageView.image  = image
        storedCoordinate = coordinate
        setZoomScale(minimumZoomScale, animated: false)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let img = imageView.image,
              bounds.width > 0, bounds.height > 0 else { return }

        guard abs(zoomScale - minimumZoomScale) < 0.001 else {
            centerImageView(); return
        }

        let scale = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let fw    = img.size.width  * scale
        let fh    = img.size.height * scale
        imageView.frame = CGRect(x: 0, y: 0, width: fw, height: fh)
        contentSize     = CGSize(width: fw, height: fh)
        centerImageView()

    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImageView() }

    private func centerImageView() {
        let cx = max((bounds.width  - imageView.frame.width)  / 2, 0)
        let cy = max((bounds.height - imageView.frame.height) / 2, 0)
        contentInset = UIEdgeInsets(top: cy, left: cx, bottom: cy, right: cx)
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let pt   = g.location(in: imageView)
            let rect = CGRect(x: pt.x - 60, y: pt.y - 60, width: 120, height: 120)
            zoom(to: rect, animated: true)
        }
    }
}

private struct ZoomableImageView: UIViewRepresentable {
    let image:      UIImage?
    let coordinate: CLLocationCoordinate2D?
    let placeName:  String

    func makeUIView(context: Context) -> SatelliteScrollView { SatelliteScrollView() }

    func updateUIView(_ view: SatelliteScrollView, context: Context) {
        view.configure(image: image, coordinate: coordinate, placeName: placeName)
    }
}

// MARK: - SunHeroCard

private struct SunHeroCard: View {

    enum CardState { case next, done, idle }

    let title:     String
    let time:      String
    let snapshot:  HourlySnapshot?
    let isSunrise: Bool
    let state:     CardState

    @State private var glowPulse = false

    private var glowColor: Color {
        isSunrise ? Color(hex: 0xFF8C3A) : Color(hex: 0xC83060)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Line 1: Label + badge ─────────────────────────────────
            HStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(state == .done ? 0.36 : 0.72))
                    .tracking(0.4)
                Spacer(minLength: 4)
                badgeView
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Line 2: Large time ────────────────────────────────────
            Text(time)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(state == .done ? 0.38 : 1.0))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 16)
                .padding(.top, 5)

            // ── Line 3: Icon · condition · cloud% ────────────────────
            if let snap = snapshot {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: snap.sfSymbol)
                        .font(.system(size: 17))
                        .symbolRenderingMode(.multicolor)
                    Text(snap.conditionLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(state == .done ? 0.30 : 0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("· \(Int(snap.cloudCover))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(state == .done ? 0.26 : 0.58))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // ── Line 4: Quality rating ────────────────────────────────
            if let snap = snapshot {
                HStack(spacing: 6) {
                    Circle()
                        .fill(qualityColor(snap.lightQuality))
                        .frame(width: 7, height: 7)
                    Text(snap.lightQuality.label + " light")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(qualityColor(snap.lightQuality)
                            .opacity(state == .done ? 0.38 : 0.92))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Dark frosted glass — always readable regardless of sky color
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.regularMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.28)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    state == .next
                        ? glowColor.opacity(glowPulse ? 0.92 : 0.48)
                        : Color.white.opacity(state == .done ? 0.06 : 0.13),
                    lineWidth: state == .next ? 1.5 : 1
                )
        }
        .shadow(
            color: glowColor.opacity(state == .next ? (glowPulse ? 0.48 : 0.14) : 0),
            radius: 14, x: 0, y: 0
        )
        .opacity(state == .done ? 0.72 : 1.0)
        .onAppear {
            guard state == .next else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: Badge

    @ViewBuilder
    private var badgeView: some View {
        switch state {
        case .next:
            Text("NEXT")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(glowColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(glowColor.opacity(0.18), in: Capsule())
                .overlay(Capsule().strokeBorder(glowColor.opacity(0.50), lineWidth: 1))
        case .done:
            HStack(spacing: 3) {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                Text("DONE").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.30))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.06), in: Capsule())
        case .idle:
            EmptyView()
        }
    }

    // MARK: Helpers

    private func qualityColor(_ q: LightQuality) -> Color {
        switch q {
        case .great: return Color(hex: 0xFFE070)
        case .good:  return Color(hex: 0x88E088)
        case .poor:  return Color(hex: 0x9AAEC4)
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let icon:  String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(.white.opacity(0.85)).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
                Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - SunArcView

private struct SunArcView: View {
    let altitude:   Double
    let azimuth:    Double
    let cloudCover: Double
    let solar:      SolarInfo?
    let now:        Date
    let latitude:   Double
    let longitude:  Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            Canvas { ctx, size in
                let t   = tl.date.timeIntervalSinceReferenceDate
                let hz  = size.height * 0.68
                let cx  = size.width  / 2
                // 28pt inset each side so arc doesn't touch screen edges
                let rx  = size.width  / 2 - 28
                // Endpoints dip 25pt below horizon; peak stays the same via (hz+dip) - (ry+dip)*sin(a)
                let dip: CGFloat = 25

                // Scale peak height to today's max solar altitude at this location
                let maxAlt = maxSolarAltitude()
                let ry     = max(30, (hz - 20) * CGFloat(min(maxAlt / 85.0, 1.0)))

                drawSky(ctx, size: size, hz: hz)
                drawGround(ctx, size: size, hz: hz)
                drawStars(ctx, size: size, hz: hz, t: t)
                drawHorizonGlow(ctx, size: size, hz: hz)
                drawArc(ctx, hz: hz, cx: cx, rx: rx, ry: ry, dip: dip)
                drawTicks(ctx, hz: hz, cx: cx, rx: rx, ry: ry, dip: dip)

                let sp = sunPoint(hz: hz, cx: cx, rx: rx, ry: ry)
                if altitude >= 0 { drawGlowRings(ctx, pos: sp, t: t) }
                if altitude > 1.5 { drawCorona(ctx, pos: sp, t: t) }
                drawSunDot(ctx, pos: sp)
                drawSunLabel(ctx, pos: sp, size: size)
            }
        }
    }

    // ── Geometry ─────────────────────────────────────────────────────

    /// Fraction 0 (sunrise) → 1 (sunset) for the current time.
    private func normalizedTimePosition() -> Double {
        guard let rise = solar?.sunrise, let set = solar?.sunset else { return 0.5 }
        let total = set.timeIntervalSince(rise)
        guard total > 0 else { return 0.5 }
        return now.timeIntervalSince(rise) / total
    }

    /// Sun's peak altitude today (at solar noon) for this lat/lon.
    private func maxSolarAltitude() -> Double {
        guard let noon = solar?.solarNoon else { return max(altitude, 10) }
        return max(SolarCalculator.altitude(for: noon,
                                             latitude: latitude,
                                             longitude: longitude), 1)
    }

    private func sunPoint(hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPoint {
        // x: time-based position (sunrise=left end, sunset=right end)
        let t = normalizedTimePosition()
        let clampedT = max(-0.3, min(1.3, t))
        let a = Double.pi * (1.0 - clampedT)
        let x = cx + rx * CGFloat(cos(a))
        // y: actual altitude mapped against today's maximum
        let maxAlt = maxSolarAltitude()
        let y = hz - ry * CGFloat(altitude / maxAlt)
        return CGPoint(x: x, y: y)
    }

    // ── Sky ───────────────────────────────────────────────────────────

    private func drawSky(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: hz)),
            with: .linearGradient(
                Gradient(colors: skyColors),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: hz)
            )
        )
    }

    // ── Ground ────────────────────────────────────────────────────────

    private func drawGround(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        ctx.fill(
            Path(CGRect(x: 0, y: hz, width: size.width, height: size.height - hz)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x130D04), Color(hex: 0x07061A)]),
                startPoint: CGPoint(x: 0, y: hz),
                endPoint:   CGPoint(x: 0, y: size.height)
            )
        )
    }

    // ── Stars ─────────────────────────────────────────────────────────

    private func drawStars(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat, t: Double) {
        let fade: Double
        switch altitude {
        case ..<(-6): fade = 0.90
        case -6..<2:  fade = max(0, 0.9 * (2.0 - altitude) / 8.0)
        default:      return
        }
        for i in 0..<90 {
            let sx     = abs(sin(Double(i) * 127.1)) * Double(size.width)
            let sy     = abs(cos(Double(i) * 311.7)) * Double(hz) * 0.92
            let twinkle = 0.4 + 0.6 * sin(t * 1.2 + Double(i) * 1.9)
            let alpha  = fade * twinkle * (0.25 + Double(i % 4) / 6.0)
            let r      = CGFloat(0.7 + Double(i % 3) * 0.55)
            ctx.fill(
                Path(ellipseIn: CGRect(x: CGFloat(sx) - r, y: CGFloat(sy) - r,
                                       width: r * 2, height: r * 2)),
                with: .color(.white.opacity(alpha))
            )
        }
    }

    // ── Horizon glow + line ───────────────────────────────────────────

    private func drawHorizonGlow(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        let glowH: CGFloat = 55
        ctx.fill(
            Path(CGRect(x: 0, y: hz - glowH, width: size.width, height: glowH * 2)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: horizonGlowColor.opacity(0),    location: 0),
                    .init(color: horizonGlowColor.opacity(0.45), location: 0.5),
                    .init(color: horizonGlowColor.opacity(0),    location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: hz - glowH),
                endPoint:   CGPoint(x: 0, y: hz + glowH)
            )
        )
        var line = Path()
        line.move(to:    CGPoint(x: 0,           y: hz))
        line.addLine(to: CGPoint(x: size.width,  y: hz))
        ctx.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 0.75)
    }

    // ── Arc — gradient from indigo at ends to gold at peak ────────────

    private func drawArc(_ ctx: GraphicsContext,
                         hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat, dip: CGFloat) {
        let n    = 80
        let sunT = normalizedTimePosition()
        for i in 0..<n {
            let t0   = Double(i)     / Double(n)
            let t1   = Double(i + 1) / Double(n)
            let a0   = Double.pi * (1 - t0)
            let a1   = Double.pi * (1 - t1)
            // (hz + dip) - (ry + dip)*sin(a) keeps peak unchanged, dips endpoints 'dip' below horizon
            let p0   = CGPoint(x: cx + rx * CGFloat(cos(a0)),
                               y: (hz + dip) - (ry + dip) * CGFloat(sin(a0)))
            let p1   = CGPoint(x: cx + rx * CGFloat(cos(a1)),
                               y: (hz + dip) - (ry + dip) * CGFloat(sin(a1)))
            let tm   = (t0 + t1) / 2
            let peak = sin(.pi * tm)                        // 0 at ends, 1 at top
            let done = tm <= sunT                           // traversed portion of arc

            // indigo (ends) → amber-gold (peak)
            let r = 0.22 + peak * 0.78
            let g = 0.15 + peak * 0.62
            let b = 0.78 - peak * 0.58
            let opacity = done ? (0.55 + peak * 0.40) : (0.18 + peak * 0.22)
            let lw      = CGFloat(done ? 2.5 + peak * 1.5 : 1.2 + peak * 0.5)

            var seg = Path()
            seg.move(to: p0); seg.addLine(to: p1)
            ctx.stroke(seg,
                       with: .color(Color(red: r, green: g, blue: b).opacity(opacity)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
    }

    // ── Tick marks with time labels ───────────────────────────────────

    private func drawTicks(_ ctx: GraphicsContext,
                           hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat, dip: CGFloat) {
        struct Tick { let angle: Double; let label: String; let lx: CGFloat; let ly: CGFloat }
        // sunrise/sunset labels offset upward enough to clear the horizon (ly = -(dip + 14))
        let ticks = [
            Tick(angle: .pi,     label: fmtTime(solar?.sunrise),  lx:  32, ly: -(dip + 14)),
            Tick(angle: .pi / 2, label: fmtTime(solar?.solarNoon),lx:   0, ly:  18),
            Tick(angle: 0,       label: fmtTime(solar?.sunset),   lx: -32, ly: -(dip + 14)),
        ]
        for tk in ticks {
            let a  = tk.angle
            let px = cx + rx * CGFloat(cos(a))
            let py = (hz + dip) - (ry + dip) * CGFloat(sin(a))
            // Dot
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - 3.5, y: py - 3.5, width: 7, height: 7)),
                with: .color(.white.opacity(0.85))
            )
            // Radial tick toward arc centre
            let dx = CGFloat(-cos(a)); let dy = CGFloat(sin(a))
            var tp = Path()
            tp.move(to:    CGPoint(x: px,           y: py))
            tp.addLine(to: CGPoint(x: px + dx * 11, y: py + dy * 11))
            ctx.stroke(tp, with: .color(.white.opacity(0.50)), lineWidth: 1.5)
            // Label — white with strong drop shadow for readability over any sky
            if !tk.label.isEmpty {
                ctx.drawLayer { lc in
                    lc.addFilter(.shadow(color: .black.opacity(0.80), radius: 4, x: 1, y: 1))
                    lc.draw(
                        Text(tk.label)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white),
                        at: CGPoint(x: px + tk.lx, y: py + tk.ly)
                    )
                }
            }
        }
    }

    // ── Sun glow rings (pulsing) ──────────────────────────────────────

    private func drawGlowRings(_ ctx: GraphicsContext, pos: CGPoint, t: Double) {
        let pulse = CGFloat(0.5 + 0.5 * sin(t * 0.75))
        let dim   = 1.0 - cloudCover / 100 * 0.65
        let rings: [(CGFloat, Double)] = [(38, 0.05), (26, 0.12), (16, 0.21)]
        for (baseR, alpha) in rings {
            let r = baseR + pulse * 5
            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
                with: .color(sunDotColor.opacity(alpha * dim))
            )
        }
    }

    // ── Corona rays ───────────────────────────────────────────────────

    private func drawCorona(_ ctx: GraphicsContext, pos: CGPoint, t: Double) {
        let dim = max(0, 1.0 - cloudCover / 100 * 0.85)
        for i in 0..<12 {
            let a   = Double(i) / 12.0 * .pi * 2 + t * 0.10
            let ir  = CGFloat(12)
            let or  = CGFloat(22 + i % 3 * 5)
            var rp  = Path()
            rp.move(to:    CGPoint(x: pos.x + ir * CGFloat(cos(a)), y: pos.y + ir * CGFloat(sin(a))))
            rp.addLine(to: CGPoint(x: pos.x + or * CGFloat(cos(a)), y: pos.y + or * CGFloat(sin(a))))
            ctx.stroke(rp, with: .color(sunDotColor.opacity(0.28 * dim)),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }

    // ── Sun dot (dimmed when below horizon) ──────────────────────────

    private func drawSunDot(_ ctx: GraphicsContext, pos: CGPoint) {
        let cloudDim = 1.0 - cloudCover / 100 * 0.82
        let altDim   = altitude < 0 ? max(0.20, 1.0 + altitude / 18.0) : 1.0
        let dim      = cloudDim * altDim
        let dr: CGFloat = 9
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - dr, y: pos.y - dr, width: dr * 2, height: dr * 2)),
            with: .color(sunDotColor.opacity(0.90 * dim))
        )
        let cr: CGFloat = 4
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)),
            with: .color(.white.opacity(dim))
        )
    }

    // ── Current time label beside the sun dot ────────────────────────

    private func drawSunLabel(_ ctx: GraphicsContext, pos: CGPoint, size: CGSize) {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "h:mm"
        let label = fmt.string(from: now)
        let offsetX: CGFloat = pos.x > size.width - 70 ? -52 : 18
        ctx.drawLayer { lc in
            lc.addFilter(.shadow(color: .black.opacity(0.80), radius: 4, x: 1, y: 1))
            lc.draw(
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: pos.x + offsetX, y: pos.y - 16)
            )
        }
    }

    // ── Color helpers ─────────────────────────────────────────────────

    private var skyColors: [Color] {
        switch altitude {
        case ..<(-18):  return [Color(hex: 0x000005), Color(hex: 0x000812)]
        case -18..<(-6):return [Color(hex: 0x03000E), Color(hex: 0x0A0028)]
        case  -6..<0:   return [Color(hex: 0x200040), Color(hex: 0x8C1A4A)]
        case   0..<6:   return [Color(hex: 0xCC3300), Color(hex: 0xFFAA44)]
        case   6..<20:  return [Color(hex: 0x1A5FA8), Color(hex: 0x6DB3E8)]
        default:        return [Color(hex: 0x0F4F99), Color(hex: 0x5BA8E0)]
        }
    }

    private var horizonGlowColor: Color {
        switch altitude {
        case ..<(-6): return Color(hex: 0x1A1A8C)
        case -6..<0:  return Color(hex: 0xCC3366)
        case  0..<6:  return Color(hex: 0xFF7733)
        default:      return Color(hex: 0x55AAEE)
        }
    }

    private var sunDotColor: Color {
        switch altitude {
        case ..<(-6): return Color(hex: 0x9933FF)
        case -6..<0:  return Color(hex: 0xFF2255)
        case  0..<6:  return Color(hex: 0xFF5500)
        case  6..<20: return Color(hex: 0xFFCC44)
        default:      return Color(hex: 0xFFF0AA)
        }
    }

    private func fmtTime(_ d: Date?) -> String {
        guard let d else { return "" }
        return d.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Pill style helper

private extension View {
    func pill() -> some View {
        self
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(.white.opacity(0.15), in: Capsule())
    }
}

// MARK: - Color hex

extension Color {
    init(hex: UInt32) {
        self.init(red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255)
    }
}

#Preview { ContentView() }
