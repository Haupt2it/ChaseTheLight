import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Status

enum LocationStatus {
    case idle
    case loading
    case authorized
    case denied
}

// MARK: - LocationManager

final class LocationManager: NSObject, ObservableObject {

    // MARK: Published

    @Published private(set) var status: LocationStatus = .idle
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var placeName: String = ""
    @Published private(set) var timeZone: TimeZone?

    // MARK: Private

    private let manager = CLLocationManager()

    // MARK: Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        print("[LocationManager] init — delegate set: \(manager.delegate != nil)")
    }

    // MARK: Public

    func requestLocation() {
        let auth = manager.authorizationStatus
        print("[LocationManager] requestLocation() called — authorizationStatus: \(auth.debugDescription)")
        switch auth {
        case .notDetermined:
            status = .loading
            print("[LocationManager] → requesting WhenInUse authorization")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .loading
            print("[LocationManager] → already authorized, calling requestLocation()")
            manager.requestLocation()
        case .denied, .restricted:
            print("[LocationManager] → denied/restricted, setting status .denied")
            status = .denied
        @unknown default:
            print("[LocationManager] → unknown auth status, setting status .denied")
            status = .denied
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        print("[LocationManager] locationManagerDidChangeAuthorization — new status: \(auth.debugDescription)")
        switch auth {
        case .authorizedWhenInUse, .authorizedAlways:
            status = .loading
            print("[LocationManager] → authorized, calling requestLocation()")
            manager.requestLocation()
        case .denied, .restricted:
            print("[LocationManager] → denied/restricted")
            status = .denied
        case .notDetermined:
            print("[LocationManager] → notDetermined")
            status = .idle
        @unknown default:
            print("[LocationManager] → unknown default")
            status = .idle
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("[LocationManager] didUpdateLocations — empty locations array")
            return
        }
        print("[LocationManager] didUpdateLocations — lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude), accuracy: \(location.horizontalAccuracy)m")
        coordinate = location.coordinate
        status = .authorized
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        print("[LocationManager] didFailWithError — \(error.localizedDescription) | CLError code: \(clError?.code.rawValue as Any)")
        if coordinate == nil {
            print("[LocationManager] → no prior coordinate, setting status .denied")
            status = .denied
        }
    }

    // MARK: - Geocoding

    private func reverseGeocode(_ location: CLLocation) {
        print("[LocationManager] reverseGeocode starting")
        Task {
            do {
                guard let req = MKReverseGeocodingRequest(location: location) else { return }
                let items = try await req.mapItems
                await MainActor.run {
                    if let item = items.first {
                        let city    = item.addressRepresentations?.cityName ?? ""
                        let country = item.addressRepresentations?.regionName ?? ""
                        self.placeName = [city, country]
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")
                        self.timeZone = item.timeZone as TimeZone?
                        print("[LocationManager] reverseGeocode → \(self.placeName)")
                    } else {
                        print("[LocationManager] reverseGeocode → no items returned")
                    }
                }
            } catch {
                print("[LocationManager] reverseGeocode error — \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Debug helpers

private extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined:       return "notDetermined"
        case .restricted:          return "restricted"
        case .denied:              return "denied"
        case .authorizedAlways:    return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default:          return "unknown(\(rawValue))"
        }
    }
}
