import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsSheet

struct NotificationSettingsSheet: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private let leadOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A1628).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        if authStatus == .denied {
                            deniedBanner
                        }

                        // ── Sunrise ────────────────────────────────────
                        alertCard(
                            title:       "Sunrise",
                            subtitle:    "Alert before sunrise begins",
                            icon:        "sunrise.fill",
                            iconColor:   Color(hex: 0xFF8800),
                            isEnabled:   $appSettings.sunriseAlertEnabled,
                            leadMinutes: $appSettings.sunriseLeadMinutes
                        )

                        // ── Sunset ─────────────────────────────────────
                        alertCard(
                            title:       "Sunset",
                            subtitle:    "Alert before sunset begins",
                            icon:        "sunset.fill",
                            iconColor:   Color(hex: 0xFF5500),
                            isEnabled:   $appSettings.sunsetAlertEnabled,
                            leadMinutes: $appSettings.sunsetLeadMinutes
                        )

                        // ── Golden Hour ────────────────────────────────
                        simpleAlertCard(
                            title:     "Golden Hour",
                            subtitle:  "When warm golden light begins",
                            icon:      "sun.horizon.fill",
                            iconColor: Color(hex: 0xFFBB00),
                            isEnabled: $appSettings.goldenHourAlertEnabled
                        )

                        // ── Blue Hour ──────────────────────────────────
                        simpleAlertCard(
                            title:     "Blue Hour",
                            subtitle:  "When cool twilight blue begins",
                            icon:      "moon.stars.fill",
                            iconColor: Color(hex: 0x5599FF),
                            isEnabled: $appSettings.blueHourAlertEnabled
                        )

                        travelTimeTip

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
        .task { await refreshAuthStatus() }
    }

    // MARK: - Alert card with lead time picker

    private func alertCard(
        title: String, subtitle: String,
        icon: String, iconColor: Color,
        isEnabled: Binding<Bool>, leadMinutes: Binding<Int>
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
                        if val { Task { await requestPermission() } }
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
        isEnabled: Binding<Bool>
    ) -> some View {
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
                    if val { Task { await requestPermission() } }
                }
            ))
            .labelsHidden()
            .tint(iconColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .environment(\.colorScheme, .dark)
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

    // MARK: - Permission helpers

    private func refreshAuthStatus() async {
        let current = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = current.authorizationStatus
    }

    private func requestPermission() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authStatus = granted ? .authorized : .denied
    }
}
