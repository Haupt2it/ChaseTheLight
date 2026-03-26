import Foundation
import Combine
import CoreLocation
import WatchConnectivity
import UserNotifications

// MARK: - WatchSolarManager

@MainActor
final class WatchSolarManager: NSObject, ObservableObject {

    // MARK: Published solar state

    @Published var solar: SolarInfo = SolarInfo(
        altitude: 0, azimuth: 180,
        sunrise: nil, sunset: nil, solarNoon: nil, dayLength: 0
    )
    @Published var phases: [LightPhase] = []
    @Published var locationReady: Bool = false

    // MARK: Published Pro & alert settings (synced from iOS)

    @Published var isPro: Bool = false
    @Published var sunriseAlertEnabled: Bool  = false
    @Published var sunriseLeadMinutes:  Int   = 15
    @Published var sunsetAlertEnabled:  Bool  = false
    @Published var sunsetLeadMinutes:   Int   = 15
    @Published var goldenHourAlertEnabled: Bool = false
    @Published var blueHourAlertEnabled:   Bool = false

    // MARK: Private

    private let locationManager = CLLocationManager()
    private var location: CLLocation?
    private var updateTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        isPro = UserDefaults.standard.bool(forKey: "watchIsPro")
        loadAlertSettings()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.update() }
        }
    }

    // MARK: - Computed

    var currentPhase: LightPhase? {
        phases.first { $0.isActive(at: Date()) }
    }

    /// Next golden-moment event (golden hour or blue hour start, or sunrise).
    var nextGoldenMoment: (name: String, date: Date)? {
        let now = Date()
        let priority: [LightPhase.Kind] = [.goldenHour, .blueHour]
        for phase in phases {
            guard priority.contains(phase.kind) else { continue }
            if let win = phase.nextWindow(after: now), win.start > now {
                return (phase.name, win.start)
            }
        }
        if let sunrise = solar.sunrise, sunrise > now { return ("Sunrise", sunrise) }
        return nil
    }

    // MARK: - Internal

    func update() {
        guard let loc = location else { return }
        let now = Date()
        solar = SolarCalculator.solarInfo(for: now,
                                          latitude:  loc.coordinate.latitude,
                                          longitude: loc.coordinate.longitude)
        phases = LightPhaseCalculator.phases(for: now,
                                             latitude:  loc.coordinate.latitude,
                                             longitude: loc.coordinate.longitude,
                                             solar: solar)
        scheduleHapticAlerts()
    }

    // MARK: - Haptic alert scheduling

    func scheduleHapticAlerts() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard isPro else { return }

        var events: [(title: String, body: String, fireDate: Date)] = []
        let now = Date()

        if sunriseAlertEnabled, let sunrise = solar.sunrise {
            let fire = sunrise.addingTimeInterval(TimeInterval(-sunriseLeadMinutes * 60))
            if fire > now {
                events.append(("Sunrise in \(sunriseLeadMinutes)m", "Get into position — golden light incoming.", fire))
            }
        }
        if sunsetAlertEnabled, let sunset = solar.sunset {
            let fire = sunset.addingTimeInterval(TimeInterval(-sunsetLeadMinutes * 60))
            if fire > now {
                events.append(("Sunset in \(sunsetLeadMinutes)m", "Get into position — golden light incoming.", fire))
            }
        }
        if goldenHourAlertEnabled {
            for phase in phases where phase.kind == .goldenHour {
                if let win = phase.nextWindow(after: now), win.start > now {
                    events.append(("Golden Hour starting", "Warm directional light — shoot now.", win.start))
                }
            }
        }
        if blueHourAlertEnabled {
            for phase in phases where phase.kind == .blueHour {
                if let win = phase.nextWindow(after: now), win.start > now {
                    events.append(("Blue Hour starting", "Even, shadowless cool light — shoot now.", win.start))
                }
            }
        }

        for event in events {
            let content          = UNMutableNotificationContent()
            content.title        = event.title
            content.body         = event.body
            content.sound        = .defaultCritical
            let comps            = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.fireDate)
            let trigger          = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request          = UNNotificationRequest(identifier: event.title + event.fireDate.description,
                                                         content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Persistence helpers

    private func loadAlertSettings() {
        let ud = UserDefaults.standard
        sunriseAlertEnabled    = ud.bool(forKey: "watchSunriseAlert")
        sunriseLeadMinutes     = ud.object(forKey: "watchSunriseLeadMin") as? Int ?? 15
        sunsetAlertEnabled     = ud.bool(forKey: "watchSunsetAlert")
        sunsetLeadMinutes      = ud.object(forKey: "watchSunsetLeadMin") as? Int ?? 15
        goldenHourAlertEnabled = ud.bool(forKey: "watchGoldenAlert")
        blueHourAlertEnabled   = ud.bool(forKey: "watchBlueAlert")
    }

    func saveAlertSettings() {
        let ud = UserDefaults.standard
        ud.set(sunriseAlertEnabled,    forKey: "watchSunriseAlert")
        ud.set(sunriseLeadMinutes,     forKey: "watchSunriseLeadMin")
        ud.set(sunsetAlertEnabled,     forKey: "watchSunsetAlert")
        ud.set(sunsetLeadMinutes,      forKey: "watchSunsetLeadMin")
        ud.set(goldenHourAlertEnabled, forKey: "watchGoldenAlert")
        ud.set(blueHourAlertEnabled,   forKey: "watchBlueAlert")
        scheduleHapticAlerts()
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchSolarManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.location      = loc
            self.locationReady = true
            self.update()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSolarManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        applyContext(context)
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        applyContext(message)
    }

    private nonisolated func applyContext(_ ctx: [String: Any]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let v = ctx["isPro"] as? Bool {
                self.isPro = v
                UserDefaults.standard.set(v, forKey: "watchIsPro")
            }
            if let v = ctx["sunriseAlertEnabled"] as? Bool { self.sunriseAlertEnabled = v }
            if let v = ctx["sunriseLeadMinutes"]  as? Int  { self.sunriseLeadMinutes  = v }
            if let v = ctx["sunsetAlertEnabled"]  as? Bool { self.sunsetAlertEnabled  = v }
            if let v = ctx["sunsetLeadMinutes"]   as? Int  { self.sunsetLeadMinutes   = v }
            if let v = ctx["goldenHourAlertEnabled"] as? Bool { self.goldenHourAlertEnabled = v }
            if let v = ctx["blueHourAlertEnabled"]   as? Bool { self.blueHourAlertEnabled   = v }
            self.saveAlertSettings()
        }
    }
}
