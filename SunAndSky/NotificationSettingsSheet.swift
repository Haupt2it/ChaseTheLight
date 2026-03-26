import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsSheet

struct NotificationSettingsSheet: View {
    @EnvironmentObject private var appSettings:         AppSettings
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss

    private let leadOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A1628).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // ── Permission denied banner ────────────────────
                        if notificationManager.authorizationStatus == .denied {
                            deniedBanner
                        }

                        // ── Sunrise ─────────────────────────────────────
                        alertCard(
                            title:       "Sunrise",
                            subtitle:    "Alert before sunrise begins",
                            icon:        "sunrise.fill",
                            iconColor:   Color(hex: 0xFF8800),
                            isEnabled:   $appSettings.sunriseAlertEnabled,
                            leadMinutes: $appSettings.sunriseLeadMinutes,
                            nextDate:    notificationManager.nextSunriseAlert
                        )

                        // ── Sunset ──────────────────────────────────────
                        alertCard(
                            title:       "Sunset",
                            subtitle:    "Alert before sunset begins",
                            icon:        "sunset.fill",
                            iconColor:   Color(hex: 0xFF5500),
                            isEnabled:   $appSettings.sunsetAlertEnabled,
                            leadMinutes: $appSettings.sunsetLeadMinutes,
                            nextDate:    notificationManager.nextSunsetAlert
                        )

                        // ── Golden Hour ─────────────────────────────────
                        simpleAlertCard(
                            title:     "Golden Hour",
                            subtitle:  "When warm golden light begins",
                            icon:      "sun.horizon.fill",
                            iconColor: Color(hex: 0xFFBB00),
                            isEnabled: $appSettings.goldenHourAlertEnabled,
                            nextDate:  notificationManager.nextGoldenAlert
                        )

                        // ── Blue Hour ───────────────────────────────────
                        simpleAlertCard(
                            title:     "Blue Hour",
                            subtitle:  "When cool twilight blue begins",
                            icon:      "moon.stars.fill",
                            iconColor: Color(hex: 0x5599FF),
                            isEnabled: $appSettings.blueHourAlertEnabled,
                            nextDate:  notificationManager.nextBlueAlert
                        )

                        travelTimeTip

                        // ── Test notification ───────────────────────────
                        testSection

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Light Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .task { await notificationManager.refreshAuthStatus() }
    }

    // MARK: - Alert card with lead time

    private func alertCard(
        title: String, subtitle: String,
        icon: String, iconColor: Color,
        isEnabled: Binding<Bool>, leadMinutes: Binding<Int>,
        nextDate: Date?
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled.wrappedValue },
                    set: { val in
                        isEnabled.wrappedValue = val
                        if val { Task { _ = await notificationManager.requestAuthorization() } }
                    }
                ))
                .labelsHidden()
                .tint(iconColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isEnabled.wrappedValue {
                Divider()
                    .overlay(.white.opacity(0.12))
                    .padding(.horizontal, 16)

                HStack {
                    Text("Alert me")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.70))
                    Spacer()
                    Picker("Lead time", selection: leadMinutes) {
                        ForEach(leadOptions, id: \.self) { min in
                            Text("\(min) min before").tag(min)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(iconColor)
                    .font(.system(size: 17))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let next = nextDate {
                    Divider()
                        .overlay(.white.opacity(0.08))
                        .padding(.horizontal, 16)
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(iconColor.opacity(0.7))
                        Text("Next: \(nextAlertLabel(next))")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Simple alert card (no lead time)

    private func simpleAlertCard(
        title: String, subtitle: String,
        icon: String, iconColor: Color,
        isEnabled: Binding<Bool>,
        nextDate: Date?
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled.wrappedValue },
                    set: { val in
                        isEnabled.wrappedValue = val
                        if val { Task { _ = await notificationManager.requestAuthorization() } }
                    }
                ))
                .labelsHidden()
                .tint(iconColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isEnabled.wrappedValue, let next = nextDate {
                Divider()
                    .overlay(.white.opacity(0.08))
                    .padding(.horizontal, 16)
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor.opacity(0.7))
                    Text("Next: \(nextAlertLabel(next))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Test section

    private var testSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await notificationManager.scheduleTest() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                    Text("Send Test Notification")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(
                    Color(hex: 0xFFBB00).opacity(0.35), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(notificationManager.authorizationStatus != .authorized)
            .opacity(notificationManager.authorizationStatus == .authorized ? 1 : 0.45)

            Text("Fires in 5 seconds — leave the app to see it as a banner")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.40))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Denied banner

    private var deniedBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.70))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text("Notifications Disabled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Enable notifications in iOS Settings to receive light alerts.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFFBB00))
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Travel time tip

    private var travelTimeTip: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 1)
            Text("Set lead time to match your travel time to your shooting location — the alert fires when you need to **leave**, not when the light peaks.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Date formatting helper

    private func nextAlertLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let tf  = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        let time = tf.string(from: date)
        if cal.isDateInToday(date)    { return "Today at \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow at \(time)" }
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return "\(df.string(from: date)) at \(time)"
    }
}
