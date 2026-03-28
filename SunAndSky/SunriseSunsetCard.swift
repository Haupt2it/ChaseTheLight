import SwiftUI

// MARK: - SunriseSunsetCard

struct SunriseSunsetCard: View {
    @EnvironmentObject private var settings: AppSettings

    let solar:    SolarInfo
    let weather:  WeatherData?
    let now:      Date
    let timeZone: TimeZone?
    @Binding var displayModes: [String: Int]

    private var cardStates: (rise: SunHeroCard.CardState, set: SunHeroCard.CardState) {
        guard let r = solar.sunrise, let s = solar.sunset else { return (.idle, .idle) }
        if now < r      { return (.next, .idle) }
        else if now < s { return (.done, .next) }
        else            { return (.done, .done) }
    }

    var body: some View {
        HStack(spacing: 12) {
            SunHeroCard(
                title:        "Sunrise",
                time:         solar.sunrise.map { settings.timeString($0, timeZone: timeZone) } ?? "—",
                eventDate:    solar.sunrise,
                now:          now,
                snapshot:     solar.sunrise.flatMap { weather?.snapshot(at: $0) },
                isSunrise:    true,
                state:        cardStates.rise,
                key:          "sunrise",
                displayModes: $displayModes
            )
            SunHeroCard(
                title:        "Sunset",
                time:         solar.sunset.map { settings.timeString($0, timeZone: timeZone) } ?? "—",
                eventDate:    solar.sunset,
                now:          now,
                snapshot:     solar.sunset.flatMap { weather?.snapshot(at: $0) },
                isSunrise:    false,
                state:        cardStates.set,
                key:          "sunset",
                displayModes: $displayModes
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - AlertsRow

struct AlertsRow: View {
    @EnvironmentObject private var proManager: ProManager
    var onUpgrade:       () -> Void
    var onNotifications: () -> Void
    let solar:    SolarInfo
    let now:      Date
    let timeZone: TimeZone?

    var body: some View {
        Button {
            if proManager.isPro { onNotifications() }
            else                { onUpgrade() }
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
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass
    private var isPhone: Bool         { hSizeClass == .compact }
    private var isPhonePortrait: Bool { hSizeClass == .compact && vSizeClass == .regular }
    @State private var bellPulse = false

    var body: some View {
        if isPhonePortrait {
            portraitBody
        } else {
            landscapeBody
        }
    }

    // MARK: Portrait

    private var portraitBody: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x7A2800), Color(hex: 0xCC5500), Color(hex: 0xFF9200)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 0) {
                // Top row: bell + title
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .scaleEffect(bellPulse ? 1.06 : 1.0)
                    Text("Chase the Light")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Text("Alerts")
                        .font(.system(size: 22, weight: .black))
                        .lineLimit(1)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xFFDD55), Color(hex: 0xFFAA00)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 1)

                // Bottom: upgrade prompt
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Spacer(minLength: 0)
                        Text("Never miss golden hour")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("Set your departure reminder")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 14)
                    Spacer(minLength: 4)
                    Text("PRO")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(hex: 0xCC4400))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.white.opacity(0.93), in: Capsule())
                        .padding(.trailing, 14)
                }
                .frame(height: 60)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: 0xFF6600).opacity(0.50), radius: 18, x: 0, y: 7)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bellPulse = true
            }
        }
    }

    // MARK: Landscape (existing layout)

    private var landscapeBody: some View {
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
                                .font(.system(size: isPhone ? 18 : 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Alerts")
                                .font(.system(size: isPhone ? 29 : 27, weight: .black))
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
                                    .font(.system(size: isPhone ? 17 : 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Set your departure reminder")
                                    .font(.system(size: isPhone ? 14 : 12, weight: .medium))
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
        .frame(height: isPhone ? 115 : 96)
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
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass
    private var isPhone: Bool         { hSizeClass == .compact }
    private var isPhonePortrait: Bool { hSizeClass == .compact && vSizeClass == .regular }

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
        let leadMinutes: Int?
    }

    private var activeAlerts: [AlertItem] {
        var items: [AlertItem] = []
        if settings.sunriseAlertEnabled {
            let lead = Double(settings.sunriseLeadMinutes) * 60
            let todayTrigger = solar.sunrise.map { $0.addingTimeInterval(-lead) }
            let isTomorrow   = todayTrigger.map { $0 <= now } ?? false
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

    // MARK: Shared layers

    private var cardBackground: some View {
        LinearGradient(
            colors: [Color(hex: 0x080E38), Color(hex: 0x160850), Color(hex: 0x280D78)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var shimmerLayer: some View {
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
    }

    private var alertsHeaderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
            Text("Chase the Light")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(1)
            Text("Alerts")
                .font(.system(size: 20, weight: .black))
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0xFFDD55), Color(hex: 0xFFAA00)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Portrait

    var body: some View {
        if isPhonePortrait {
            portraitBody
        } else {
            landscapeBody
        }
    }

    private var portraitBody: some View {
        ZStack {
            cardBackground
            shimmerLayer
            VStack(spacing: 0) {
                alertsHeaderRow
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 1)
                portraitPillsArea
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
    private var portraitPillsArea: some View {
        let alerts = activeAlerts
        if alerts.isEmpty {
            Text("Tap to set your alerts →")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(16)
        } else {
            // Chunk into rows of 2 for the 2-column grid
            let pairs: [[AlertItem]] = stride(from: 0, to: alerts.count, by: 2).map {
                Array(alerts[$0..<min($0 + 2, alerts.count)])
            }
            VStack(spacing: 2) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 2) {
                        ForEach(pair) { alert in
                            portraitPillCell(alert)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                        // Pad to keep grid even when last row has only 1 item
                        if pair.count == 1 {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func portraitPillCell(_ alert: AlertItem) -> some View {
        ZStack {
            alert.color
            HStack(spacing: 6) {
                Text(alert.icon)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let lead = alert.leadMinutes {
                        Text("\(lead) min before")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                    }
                    if let cd = alert.triggerDate.flatMap({ countdown(to: $0, isTomorrow: alert.isTomorrow) }) {
                        Text(cd)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: Landscape (existing layout)

    private var landscapeBody: some View {
        GeometryReader { geo in
            ZStack {
                cardBackground
                shimmerLayer
                HStack(spacing: 0) {
                    // Left 30% — bell + label
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                            .fixedSize()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chase the Light")
                                .font(.system(size: isPhone ? 20 : 18, weight: .medium))
                                .foregroundStyle(.white.opacity(0.80))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Alerts")
                                .font(.system(size: isPhone ? 23 : 21, weight: .black))
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
        .frame(height: isPhone ? 115 : 96)
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
                                    .font(.system(size: isPhone ? 18 : 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.50)
                                if let lead = alert.leadMinutes {
                                    Text("Alert: \(lead) min before")
                                        .font(.system(size: isPhone ? 15 : 13))
                                        .foregroundStyle(.white.opacity(0.70))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.50)
                                }
                                if let cd = alert.triggerDate.flatMap({ countdown(to: $0, isTomorrow: alert.isTomorrow) }) {
                                    Text(cd)
                                        .font(.system(size: isPhone ? 17 : 15, weight: .semibold))
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

    let title:        String
    let time:         String
    let eventDate:    Date?
    let now:          Date
    let snapshot:     HourlySnapshot?
    let isSunrise:    Bool
    let state:        CardState
    let key:          String
    @Binding var displayModes: [String: Int]

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isPhone: Bool { hSizeClass == .compact }
    @State private var glowPulse = false

    private var mode: Int { displayModes[key] ?? 0 }

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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                badgeView
            }
            .padding(.horizontal, isPhone ? 12 : 16)
            .padding(.top, isPhone ? 12 : 16)

            // ── Line 2: Tappable time / countdown ─────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    displayModes[key] = ((displayModes[key] ?? 0) + 1) % 2
                }
            } label: {
                HStack(alignment: .center, spacing: 5) {
                    if mode == 0 {
                        Text(time)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(state == .done ? 0.38 : 1.0))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    } else {
                        countdownPillContent
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.16)))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.30))
                        .rotationEffect(.degrees(mode == 1 ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: mode)
                }
                .padding(.horizontal, isPhone ? 12 : 16)
                .padding(.top, 5)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.3), value: mode)

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
                .padding(.horizontal, isPhone ? 12 : 16)
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
                .padding(.horizontal, isPhone ? 12 : 16)
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

    // MARK: Countdown pill content

    @ViewBuilder
    private var countdownPillContent: some View {
        if let date = eventDate {
            let diff = date.timeIntervalSince(now)
            if abs(diff) < 300 {
                // Within ±5 min — event is happening now
                Text("NOW")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            } else if diff > 0 {
                // Upcoming today
                let h = Int(diff) / 3600
                let m = (Int(diff) % 3600) / 60
                Text(h > 0 ? "in \(h)h \(m)m" : "in \(m)m")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                // Already passed — show DONE + tomorrow countdown
                let tomorrowDiff = 86400.0 + diff
                let h = Int(max(0, tomorrowDiff)) / 3600
                let m = (Int(max(0, tomorrowDiff)) % 3600) / 60
                VStack(alignment: .leading, spacing: 1) {
                    Text("DONE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Text("tmrw in \(h)h \(m)m")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        } else {
            Text("—")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
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

