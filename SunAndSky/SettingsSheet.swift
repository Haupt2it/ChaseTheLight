import SwiftUI

// MARK: - SettingsSheet

struct SettingsSheet: View {
    @EnvironmentObject var settings:   AppSettings
    @EnvironmentObject var proManager: ProManager
    @Environment(\.dismiss) private var dismiss

    @State private var showUpgrade              = false
    @State private var showNotificationSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A1628).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // ── Pro Status ────────────────────────────────
                        ProStatusCard(
                            showUpgrade:              $showUpgrade,
                            showNotificationSettings: $showNotificationSettings
                        )

                        // ── Time Format ───────────────────────────────
                        SettingsCard(title: "Time Format", icon: "clock.fill") {
                            SettingsToggleRow(
                                label:  "24-Hour Clock",
                                detail: "Show times as 14:30 instead of 2:30 PM",
                                isOn:   $settings.use24HourTime
                            )
                        }

                        // ── Temperature ───────────────────────────────
                        SettingsCard(title: "Temperature", icon: "thermometer.medium") {
                            SettingsToggleRow(
                                label:  "Celsius (°C)",
                                detail: "Display temperatures in Celsius instead of Fahrenheit",
                                isOn:   $settings.useCelsius
                            )
                        }

                        // ── Satellite Region ──────────────────────────
                        SettingsCard(title: "Satellite Image Region", icon: "globe.americas.fill") {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("Region", selection: $settings.satelliteRegion) {
                                    ForEach(SatelliteRegion.allCases) { region in
                                        Text(region.pickerLabel).tag(region)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(settings.satelliteRegion.sourceDescription)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }

                        // ── Appearance ────────────────────────────────
                        SettingsCard(title: "Appearance", icon: "eye.fill") {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    label:  "Live Satellite Card",
                                    detail: "Show real-time satellite imagery",
                                    isOn:   $settings.showSatelliteCard
                                )
                                Divider()
                                    .overlay(.white.opacity(0.12))
                                    .padding(.vertical, 4)
                                SettingsToggleRow(
                                    label:  "24-Hour Forecast Strip",
                                    detail: "Show hourly forecast in the weather card",
                                    isOn:   $settings.showForecastStrip
                                )
                            }
                        }

                        // ── About ─────────────────────────────────────
                        AboutCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet().environmentObject(proManager)
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsSheet().environmentObject(settings)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ProStatusCard

private struct ProStatusCard: View {
    @EnvironmentObject private var proManager: ProManager
    @Binding var showUpgrade:              Bool
    @Binding var showNotificationSettings: Bool

    var body: some View {
        if proManager.isPro { proView } else { freeView }
    }

    // MARK: Pro state

    private var proView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFFBB00).opacity(0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chase the Light Pro")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("All Pro features unlocked ✨")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(hex: 0x44DD88))
            }
            .padding(16)

            Divider().overlay(.white.opacity(0.10)).padding(.horizontal, 16)

            // Manage Alerts
            Button { showNotificationSettings = true } label: {
                HStack {
                    Text("Manage Light Alerts")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }

            Divider().overlay(.white.opacity(0.10)).padding(.horizontal, 16)

            Button {
                Task { await proManager.restorePurchases() }
            } label: {
                Text(proManager.isLoading ? "Restoring…" : "Restore Purchase")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(proManager.isLoading)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(hex: 0x44DD88).opacity(0.40), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    // MARK: Free state

    private var freeView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 50, height: 50)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.55))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chase the Light Free")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Unlock departure reminders with Pro")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(16)

            Divider().overlay(.white.opacity(0.10)).padding(.horizontal, 16)

            // Upgrade button
            Button { showUpgrade = true } label: {
                Text("Upgrade to Pro — \(proManager.priceString)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x0D0D0D))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xFFDD00), Color(hex: 0xFF9500)],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Button {
                Task { await proManager.restorePurchases() }
            } label: {
                Text(proManager.isLoading ? "Restoring…" : "Restore Purchase")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(proManager.isLoading)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - AboutCard

private struct AboutCard: View {
    private let privacyURL = URL(string: "https://haupt2it.github.io/ChaseTheLight")!
    private let supportURL  = URL(string: "https://haupt2it.github.io/ChaseTheLight")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header matching SettingsCard style
            Label("About", systemImage: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(spacing: 0) {
                // App + version
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Chase the Light")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("by Jeffrey E. Haupt · v1.0.1")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.bottom, 14)

                Divider().overlay(.white.opacity(0.10))

                // Privacy Policy
                Link(destination: privacyURL) {
                    HStack {
                        Text("Privacy Policy")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.vertical, 12)
                }

                Divider().overlay(.white.opacity(0.10))

                // Support
                Link(destination: supportURL) {
                    HStack {
                        Text("Support")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - SettingsCard

private struct SettingsCard<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.8)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - SettingsToggleRow

private struct SettingsToggleRow: View {
    let label:  String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
    }
}
