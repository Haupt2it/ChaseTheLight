import SwiftUI
import CoreLocation

// MARK: - SunArcHeroView

struct SunArcHeroView: View {
    @EnvironmentObject private var settings: AppSettings

    let solar:      SolarInfo?
    let cloudCover: Double
    let now:        Date
    let latitude:   Double
    let longitude:  Double
    let placeName:  String

    // Interaction (passed from ContentView)
    let hasPinnedCoordinate: Bool
    let isGeocoding:         Bool
    let searchError:         String?
    @Binding var isSearching: Bool
    @Binding var searchText:  String
    let onSearch:       () -> Void
    let onClearPin:     () -> Void
    let onCancel:       () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            // ── Full sky arc canvas (non-interactive) ──────────────────
            Group {
                if let solar {
                    SunArcView(
                        altitude:   solar.altitude,
                        azimuth:    solar.azimuth,
                        cloudCover: cloudCover,
                        solar:      solar,
                        now:        now,
                        latitude:   latitude,
                        longitude:  longitude,
                        use24Hour:  settings.use24HourTime
                    )
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x020818), Color(hex: 0x0A1628)],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
            }
            .allowsHitTesting(false)

            // ── Title + tagline just above the horizon (non-interactive) ─
            // Horizon at 68% = 204pt; ZStack centre = 150pt.
            // offset -15 → VStack centre at 135pt; bottom edge ≈ 175pt,
            // leaving ~29pt of breathing room before the horizon at 204pt.
            VStack(spacing: 2) {
                Text("CHASE THE LIGHT")
                    .font(.system(size: 62, weight: .ultraLight, design: .default))
                    .tracking(62 * 0.15)
                    .foregroundStyle(Color(red: 1.0, green: 0.973, blue: 0.882))   // #FFF8E1
                    .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 2)
                    .multilineTextAlignment(.center)

                Text("Sun, sky, and the perfect moment \u{2014} all in one place.")
                    .font(.system(size: 18, weight: .regular, design: .serif).italic())
                    .tracking(18 * 0.05)
                    .foregroundStyle(Color(red: 1.0, green: 0.878, blue: 0.698))   // #FFE0B2
                    .shadow(color: .black.opacity(0.50), radius: 4, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .offset(y: -15)
            .allowsHitTesting(false)

            // ── Interactive ground zone ────────────────────────────────
            // Horizon at 68% = 204pt; ZStack centre = 150pt.
            // Ground zone: 204–300pt (96pt). Centre at 252pt → offset +102.
            groundContent
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .offset(y: 102)
                .animation(.spring(duration: 0.3), value: isSearching)
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
        .clipped()
    }

    // MARK: - Ground content

    @ViewBuilder
    private var groundContent: some View {
        if isSearching {
            searchBarInGround
                .transition(.opacity)
        } else {
            VStack(spacing: 9) {
                // ── Location name ─────────────────────────────────────
                if !placeName.isEmpty {
                    Text(placeName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.65), radius: 4, x: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                }

                // ── Search field + action buttons row ─────────────────
                HStack(spacing: 8) {
                    // Settings
                    Button { onOpenSettings() } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Search field (tappable proxy)
                    Button { searchText = ""; isSearching = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17))
                                .foregroundStyle(.white.opacity(0.55))
                            Text("Search city or place…")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.42))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // GPS / clear-pin
                    Button { if hasPinnedCoordinate { onClearPin() } } label: {
                        Image(systemName: hasPinnedCoordinate ? "location.fill" : "location")
                            .font(.system(size: 22))
                            .foregroundStyle(hasPinnedCoordinate
                                ? Color(hex: 0x55BBFF)
                                : .white.opacity(0.55))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
    }

    private var searchBarInGround: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: isGeocoding ? "circle.dotted" : "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.7))
                    .symbolEffect(.rotate, isActive: isGeocoding)
                TextField("Search city or place…", text: $searchText)
                    .font(.system(size: 18))
                    .foregroundStyle(.white).tint(.white)
                    .submitLabel(.search).onSubmit { onSearch() }
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Button("Cancel") { onCancel() }
                    .foregroundStyle(.white)
                    .font(.system(size: 17))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)

            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.horizontal, 24)
                    .lineLimit(2)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - LocationHeaderView

struct LocationHeaderView: View {
    @EnvironmentObject private var settings: AppSettings

    let solar:    SolarInfo?
    let now:      Date
    let timeZone: TimeZone?

    var body: some View {
        VStack(spacing: 8) {
            Text(settings.timeString(now, timeZone: timeZone))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(localDateStr(now))
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.7))
            if let solar {
                skyInfoPill(solar: solar)
            }
        }
    }

    // MARK: Sky info pill

    private func skyInfoPill(solar: SolarInfo) -> some View {
        HStack(spacing: 0) {
            // ── Sky condition ─────────────────────────────────────────
            Text(SkyTheme.make(sunAltitude: solar.altitude).label)

            pillDivider

            // ── Solar Noon ────────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.white.opacity(0.75))
                Text(solar.solarNoon.map { settings.timeString($0, timeZone: timeZone) } ?? "—")
            }

            pillDivider

            // ── Day Length ────────────────────────────────────────────
            HStack(spacing: 4) {
                Text("Length of Day")
                Image(systemName: "clock.fill")
                    .foregroundStyle(.white.opacity(0.75))
                Text(dayLengthStr(solar.dayLength))
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.80)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.white.opacity(0.15), in: Capsule())
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.28))
            .frame(width: 1, height: 11)
            .padding(.horizontal, 10)
    }

    private func dayLengthStr(_ seconds: TimeInterval) -> String {
        if seconds == 0     { return "Polar Night" }
        if seconds >= 86400 { return "Midnight Sun" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    // MARK: Formatters

    private func localDateStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE, MMMM d"
        if let tz = timeZone { f.timeZone = tz }
        return f.string(from: date)
    }
}

// MARK: - SunArcView

private struct SunArcView: View {
    let altitude:   Double
    let azimuth:    Double
    let cloudCover: Double
    let solar:      SolarInfo?
    let now:        Date
    let latitude:   Double
    let longitude:  Double
    let use24Hour:  Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            Canvas { ctx, size in
                let t   = tl.date.timeIntervalSinceReferenceDate
                let hz  = size.height * 0.68
                let cx  = size.width  / 2
                // 28pt inset each side so arc doesn't touch screen edges
                let rx  = size.width  / 2 - 28
                // Endpoints dip 25pt below horizon; peak stays the same via (hz+dip) - (ry+dip)*sin(a)
                let dip: CGFloat = 25

                // Scale peak height to today's max solar altitude at this location
                let maxAlt = maxSolarAltitude()
                let ry     = max(30, (hz - 20) * CGFloat(min(maxAlt / 85.0, 1.0)))

                drawSky(ctx, size: size, hz: hz)
                drawGround(ctx, size: size, hz: hz)
                drawStars(ctx, size: size, hz: hz, t: t)
                drawHorizonGlow(ctx, size: size, hz: hz)
                drawArc(ctx, hz: hz, cx: cx, rx: rx, ry: ry, dip: dip)
                drawTicks(ctx, hz: hz, cx: cx, rx: rx, ry: ry, dip: dip)

                let sp = sunPoint(hz: hz, cx: cx, rx: rx, ry: ry)
                if altitude >= 0 { drawGlowRings(ctx, pos: sp, t: t) }
                if altitude > 1.5 { drawCorona(ctx, pos: sp, t: t) }
                drawSunDot(ctx, pos: sp)
                drawSunLabel(ctx, pos: sp, size: size)
            }
        }
    }

    // ── Geometry ──────────────────────────────────────────────────────

    /// Fraction 0 (sunrise) → 1 (sunset) for the current time.
    private func normalizedTimePosition() -> Double {
        guard let rise = solar?.sunrise, let set = solar?.sunset else { return 0.5 }
        let total = set.timeIntervalSince(rise)
        guard total > 0 else { return 0.5 }
        return now.timeIntervalSince(rise) / total
    }

    /// Sun's peak altitude today (at solar noon) for this lat/lon.
    private func maxSolarAltitude() -> Double {
        guard let noon = solar?.solarNoon else { return max(altitude, 10) }
        return max(SolarCalculator.altitude(for: noon,
                                             latitude: latitude,
                                             longitude: longitude), 1)
    }

    private func sunPoint(hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPoint {
        let t        = normalizedTimePosition()
        let clampedT = max(-0.3, min(1.3, t))
        let a        = Double.pi * (1.0 - clampedT)
        let x        = cx + rx * CGFloat(cos(a))
        let maxAlt   = maxSolarAltitude()
        let y        = hz - ry * CGFloat(altitude / maxAlt)
        return CGPoint(x: x, y: y)
    }

    // ── Sky ───────────────────────────────────────────────────────────

    private func drawSky(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: hz)),
            with: .linearGradient(
                Gradient(colors: skyColors),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: hz)
            )
        )
    }

    // ── Ground ────────────────────────────────────────────────────────

    private func drawGround(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        ctx.fill(
            Path(CGRect(x: 0, y: hz, width: size.width, height: size.height - hz)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x130D04), Color(hex: 0x07061A)]),
                startPoint: CGPoint(x: 0, y: hz),
                endPoint:   CGPoint(x: 0, y: size.height)
            )
        )
    }

    // ── Stars ─────────────────────────────────────────────────────────

    private func drawStars(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat, t: Double) {
        let fade: Double
        switch altitude {
        case ..<(-6): fade = 0.90
        case -6..<2:  fade = max(0, 0.9 * (2.0 - altitude) / 8.0)
        default:      return
        }
        for i in 0..<90 {
            let sx      = abs(sin(Double(i) * 127.1)) * Double(size.width)
            let sy      = abs(cos(Double(i) * 311.7)) * Double(hz) * 0.92
            let twinkle = 0.4 + 0.6 * sin(t * 1.2 + Double(i) * 1.9)
            let alpha   = fade * twinkle * (0.25 + Double(i % 4) / 6.0)
            let r       = CGFloat(0.7 + Double(i % 3) * 0.55)
            ctx.fill(
                Path(ellipseIn: CGRect(x: CGFloat(sx) - r, y: CGFloat(sy) - r,
                                       width: r * 2, height: r * 2)),
                with: .color(.white.opacity(alpha))
            )
        }
    }

    // ── Horizon glow + line ───────────────────────────────────────────

    private func drawHorizonGlow(_ ctx: GraphicsContext, size: CGSize, hz: CGFloat) {
        let glowH: CGFloat = 55
        ctx.fill(
            Path(CGRect(x: 0, y: hz - glowH, width: size.width, height: glowH * 2)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: horizonGlowColor.opacity(0),    location: 0),
                    .init(color: horizonGlowColor.opacity(0.45), location: 0.5),
                    .init(color: horizonGlowColor.opacity(0),    location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: hz - glowH),
                endPoint:   CGPoint(x: 0, y: hz + glowH)
            )
        )
        var line = Path()
        line.move(to:    CGPoint(x: 0,          y: hz))
        line.addLine(to: CGPoint(x: size.width, y: hz))
        ctx.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 0.75)
    }

    // ── Arc — gradient from indigo at ends to gold at peak ────────────

    private func drawArc(_ ctx: GraphicsContext,
                         hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat, dip: CGFloat) {
        let n    = 80
        let sunT = normalizedTimePosition()
        for i in 0..<n {
            let t0 = Double(i)     / Double(n)
            let t1 = Double(i + 1) / Double(n)
            let a0 = Double.pi * (1 - t0)
            let a1 = Double.pi * (1 - t1)
            // (hz + dip) - (ry + dip)*sin(a) keeps peak unchanged, dips endpoints 'dip' below horizon
            let p0 = CGPoint(x: cx + rx * CGFloat(cos(a0)),
                             y: (hz + dip) - (ry + dip) * CGFloat(sin(a0)))
            let p1 = CGPoint(x: cx + rx * CGFloat(cos(a1)),
                             y: (hz + dip) - (ry + dip) * CGFloat(sin(a1)))
            let tm   = (t0 + t1) / 2
            let peak = sin(.pi * tm)          // 0 at ends, 1 at top
            let done = tm <= sunT             // traversed portion of arc

            // indigo (ends) → amber-gold (peak)
            let r = 0.22 + peak * 0.78
            let g = 0.15 + peak * 0.62
            let b = 0.78 - peak * 0.58
            let opacity = done ? (0.55 + peak * 0.40) : (0.18 + peak * 0.22)
            let lw      = CGFloat(done ? 2.5 + peak * 1.5 : 1.2 + peak * 0.5)

            var seg = Path()
            seg.move(to: p0); seg.addLine(to: p1)
            ctx.stroke(seg,
                       with: .color(Color(red: r, green: g, blue: b).opacity(opacity)),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
    }

    // ── Tick marks with time labels ───────────────────────────────────

    private func drawTicks(_ ctx: GraphicsContext,
                           hz: CGFloat, cx: CGFloat, rx: CGFloat, ry: CGFloat, dip: CGFloat) {
        struct Tick { let angle: Double; let label: String; let lx: CGFloat; let ly: CGFloat }
        // sunrise/sunset labels offset upward enough to clear the horizon (ly = -(dip + 14))
        let ticks = [
            Tick(angle: .pi,     label: fmtTime(solar?.sunrise),   lx:  32, ly: -(dip + 14)),
            Tick(angle: .pi / 2, label: fmtTime(solar?.solarNoon), lx:   0, ly:  18),
            Tick(angle: 0,       label: fmtTime(solar?.sunset),    lx: -32, ly: -(dip + 14)),
        ]
        for tk in ticks {
            let a  = tk.angle
            let px = cx + rx * CGFloat(cos(a))
            let py = (hz + dip) - (ry + dip) * CGFloat(sin(a))
            // Dot
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - 3.5, y: py - 3.5, width: 7, height: 7)),
                with: .color(.white.opacity(0.85))
            )
            // Radial tick toward arc centre
            let dx = CGFloat(-cos(a)); let dy = CGFloat(sin(a))
            var tp = Path()
            tp.move(to:    CGPoint(x: px,           y: py))
            tp.addLine(to: CGPoint(x: px + dx * 11, y: py + dy * 11))
            ctx.stroke(tp, with: .color(.white.opacity(0.50)), lineWidth: 1.5)
            // Label — white with strong drop shadow for readability over any sky
            if !tk.label.isEmpty {
                ctx.drawLayer { lc in
                    lc.addFilter(.shadow(color: .black.opacity(0.80), radius: 4, x: 1, y: 1))
                    lc.draw(
                        Text(tk.label)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white),
                        at: CGPoint(x: px + tk.lx, y: py + tk.ly)
                    )
                }
            }
        }
    }

    // ── Sun glow rings (pulsing) ──────────────────────────────────────

    private func drawGlowRings(_ ctx: GraphicsContext, pos: CGPoint, t: Double) {
        let pulse = CGFloat(0.5 + 0.5 * sin(t * 0.75))
        let dim   = 1.0 - cloudCover / 100 * 0.65
        let rings: [(CGFloat, Double)] = [(38, 0.05), (26, 0.12), (16, 0.21)]
        for (baseR, alpha) in rings {
            let r = baseR + pulse * 5
            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
                with: .color(sunDotColor.opacity(alpha * dim))
            )
        }
    }

    // ── Corona rays ───────────────────────────────────────────────────

    private func drawCorona(_ ctx: GraphicsContext, pos: CGPoint, t: Double) {
        let dim = max(0, 1.0 - cloudCover / 100 * 0.85)
        for i in 0..<12 {
            let a  = Double(i) / 12.0 * .pi * 2 + t * 0.10
            let ir = CGFloat(12)
            let or = CGFloat(22 + i % 3 * 5)
            var rp = Path()
            rp.move(to:    CGPoint(x: pos.x + ir * CGFloat(cos(a)), y: pos.y + ir * CGFloat(sin(a))))
            rp.addLine(to: CGPoint(x: pos.x + or * CGFloat(cos(a)), y: pos.y + or * CGFloat(sin(a))))
            ctx.stroke(rp, with: .color(sunDotColor.opacity(0.28 * dim)),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }

    // ── Sun dot (dimmed when below horizon) ──────────────────────────

    private func drawSunDot(_ ctx: GraphicsContext, pos: CGPoint) {
        let cloudDim = 1.0 - cloudCover / 100 * 0.82
        let altDim   = altitude < 0 ? max(0.20, 1.0 + altitude / 18.0) : 1.0
        let dim      = cloudDim * altDim
        let dr: CGFloat = 9
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - dr, y: pos.y - dr, width: dr * 2, height: dr * 2)),
            with: .color(sunDotColor.opacity(0.90 * dim))
        )
        let cr: CGFloat = 4
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)),
            with: .color(.white.opacity(dim))
        )
    }

    // ── Current time label beside the sun dot ────────────────────────

    private func drawSunLabel(_ ctx: GraphicsContext, pos: CGPoint, size: CGSize) {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        let label   = fmt.string(from: now)
        let offsetX: CGFloat = pos.x > size.width - 70 ? -52 : 18
        ctx.drawLayer { lc in
            lc.addFilter(.shadow(color: .black.opacity(0.80), radius: 4, x: 1, y: 1))
            lc.draw(
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: pos.x + offsetX, y: pos.y - 16)
            )
        }
    }

    // ── Color helpers ─────────────────────────────────────────────────

    private var skyColors: [Color] {
        switch altitude {
        case ..<(-18):   return [Color(hex: 0x000005), Color(hex: 0x000812)]
        case -18..<(-6): return [Color(hex: 0x03000E), Color(hex: 0x0A0028)]
        case  -6..<0:    return [Color(hex: 0x200040), Color(hex: 0x8C1A4A)]
        case   0..<6:    return [Color(hex: 0xCC3300), Color(hex: 0xFFAA44)]
        case   6..<20:   return [Color(hex: 0x1A5FA8), Color(hex: 0x6DB3E8)]
        default:         return [Color(hex: 0x0F4F99), Color(hex: 0x5BA8E0)]
        }
    }

    private var horizonGlowColor: Color {
        switch altitude {
        case ..<(-6): return Color(hex: 0x1A1A8C)
        case -6..<0:  return Color(hex: 0xCC3366)
        case  0..<6:  return Color(hex: 0xFF7733)
        default:      return Color(hex: 0x55AAEE)
        }
    }

    private var sunDotColor: Color {
        switch altitude {
        case ..<(-6): return Color(hex: 0x9933FF)
        case -6..<0:  return Color(hex: 0xFF2255)
        case  0..<6:  return Color(hex: 0xFF5500)
        case  6..<20: return Color(hex: 0xFFCC44)
        default:      return Color(hex: 0xFFF0AA)
        }
    }

    private func fmtTime(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return f.string(from: d)
    }
}
