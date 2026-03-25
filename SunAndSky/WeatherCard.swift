import SwiftUI

// MARK: - CurrentConditionsCard

struct CurrentConditionsCard: View {
    @EnvironmentObject private var settings: AppSettings

    let weather:     WeatherData
    let solar:       SolarInfo?
    let timeZone:    TimeZone?
    let source:      WeatherSource
    let onSourceTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Current conditions row ────────────────────────────────
            HStack {
                VStack(spacing: 5) {
                    Image(systemName: weather.sfSymbol)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.multicolor)
                    Text(settings.temperatureString(weather.temperature))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(weather.conditionLabel)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "cloud.fill",    label: "Cloud",      value: "\(Int(weather.cloudCover))%")
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "humidity.fill", label: "Humidity",   value: weather.humidityLabel)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "wind",          label: "Wind",       value: weather.windSpeedLabel)
                Divider().frame(height: 40).overlay(.white.opacity(0.2))
                WeatherMiniStat(icon: "eye.fill",      label: "Visibility", value: weather.visibilityLabel)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)

            if settings.showForecastStrip {
                Divider().overlay(.white.opacity(0.25)).padding(.horizontal, 14)

                // ── 24-hour forecast strip ────────────────────────────
                HStack {
                    Text("24-Hour Forecast")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                forecastStrip
            }

            // ── Day summary ──────────────────────────────────────────
            Divider().overlay(.white.opacity(0.25)).padding(.horizontal, 14)
            Text(daySummary)
                .font(.system(size: 17))
                .italic()
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // ── Attribution (tappable → opens Settings) ──────────────
            Divider().overlay(.white.opacity(0.12)).padding(.horizontal, 14)
            Button(action: onSourceTap) {
                HStack(spacing: 4) {
                    Text(source.attributionLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.38))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.28))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    private var forecastStrip: some View {
        let cal         = Calendar.current
        let now2        = Date()
        let nowHour     = cal.component(.hour, from: now2)
        let slots       = stride(from: 0, to: 24, by: 2).map { $0 }
        let currentSlot = slots.last(where: { $0 <= nowHour }) ?? 0
        let today       = cal.startOfDay(for: now2)
        let rise        = solar?.sunrise
        let set         = solar?.sunset

        func lightWindow(for h: Int) -> ForecastCell.LightWindow? {
            guard let rise, let set else { return nil }
            guard let ss = cal.date(byAdding: .hour, value: h,     to: today),
                  let se = cal.date(byAdding: .hour, value: h + 2, to: today) else { return nil }
            if ss < rise.addingTimeInterval(3600) && se > rise              { return .golden }
            if ss < set  && se > set.addingTimeInterval(-3600)              { return .golden }
            if ss < rise && se > rise.addingTimeInterval(-1200)             { return .blue }
            if ss < set.addingTimeInterval(1200) && se > set               { return .blue }
            return nil
        }

        let sunriseHour = rise.map { cal.component(.hour, from: $0) }
        let sunsetHour  = set.map  { cal.component(.hour, from: $0) }

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(slots, id: \.self) { h in
                        if let snap = weather.hourlySnapshots.first(where: { $0.hour == h }) {
                            ForecastCell(
                                snapshot:    snap,
                                isCurrent:   h == currentSlot,
                                isSunrise:   sunriseHour.map { abs($0 - h) <= 1 } ?? false,
                                isSunset:    sunsetHour.map  { abs($0 - h) <= 1 } ?? false,
                                lightWindow: lightWindow(for: h)
                            )
                            .id(h)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .onAppear { proxy.scrollTo(currentSlot, anchor: .center) }
        }
    }

    private var daySummary: String {
        let rainCodes: Set<Int> = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]
        let rainyHours = weather.hourlySnapshots.filter { rainCodes.contains($0.weatherCode) }.count
        let conditionPhrase: String
        if rainyHours > 4               { conditionPhrase = "a rainy day" }
        else if weather.cloudCover > 60 { conditionPhrase = "mostly overcast skies" }
        else if weather.cloudCover >= 25 { conditionPhrase = "partly cloudy skies" }
        else                            { conditionPhrase = "mostly clear skies" }

        if let sunset = solar?.sunset {
            let h  = Calendar.current.component(.hour, from: sunset)
            let tf = settings.timeString(sunset, timeZone: timeZone)
            if let snap = weather.hourlySnapshots.first(where: { $0.hour == h }) {
                switch snap.lightQuality {
                case .great: return "Expect \(conditionPhrase) with a stunning golden hour at \(tf)"
                case .good:  return "Expect \(conditionPhrase) — clean sunset light at \(tf)"
                case .poor:  return "Expect \(conditionPhrase) today"
                }
            }
        }
        return "Expect \(conditionPhrase) today"
    }
}

// MARK: - ForecastCell

private struct ForecastCell: View {
    @EnvironmentObject private var settings: AppSettings

    enum LightWindow { case golden, blue }

    let snapshot:    HourlySnapshot
    let isCurrent:   Bool
    let isSunrise:   Bool
    let isSunset:    Bool
    let lightWindow: LightWindow?

    var body: some View {
        VStack(spacing: 0) {
            // ── Period badge row (golden / blue / empty) ──────────────
            Group {
                if let lw = lightWindow {
                    Text(lw == .golden ? "Golden" : "Blue")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x77AAFF))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(
                            Capsule().fill((lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x77AAFF)).opacity(0.18))
                        )
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .frame(height: 20)
            .padding(.top, 8)

            // ── Time label ────────────────────────────────────────────
            Text(timeLabel)
                .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? .white : .white.opacity(0.75))
                .padding(.top, 4)

            // ── Weather icon (with sunrise/sunset badge) ──────────────
            ZStack(alignment: .topTrailing) {
                Image(systemName: snapshot.sfSymbol)
                    .font(.system(size: 22))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 30, height: 28)
                if isSunrise || isSunset {
                    Image(systemName: isSunrise ? "sunrise.fill" : "sunset.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: 0xFFB347))
                        .offset(x: 5, y: -4)
                }
            }
            .padding(.top, 4)

            // ── Temperature ───────────────────────────────────────────
            Text(settings.temperatureString(snapshot.temperature))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 3)

            // ── Cloud cover ───────────────────────────────────────────
            HStack(spacing: 2) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.50))
                Text("\(Int(snapshot.cloudCover))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .frame(width: 76)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.22))
            } else if let lw = lightWindow {
                let c = lw == .golden ? Color(hex: 0xFFCC55) : Color(hex: 0x5577FF)
                RoundedRectangle(cornerRadius: 11).fill(c.opacity(0.13))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(c.opacity(0.35), lineWidth: 1))
            } else if isSunrise || isSunset {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(hex: 0xFFB347).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color(hex: 0xFFB347).opacity(0.35), lineWidth: 1))
            }
        }
    }

    private var timeLabel: String {
        let h = snapshot.hour
        if settings.use24HourTime { return String(format: "%02d:00", h) }
        if h == 0  { return "12 AM" }
        if h < 12  { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

// MARK: - WeatherMiniStat

private struct WeatherMiniStat: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }
}
