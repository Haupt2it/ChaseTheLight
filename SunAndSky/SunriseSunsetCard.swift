import SwiftUI

// MARK: - SunriseSunsetCard

struct SunriseSunsetCard: View {
    @EnvironmentObject private var settings: AppSettings

    let solar:    SolarInfo
    let weather:  WeatherData?
    let now:      Date
    let timeZone: TimeZone?

    private var cardStates: (rise: SunHeroCard.CardState, set: SunHeroCard.CardState) {
        guard let r = solar.sunrise, let s = solar.sunset else { return (.idle, .idle) }
        if now < r      { return (.next, .idle) }
        else if now < s { return (.done, .next) }
        else            { return (.done, .done) }
    }

    var body: some View {
        HStack(spacing: 12) {
            SunHeroCard(
                title:     "Sunrise",
                time:      solar.sunrise.map { settings.timeString($0, timeZone: timeZone) } ?? "—",
                snapshot:  solar.sunrise.flatMap { weather?.snapshot(at: $0) },
                isSunrise: true,
                state:     cardStates.rise
            )
            SunHeroCard(
                title:     "Sunset",
                time:      solar.sunset.map { settings.timeString($0, timeZone: timeZone) } ?? "—",
                snapshot:  solar.sunset.flatMap { weather?.snapshot(at: $0) },
                isSunrise: false,
                state:     cardStates.set
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - AlertsRow

struct AlertsRow: View {
    @EnvironmentObject private var proManager: ProManager
    @Binding var showUpgrade:              Bool
    @Binding var showNotificationSettings: Bool

    var body: some View {
        Button {
            if proManager.isPro { showNotificationSettings = true }
            else                { showUpgrade = true }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFFBB00).opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Chase the Light Alerts")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        if !proManager.isPro { ProBadge() }
                    }
                    Text(proManager.isPro
                         ? "Alerts active — tap to manage"
                         : "Reminders before golden hour, sunrise & sunset")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: proManager.isPro ? "chevron.right" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(proManager.isPro
                                     ? .white.opacity(0.30)
                                     : Color(hex: 0xFFBB00).opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(state == .done ? 0.36 : 0.90))
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

    private func qualityColor(_ q: LightQuality) -> Color {
        switch q {
        case .great: return Color(hex: 0xFFE070)
        case .good:  return Color(hex: 0x88E088)
        case .poor:  return Color(hex: 0x9AAEC4)
        }
    }
}

