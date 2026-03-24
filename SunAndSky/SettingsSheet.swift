import SwiftUI

// MARK: - SettingsSheet

struct SettingsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A1628).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

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
                        SettingsCard(title: "About", icon: "info.circle.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                SettingsInfoRow(label: "App",             value: "Chase the Light")
                                SettingsInfoRow(label: "Version",         value: "1.0.0")
                                SettingsInfoRow(label: "Weather",         value: "Open-Meteo (open-meteo.com)")
                                SettingsInfoRow(label: "Solar math",      value: "USNO algorithm")
                                SettingsInfoRow(label: "Satellite",       value: "NOAA · EUMETSAT · JMA")
                                SettingsInfoRow(label: "Privacy Policy",  value: "haupt2it.github.io/ChaseTheLight")
                            }
                        }
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
        }
        .preferredColorScheme(.dark)
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

// MARK: - SettingsInfoRow

private struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.50))
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}
