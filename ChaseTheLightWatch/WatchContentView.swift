import SwiftUI
import UserNotifications

// MARK: - WatchContentView (root)

struct WatchContentView: View {
    @EnvironmentObject private var mgr: WatchSolarManager

    var body: some View {
        if !mgr.isPro {
            WatchProUpsellView()
        } else {
            TabView {
                WatchMainFaceView()
                    .tag(0)
                WatchScheduleView()
                    .tag(1)
                WatchAlertsView()
                    .tag(2)
            }
            .tabViewStyle(.page)
        }
    }
}

// MARK: - Tab 1: Main Glanceable Face

private struct WatchMainFaceView: View {
    @EnvironmentObject private var mgr: WatchSolarManager

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {

                // Phase pill
                if let phase = mgr.currentPhase {
                    Text(phase.name.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(phase.phaseColor)
                        .tracking(1.2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(phase.phaseColor.opacity(0.18), in: Capsule())
                }

                // Countdown to next golden moment
                if let next = mgr.nextGoldenMoment {
                    VStack(spacing: 1) {
                        Text(countdownString(to: next.date))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("until \(next.name)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                // Mini sun arc
                WatchSunArcView(
                    altitude:  mgr.solar.altitude,
                    sunrise:   mgr.solar.sunrise,
                    sunset:    mgr.solar.sunset
                )
                .frame(height: 38)
                .padding(.horizontal, 8)

                // Sunrise / Sunset row
                HStack(spacing: 0) {
                    SunEventLabel(icon: "sunrise.fill", color: Color(hex: 0xFFAA33),
                                  time: mgr.solar.sunrise)
                    Spacer()
                    SunEventLabel(icon: "sunset.fill", color: Color(hex: 0xFF6622),
                                  time: mgr.solar.sunset)
                }
                .padding(.horizontal, 6)
            }
            .padding(.vertical, 6)
        }
        .containerBackground(Color(hex: 0x050B14), for: .navigation)
    }
}

// MARK: - Tab 2: Full Schedule

private struct WatchScheduleView: View {
    @EnvironmentObject private var mgr: WatchSolarManager

    var body: some View {
        List {
            ForEach(mgr.phases) { phase in
                PhaseScheduleRow(phase: phase)
                    .listRowBackground(
                        phase.isActive(at: Date())
                            ? phase.phaseColor.opacity(0.22)
                            : Color.clear
                    )
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Schedule")
        .containerBackground(Color(hex: 0x050B14), for: .navigation)
    }
}

// MARK: - Tab 3: Haptic Alerts

private struct WatchAlertsView: View {
    @EnvironmentObject private var mgr: WatchSolarManager

    var body: some View {
        List {
            Section {
                HapticAlertToggle(
                    title: "Sunrise",
                    subtitle: "\(mgr.sunriseLeadMinutes)m early",
                    icon: "sunrise.fill",
                    color: Color(hex: 0xFFAA33),
                    isOn: Binding(
                        get: { mgr.sunriseAlertEnabled },
                        set: { mgr.sunriseAlertEnabled = $0; mgr.saveAlertSettings() }
                    )
                )
                HapticAlertToggle(
                    title: "Sunset",
                    subtitle: "\(mgr.sunsetLeadMinutes)m early",
                    icon: "sunset.fill",
                    color: Color(hex: 0xFF6622),
                    isOn: Binding(
                        get: { mgr.sunsetAlertEnabled },
                        set: { mgr.sunsetAlertEnabled = $0; mgr.saveAlertSettings() }
                    )
                )
            }
            Section {
                HapticAlertToggle(
                    title: "Golden Hour",
                    subtitle: "At start",
                    icon: "sun.horizon.fill",
                    color: Color(hex: 0xC86420),
                    isOn: Binding(
                        get: { mgr.goldenHourAlertEnabled },
                        set: { mgr.goldenHourAlertEnabled = $0; mgr.saveAlertSettings() }
                    )
                )
                HapticAlertToggle(
                    title: "Blue Hour",
                    subtitle: "At start",
                    icon: "building.fill",
                    color: Color(hex: 0x2A6AAF),
                    isOn: Binding(
                        get: { mgr.blueHourAlertEnabled },
                        set: { mgr.blueHourAlertEnabled = $0; mgr.saveAlertSettings() }
                    )
                )
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Alerts")
        .containerBackground(Color(hex: 0x050B14), for: .navigation)
        .onAppear {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}

// MARK: - Subviews

private struct WatchSunArcView: View {
    let altitude: Double
    let sunrise:  Date?
    let sunset:   Date?

    var body: some View {
        GeometryReader { geo in
            let w  = geo.size.width
            let h  = geo.size.height
            let cx = w / 2
            let cy = h + 4.0
            let r  = w * 0.48
            let t  = sunProgress
            let angle = (1 - t) * Double.pi   // π = left horizon, 0 = right horizon
            let sx = cx + r * cos(angle)
            let sy = cy - r * sin(angle)

            ZStack {
                // Horizon line
                Path { p in
                    p.move(to: CGPoint(x: 4, y: cy))
                    p.addLine(to: CGPoint(x: w - 4, y: cy))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Arc
                Path { p in
                    p.addArc(center: CGPoint(x: cx, y: cy),
                             radius: r,
                             startAngle: .radians(.pi),
                             endAngle: .radians(0),
                             clockwise: false)
                }
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                // Sun dot
                if altitude > -3 {
                    Circle()
                        .fill(sunDotColor)
                        .shadow(color: sunDotColor.opacity(0.6), radius: 4)
                        .frame(width: 9, height: 9)
                        .position(x: sx, y: max(4, min(cy - 4, sy)))
                }
            }
        }
    }

    private var sunProgress: Double {
        let now = Date()
        guard let rise = sunrise, let set = sunset, set > rise else {
            return altitude > 0 ? 0.5 : 0
        }
        if now <= rise { return 0 }
        if now >= set  { return 1 }
        return now.timeIntervalSince(rise) / set.timeIntervalSince(rise)
    }

    private var sunDotColor: Color {
        if altitude > 6  { return Color(hex: 0xFFDD44) }
        if altitude > 0  { return Color(hex: 0xFF8822) }
        return Color(hex: 0x4477BB)
    }
}

private struct SunEventLabel: View {
    let icon: String
    let color: Color
    let time: Date?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(timeString(time))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func timeString(_ date: Date?) -> String {
        guard let d = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: d)
    }
}

private struct PhaseScheduleRow: View {
    let phase: LightPhase
    private let now = Date()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: phase.icon)
                .font(.system(size: 14))
                .foregroundStyle(phase.phaseColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(phase.name)
                    .font(.system(size: 13, weight: phase.isActive(at: now) ? .bold : .regular))
                    .foregroundStyle(phase.isActive(at: now) ? .white : .white.opacity(0.8))
                if let time = nextTimeString() {
                    Text(time)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer()

            if let cd = countdownLabel() {
                Text(cd)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(phase.phaseColor)
            }
        }
        .padding(.vertical, 2)
    }

    private func nextTimeString() -> String? {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        if phase.isActive(at: now) {
            if let end = (phase.morningStart != nil && now >= phase.morningStart! && now <= (phase.morningEnd ?? .distantPast)) ? phase.morningEnd :
                         (phase.eveningEnd ?? nil) {
                return "until \(f.string(from: end))"
            }
        }
        if let win = phase.nextWindow(after: now) {
            return "\(f.string(from: win.start)) – \(f.string(from: win.end))"
        }
        return nil
    }

    private func countdownLabel() -> String? {
        if phase.isActive(at: now) { return "NOW" }
        guard let win = phase.nextWindow(after: now) else { return nil }
        return countdownString(to: win.start)
    }
}

private struct HapticAlertToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .tint(color)
    }
}

// MARK: - Countdown helper

private func countdownString(to date: Date) -> String {
    let secs = max(0, date.timeIntervalSinceNow)
    let h = Int(secs) / 3600
    let m = (Int(secs) % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return "\(m)m" }
    return "<1m"
}
