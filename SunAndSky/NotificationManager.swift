import Foundation
import Combine
import UserNotifications
import CoreLocation
import WatchConnectivity

// MARK: - NotificationManager

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    // MARK: - Notification identifiers

    static let categoryID    = "CHASE_LIGHT_ALERT"
    static let actionOnMyWay = "ON_MY_WAY"
    static let actionSnooze  = "SNOOZE_15"
    static let actionView    = "VIEW_CONDITIONS"

    // MARK: - Published state

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Next scheduled fire date for each alert type (nil if not scheduled).
    @Published var nextSunriseAlert: Date?
    @Published var nextSunsetAlert:  Date?
    @Published var nextGoldenAlert:  Date?
    @Published var nextBlueAlert:    Date?

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
        Task { await refreshAuthStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthStatus()
        return granted
    }

    func refreshAuthStatus() async {
        let s = await center.notificationSettings()
        authorizationStatus = s.authorizationStatus
    }

    // MARK: - Schedule

    /// Cancel all pending notifications and reschedule for the next 7 days.
    func schedule(solar: SolarInfo,
                  coordinate: CLLocationCoordinate2D,
                  settings: AppSettings,
                  weather: WeatherData?) async {

        guard authorizationStatus == .authorized else { return }

        center.removeAllPendingNotificationRequests()
        nextSunriseAlert = nil
        nextSunsetAlert  = nil
        nextGoldenAlert  = nil
        nextBlueAlert    = nil

        let now         = Date()
        let weatherLine = weather.map { briefWeatherDescription($0) } ?? ""
        var watchTimes: [String: Any] = [:]

        for dayOffset in 0..<7 {
            guard let dayDate = Calendar.current.date(
                byAdding: .day, value: dayOffset, to: now
            ) else { continue }

            let daySolar = SolarCalculator.solarInfo(
                for:       dayDate,
                latitude:  coordinate.latitude,
                longitude: coordinate.longitude
            )
            let phases = LightPhaseCalculator.phases(
                for:       dayDate,
                latitude:  coordinate.latitude,
                longitude: coordinate.longitude,
                solar:     daySolar
            )

            // ── Sunrise ──────────────────────────────────────────────────
            if settings.sunriseAlertEnabled, let sunrise = daySolar.sunrise {
                let fireDate = sunrise.addingTimeInterval(
                    -Double(settings.sunriseLeadMinutes) * 60
                )
                if fireDate > now {
                    let sub = "Sunrise in \(settings.sunriseLeadMinutes) min"
                           + (weatherLine.isEmpty ? "" : " — \(weatherLine)")
                    enqueue(
                        id:       "sunrise-\(dayOffset)",
                        at:       fireDate,
                        title:    "🌅 Chase the Light",
                        subtitle: sub,
                        body:     "Head out now to reach your shooting location on time."
                    )
                    if nextSunriseAlert == nil {
                        nextSunriseAlert = fireDate
                        watchTimes["nextSunriseAlert"] = fireDate.timeIntervalSince1970
                    }
                }
            }

            // ── Sunset ────────────────────────────────────────────────────
            if settings.sunsetAlertEnabled, let sunset = daySolar.sunset {
                let fireDate = sunset.addingTimeInterval(
                    -Double(settings.sunsetLeadMinutes) * 60
                )
                if fireDate > now {
                    let sub = "Sunset in \(settings.sunsetLeadMinutes) min"
                           + (weatherLine.isEmpty ? "" : " — \(weatherLine)")
                    enqueue(
                        id:       "sunset-\(dayOffset)",
                        at:       fireDate,
                        title:    "🌇 Chase the Light",
                        subtitle: sub,
                        body:     "Head out now to reach your shooting location on time."
                    )
                    if nextSunsetAlert == nil {
                        nextSunsetAlert = fireDate
                        watchTimes["nextSunsetAlert"] = fireDate.timeIntervalSince1970
                    }
                }
            }

            // ── Golden Hour ───────────────────────────────────────────────
            if settings.goldenHourAlertEnabled {
                for phase in phases where phase.kind == .goldenHour {
                    for (start, suffix) in [(phase.morningStart, "am"), (phase.eveningStart, "pm")] {
                        guard let start, start > now else { continue }
                        let sub = "Golden Hour starting now"
                               + (weatherLine.isEmpty ? "" : " — \(weatherLine)")
                        enqueue(
                            id:       "golden-\(dayOffset)-\(suffix)",
                            at:       start,
                            title:    "✨ Chase the Light",
                            subtitle: sub,
                            body:     "Warm directional light — perfect for portraits, landscapes, and architecture."
                        )
                        if nextGoldenAlert == nil {
                            nextGoldenAlert = start
                            watchTimes["nextGoldenAlert"] = start.timeIntervalSince1970
                        }
                    }
                }
            }

            // ── Blue Hour ─────────────────────────────────────────────────
            if settings.blueHourAlertEnabled {
                for phase in phases where phase.kind == .blueHour {
                    for (start, suffix) in [(phase.morningStart, "am"), (phase.eveningStart, "pm")] {
                        guard let start, start > now else { continue }
                        let sub = "Blue Hour starting now"
                               + (weatherLine.isEmpty ? "" : " — \(weatherLine)")
                        enqueue(
                            id:       "blue-\(dayOffset)-\(suffix)",
                            at:       start,
                            title:    "🌑 Chase the Light",
                            subtitle: sub,
                            body:     "Even, shadowless cool blue light — great for long exposures and cityscapes."
                        )
                        if nextBlueAlert == nil {
                            nextBlueAlert = start
                            watchTimes["nextBlueAlert"] = start.timeIntervalSince1970
                        }
                    }
                }
            }
        }

        syncTimesToWatch(watchTimes)
    }

    // MARK: - Test notification

    func scheduleTest() async {
        guard authorizationStatus == .authorized else { return }
        let content              = UNMutableNotificationContent()
        content.title            = "🌅 Chase the Light"
        content.subtitle         = "Test — Golden Hour starting now"
        content.body             = "This is a test alert. Real alerts fire automatically before your chosen events."
        content.sound            = .default
        content.categoryIdentifier = Self.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content, trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - Private helpers

    private func enqueue(id: String, at date: Date,
                         title: String, subtitle: String, body: String) {
        let content              = UNMutableNotificationContent()
        content.title            = title
        content.subtitle         = subtitle
        content.body             = body
        content.sound            = .default
        content.categoryIdentifier = Self.categoryID

        let comps   = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func briefWeatherDescription(_ w: WeatherData) -> String {
        switch w.cloudCover {
        case ..<15:  return "Clear skies — excellent light"
        case ..<40:  return "Mostly clear — good light"
        case ..<60:  return "Partly cloudy — fair light"
        case ..<80:  return "Mostly cloudy — limited light"
        default:     return "Overcast — diffuse light"
        }
    }

    private func registerCategories() {
        let onMyWay = UNNotificationAction(
            identifier: Self.actionOnMyWay,
            title:      "🚗 I'm On My Way",
            options:    .foreground
        )
        let snooze = UNNotificationAction(
            identifier: Self.actionSnooze,
            title:      "⏰ Snooze 15 min",
            options:    []
        )
        let viewConditions = UNNotificationAction(
            identifier: Self.actionView,
            title:      "📷 View Conditions",
            options:    .foreground
        )
        let category = UNNotificationCategory(
            identifier:        Self.categoryID,
            actions:           [onMyWay, snooze, viewConditions],
            intentIdentifiers: [],
            options:           .customDismissAction
        )
        center.setNotificationCategories([category])
    }

    private func syncTimesToWatch(_ times: [String: Any]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled,
              !times.isEmpty else { return }
        var ctx = WCSession.default.applicationContext
        times.forEach { ctx[$0] = $1 }
        try? WCSession.default.updateApplicationContext(ctx)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Present notification as banner even when app is in foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    /// Handle interactive notification actions.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {

        case NotificationManager.actionSnooze:
            // Re-fire the same notification 15 minutes from now.
            let snoozed         = response.notification.request.content.mutableCopy()
                                    as! UNMutableNotificationContent
            let trigger         = UNTimeIntervalNotificationTrigger(
                                    timeInterval: 15 * 60, repeats: false)
            let req             = UNNotificationRequest(
                                    identifier: "snooze-\(Date().timeIntervalSince1970)",
                                    content: snoozed, trigger: trigger)
            center.add(req)

        case NotificationManager.actionOnMyWay,
             NotificationManager.actionView:
            // Both are .foreground actions — the app opens automatically.
            break

        default:
            break
        }
        handler()
    }
}
