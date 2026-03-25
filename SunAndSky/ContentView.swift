import SwiftUI
import CoreLocation
import Combine
import MapKit

// MARK: - ContentView

struct ContentView: View {

    @EnvironmentObject private var settings:   AppSettings
    @EnvironmentObject private var proManager: ProManager

    @StateObject private var location         = LocationManager()
    @StateObject private var weatherService   = WeatherService()
    @StateObject private var satelliteService = SatelliteService()

    @State private var searchText    = ""
    @State private var isSearching   = false
    @State private var searchError:  String?
    @State private var isGeocoding   = false
    @State private var showSettings              = false
    @State private var showUpgrade               = false
    @State private var showNotificationSettings  = false
    @State private var showProToast              = false

    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var pinnedPlaceName:  String = ""
    @State private var locationTimeZone: TimeZone?
    @State private var solar: SolarInfo?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeCoordinate: CLLocationCoordinate2D? { pinnedCoordinate ?? location.coordinate }
    private var activePlaceName:  String   { pinnedPlaceName.isEmpty ? location.placeName : pinnedPlaceName }
    private var activeTimeZone:   TimeZone? { locationTimeZone ?? location.timeZone }
    private var cloudCover:       Double   { weatherService.weather?.cloudCover ?? 0 }

    var body: some View {
        ZStack {
            // ── Sky gradient ───────────────────────────────────────────
            if let solar {
                SkyTheme.make(sunAltitude: solar.altitude).gradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: solar.altitude)
            } else {
                Color(hex: 0x0A1628).ignoresSafeArea()
            }

            // ── Weather overlays (clouds / fog / rain) ─────────────────
            WeatherOverlayView(weather: weatherService.weather)

            // ── Scrollable content ─────────────────────────────────────
            ScrollView {
                VStack(spacing: 0) {
                    if isSearching {
                        header.padding(.top, 56)
                    } else {
                        SunArcHeroView(
                            solar:      solar,
                            cloudCover: cloudCover,
                            now:        now,
                            latitude:   activeCoordinate?.latitude  ?? 0,
                            longitude:  activeCoordinate?.longitude ?? 0
                        )
                        .transition(.opacity)
                        header
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    if let solar {
                        SunriseSunsetCard(
                            solar:    solar,
                            weather:  weatherService.weather,
                            now:      now,
                            timeZone: activeTimeZone
                        )
                        .padding(.top, 20)

                        // ── Alerts banner ─────────────────────────────
                        AlertsRow(
                            showUpgrade:              $showUpgrade,
                            showNotificationSettings: $showNotificationSettings,
                            solar:                    solar,
                            now:                      now,
                            timeZone:                 activeTimeZone
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

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


                        // ── Satellite card ─────────────────────────────
                        if settings.showSatelliteCard {
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
                        }

                        Spacer().frame(height: 48)
                    } else {
                        loadingState.padding(.top, 60)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // ── Purchase success toast ─────────────────────────────────
            if showProToast {
                VStack {
                    Spacer()
                    Text("Welcome to Chase the Light Pro! ✨")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.04, green: 0.52, blue: 0.25).opacity(0.97),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 48)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            location.requestLocation()
            satelliteService.start(imageURL: settings.satelliteRegion.imageURL)
        }
        .onChange(of: settings.satelliteRegion) { _, region in
            satelliteService.start(imageURL: region.imageURL)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(settings)
                .environmentObject(proManager)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeSheet().environmentObject(proManager)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsSheet().environmentObject(settings)
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
        .onChange(of: proManager.isPro) { _, isPro in
            if isPro {
                withAnimation(.spring(duration: 0.45)) { showProToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.35)) { showProToast = false }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        LocationHeaderView(
            solar:               solar,
            now:                 now,
            timeZone:            activeTimeZone,
            placeName:           activePlaceName,
            hasPinnedCoordinate: pinnedCoordinate != nil,
            isGeocoding:         isGeocoding,
            searchError:         searchError,
            isSearching:         $isSearching,
            searchText:          $searchText,
            onSearch:            geocodeSearch,
            onClearPin:          clearPin,
            onCancel:            { isSearching = false; searchError = nil },
            onOpenSettings:      { showSettings = true }
        )
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
}

// MARK: - Pill style helper

extension View {
    func pill() -> some View {
        self
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(.white.opacity(0.15), in: Capsule())
    }
}

// MARK: - Color hex initialiser

extension Color {
    init(hex: UInt32) {
        self.init(red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255)
    }
}


#Preview { ContentView().environmentObject(AppSettings()).environmentObject(ProManager()) }
