import Foundation

// MARK: - Solar Output

struct SolarInfo {
    let altitude: Double      // degrees above/below horizon
    let azimuth: Double       // degrees clockwise from North
    let sunrise: Date?
    let sunset: Date?
    let solarNoon: Date?
    let dayLength: TimeInterval  // seconds; 0 if polar night, 86400 if midnight sun
}

// MARK: - SolarCalculator

enum SolarCalculator {

    // MARK: Public API

    /// Calculate full solar info for a given moment and location.
    static func solarInfo(for date: Date, latitude: Double, longitude: Double) -> SolarInfo {
        let alt = altitude(for: date, latitude: latitude, longitude: longitude)
        let az  = azimuth(for: date, latitude: latitude, longitude: longitude)
        let (rise, set, noon) = riseSetNoon(for: date, latitude: latitude, longitude: longitude)

        let length: TimeInterval
        if let r = rise, let s = set {
            length = s.timeIntervalSince(r)
        } else if alt > 0 {
            length = 86400  // midnight sun
        } else {
            length = 0      // polar night
        }

        return SolarInfo(altitude: alt, azimuth: az,
                         sunrise: rise, sunset: set,
                         solarNoon: noon, dayLength: length)
    }

    /// Sun altitude in degrees (positive = above horizon).
    static func altitude(for date: Date, latitude: Double, longitude: Double) -> Double {
        let jd  = julianDate(from: date)
        let lst = localSiderealTime(jd: jd, longitude: longitude)
        let (dec, ra) = sunDeclinationAndRA(jd: jd)
        let ha  = toRadians(lst * 15 - ra)   // hour angle in radians
        let lat = toRadians(latitude)
        let sinAlt = sin(lat) * sin(toRadians(dec)) +
                     cos(lat) * cos(toRadians(dec)) * cos(ha)
        return toDegrees(asin(sinAlt))
    }

    /// Sun azimuth in degrees clockwise from North.
    static func azimuth(for date: Date, latitude: Double, longitude: Double) -> Double {
        let jd  = julianDate(from: date)
        let lst = localSiderealTime(jd: jd, longitude: longitude)
        let (dec, ra) = sunDeclinationAndRA(jd: jd)
        let ha  = toRadians(lst * 15 - ra)
        let lat = toRadians(latitude)
        let decR = toRadians(dec)

        let sinAlt = sin(lat) * sin(decR) + cos(lat) * cos(decR) * cos(ha)
        let cosAlt = cos(asin(sinAlt))

        var cosAz = (sin(decR) - sin(lat) * sinAlt) / (cos(lat) * cosAlt)
        cosAz = max(-1, min(1, cosAz))  // clamp floating-point drift
        var az = toDegrees(acos(cosAz))
        if sin(ha) > 0 { az = 360 - az }
        return az
    }

    // MARK: - Altitude Crossings

    /// Returns the times when the sun crosses `altitude` (degrees) on the given day.
    /// `rising` = morning crossing (sun going up); `setting` = evening crossing (sun going down).
    /// Returns nil for each value when the sun never crosses that altitude today (polar regions).
    static func altitudeCrossingTimes(for date: Date, latitude: Double, longitude: Double,
                                      altitude: Double) -> (rising: Date?, setting: Date?) {
        let jd0    = julianNoon(from: date, longitude: longitude)
        let noonJD = solarNoonJD(jd0: jd0, longitude: longitude)
        let (dec, _) = sunDeclinationAndRA(jd: noonJD)
        let lat  = toRadians(latitude)
        let decR = toRadians(dec)
        let cosH = (sin(toRadians(altitude)) - sin(lat) * sin(decR)) / (cos(lat) * cos(decR))
        guard cosH >= -1 && cosH <= 1 else { return (nil, nil) }
        let haHours = toDegrees(acos(cosH)) / 15.0
        let rising  = julianDateToDate(noonJD - haHours / 24.0)
        let setting = julianDateToDate(noonJD + haHours / 24.0)
        return (rising, setting)
    }

    // MARK: - Sunrise / Sunset / Solar Noon

    /// Returns (sunrise, sunset, solarNoon) in UTC, all for the calendar day of `date`.
    static func riseSetNoon(for date: Date, latitude: Double, longitude: Double)
        -> (sunrise: Date?, sunset: Date?, solarNoon: Date?)
    {
        let jd0 = julianNoon(from: date, longitude: longitude)

        // Solar noon via equation of time
        let noonJD = solarNoonJD(jd0: jd0, longitude: longitude)

        let (dec, _) = sunDeclinationAndRA(jd: noonJD)
        let lat = toRadians(latitude)
        let decR = toRadians(dec)

        // Hour angle at sunrise/sunset (geometric, corrected for refraction & disc radius)
        let cosH = (sin(toRadians(-0.8333)) - sin(lat) * sin(decR)) /
                   (cos(lat) * cos(decR))

        let noon = julianDateToDate(noonJD)

        guard cosH >= -1 && cosH <= 1 else {
            // Midnight sun or polar night
            return (nil, nil, noon)
        }

        let haHours = toDegrees(acos(cosH)) / 15.0
        let rise = julianDateToDate(noonJD - haHours / 24.0)
        let set  = julianDateToDate(noonJD + haHours / 24.0)
        return (rise, set, noon)
    }

    // MARK: - Julian Date Helpers

    static func julianDate(from date: Date) -> Double {
        // J2000.0 epoch = JD 2451545.0
        let jd = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        return jd
    }

    static func julianDateToDate(_ jd: Double) -> Date {
        let t = (jd - 2440587.5) * 86400.0
        return Date(timeIntervalSince1970: t)
    }

    // MARK: - Internal Solar Math

    /// Julian noon for the calendar day of `date`, in the observer's longitude zone.
    private static func julianNoon(from date: Date, longitude: Double) -> Double {
        // Shift date to observer's local solar day
        let jd = julianDate(from: date)
        return floor(jd - longitude / 360.0) + 0.5 + longitude / 360.0
    }

    /// Refine solar noon using equation of time (one iteration is enough).
    private static func solarNoonJD(jd0: Double, longitude: Double) -> Double {
        let n  = jd0 - 2451545.0
        let l0 = mod360(280.46646 + 36000.76983 * (n / 36525))  // mean longitude
        let m  = mod360(357.52911 + 35999.05029 * (n / 36525))  // mean anomaly
        let mR = toRadians(m)

        let eot = -7.655 * sin(mR) + 9.873 * sin(2 * toRadians(l0) + mR) // minutes (approx)
        let eotDays = eot / (60 * 24)

        return jd0 - eotDays
    }

    /// Sun's apparent geocentric declination (degrees) and right ascension (degrees) for JD.
    private static func sunDeclinationAndRA(jd: Double) -> (declination: Double, ra: Double) {
        let n  = jd - 2451545.0
        let l0 = mod360(280.46646 + 36000.76983 * (n / 36525))
        let m  = mod360(357.52911 + 35999.05029 * (n / 36525))
        let mR = toRadians(m)

        // Equation of centre
        let c  = (1.9146 - 0.004817 * (n / 36525)) * sin(mR)
                 + 0.019993 * sin(2 * mR)
                 + 0.00029  * sin(3 * mR)

        let sunLon = mod360(l0 + c)           // apparent ecliptic longitude
        let e      = 23.439 - 0.0000004 * n   // obliquity of ecliptic

        let sinLon = sin(toRadians(sunLon))
        let dec    = toDegrees(asin(sin(toRadians(e)) * sinLon))
        let ra     = toDegrees(atan2(cos(toRadians(e)) * sinLon, cos(toRadians(sunLon))))

        return (dec, mod360(ra))
    }

    /// Local Sidereal Time in decimal hours for a given JD and longitude (degrees East).
    private static func localSiderealTime(jd: Double, longitude: Double) -> Double {
        let t   = (jd - 2451545.0) / 36525.0
        var gst = 280.46061837
                  + 360.98564736629 * (jd - 2451545.0)
                  + 0.000387933 * t * t
                  - t * t * t / 38710000.0
        gst = mod360(gst)
        let lst = mod360(gst + longitude) / 15.0
        return lst
    }

    // MARK: - Trig / Angle Utilities

    private static func toRadians(_ deg: Double) -> Double { deg * .pi / 180 }
    private static func toDegrees(_ rad: Double) -> Double { rad * 180 / .pi }
    private static func mod360(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
