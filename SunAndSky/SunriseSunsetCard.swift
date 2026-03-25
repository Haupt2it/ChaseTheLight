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
    let solar:    SolarInfo
    let now:      Date
    let timeZone: TimeZone?

    var body: some View {
        Button {
            if proManager.isPro { showNotificationSettings = true }
            else                { showUpgrade = true }
        } label: {
            if proManager.isPro {
                ProAlertsCard(solar: solar, now: now)
            } else {
                FreeAlertsCard()
            }
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - PressScaleStyle

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: - FreeAlertsCard

private struct FreeAlertsCard: View {
    @State private var bellPulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x7A2800), Color(hex: 0xCC5500), Color(hex: 0xFF9200)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                HStack(spacing: 0) {
                    // Left 30%
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 33))
                            .foregroundStyle(.white)
                            .scaleEffect(bellPulse ? 1.06 : 1.0)
                            .fixedSize()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chase the Light")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Alerts")
                                .font(.system(size: 27, weight: .black))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFDD55), Color(hex: 0xFFAA00)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .frame(width: geo.size.width * 0.30)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 1)
                        .padding(.vertical, 14)

                    // Right 70% — upgrade prompt
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 5) {
                                Spacer(minLength: 0)
                                Text("Never miss golden hour")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Set your departure reminder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 14)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.trailing, 16)
                        }
                        Text("PRO")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color(hex: 0xCC4400))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.white.opacity(0.93), in: Capsule())
                            .padding(.top, 10).padding(.trailing, 14)
                    }
                    .frame(maxHeight: .infinity)
                    .frame(width: geo.size.width * 0.70 - 1)
                }
                .frame(maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .frame(height: 96)
        .shadow(color: Color(hex: 0xFF6600).opacity(0.50), radius: 18, x: 0, y: 7)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bellPulse = true
            }
        }
    }
}

// MARK: - ProAlertsCard

private struct ProAlertsCard: View {
    @EnvironmentObject private var settings: AppSettings

    let solar: SolarInfo
    let now:   Date

    @State private var shimmerX: CGFloat = -0.6

    private struct AlertItem: Identifiable {
        enum Kind { case sunrise, sunset, golden, blue }
        let kind:        Kind
        var id:          Kind  { kind }
        let icon:        String
        let name:        String
        let triggerDate: Date?
        let isTomorrow:  Bool
        let color:       Color
        let leadMinutes: Int?   // nil for alerts without a configurable lead time
    }

    private var activeAlerts: [AlertItem] {
        var items: [AlertItem] = []
        if settings.sunriseAlertEnabled {
            let lead = Double(settings.sunriseLeadMinutes) * 60
            let todayTrigger = solar.sunrise.map { $0.addingTimeInterval(-lead) }
            let isTomorrow   = todayTrigger.map { $0 <= now } ?? false
            // If today's trigger already passed, approximate tomorrow's sunrise as +24h
            let trigger = isTomorrow
                ? solar.sunrise.map { $0.addingTimeInterval(86400 - lead) }
                : todayTrigger
            items.append(.init(kind: .sunrise, icon: "🌅", name: "Sunrise",
                               triggerDate: trigger, isTomorrow: isTomorrow,
                               color: Color(hex: 0x92400E),
                               leadMinutes: settings.sunriseLeadMinutes))
        }
        if settings.sunsetAlertEnabled {
            let trigger = solar.sunset.map {
                $0.addingTimeInterval(-Double(settings.sunsetLeadMinutes) * 60)
            }
            items.append(.init(kind: .sunset, icon: "🌇", name: "Sunset",
                               triggerDate: trigger, isTomorrow: false,
                               color: Color(hex: 0x7F1D1D),
                               leadMinutes: settings.sunsetLeadMinutes))
        }
        if settings.goldenHourAlertEnabled {
            let trigger = solar.sunset.map { $0.addingTimeInterval(-3600) }
            items.append(.init(kind: .golden, icon: "✨", name: "Golden Hour",
                               triggerDate: trigger, isTomorrow: false,
                               color: Color(hex: 0x78350F),
                               leadMinutes: nil))
        }
        if settings.blueHourAlertEnabled {
            let trigger = solar.sunset.map { $0.addingTimeInterval(20 * 60) }
            items.append(.init(kind: .blue, icon: "🔵", name: "Blue Hour",
                               triggerDate: trigger, isTomorrow: false,
                               color: Color(hex: 0x1E3A5F),
                               leadMinutes: nil))
        }
        return items
    }

    private func countdown(to trigger: Date, isTomorrow: Bool) -> String? {
        let interval = trigger.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        let hours   = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let time    = hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
        return isTomorrow ? "tomorrow \(time)" : time
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Navy → indigo gradient
                LinearGradient(
                    colors: [Color(hex: 0x080E38), Color(hex: 0x160850), Color(hex: 0x280D78)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // Shimmer band
                LinearGradient(
                    stops: [
                        .init(color: .clear,               location: 0.0),
                        .init(color: .white.opacity(0.06), location: 0.42),
                        .init(color: .white.opacity(0.11), location: 0.50),
                        .init(color: .white.opacity(0.06), location: 0.58),
                        .init(color: .clear,               location: 1.0),
                    ],
                    startPoint: .init(x: shimmerX,       y: 0.1),
                    endPoint:   .init(x: shimmerX + 0.9, y: 0.9)
                )
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    // Left 30% — bell + label
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                            .fixedSize()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chase the Light")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white.opacity(0.80))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Alerts")
                                .font(.system(size: 21, weight: .black))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFFDD55), Color(hex: 0xFFAA00)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .frame(width: geo.size.width * 0.30)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 1)
                        .padding(.vertical, 14)

                    // Right 70% — alert pills or prompt
                    rightPanel
                        .frame(maxHeight: .infinity)
                        .frame(width: geo.size.width * 0.70 - 1)
                }
                .frame(maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .frame(height: 96)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color(hex: 0x5544CC).opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x1100AA).opacity(0.55), radius: 18, x: 0, y: 7)
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
    }

    @ViewBuilder
    private var rightPanel: some View {
        let alerts = activeAlerts
        if alerts.isEmpty {
            Text("Tap to set your alerts →")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 2) {
                ForEach(alerts) { alert in
                    ZStack {
                        alert.color
                        HStack(spacing: 8) {
                            Text(alert.icon)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.50)
                                if let lead = alert.leadMinutes {
                                    Text("Alert: \(lead) min before")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.70))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.50)
                                }
                                if let cd = alert.triggerDate.flatMap({ countdown(to: $0, isTomorrow: alert.isTomorrow) }) {
                                    Text(cd)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.78))
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

