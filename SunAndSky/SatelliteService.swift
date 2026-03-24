import Foundation
import UIKit
import Combine

// MARK: - SatelliteService

@MainActor
final class SatelliteService: ObservableObject {

    @Published private(set) var image:       UIImage?
    @Published private(set) var captureTime: Date?
    @Published private(set) var isLoading    = false
    @Published private(set) var fetchError:  String?

    private var refreshTask: Task<Void, Never>?
    private var imageURL = URL(string:
        "https://cdn.star.nesdis.noaa.gov/GOES16/ABI/CONUS/GEOCOLOR/latest.jpg")!

    /// Start (or restart) the fetch loop. Pass a URL to change the satellite region.
    func start(imageURL: URL? = nil) {
        if let url = imageURL { self.imageURL = url }
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetch()
                try? await Task.sleep(nanoseconds: 900_000_000_000) // 15 min
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Network

    private func fetch() async {
        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: imageURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let img = UIImage(data: data) else {
                fetchError = "Could not decode satellite image"; return
            }
            image = img

            // Try HTTP Last-Modified header for the true capture time
            if let http = response as? HTTPURLResponse,
               let raw  = http.value(forHTTPHeaderField: "Last-Modified") {
                let fmt = DateFormatter()
                fmt.locale     = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                captureTime = fmt.date(from: raw) ?? Date()
            } else {
                captureTime = Date()
            }
            fetchError = nil
        } catch {
            fetchError = error.localizedDescription
        }
    }
}

// MARK: - CONUS coordinate helpers

/// Approximate GOES-East CONUS domain bounds (for dot placement).
/// Uses a simple equirectangular approximation — accurate enough for a visual indicator.
enum CONUSProjection {
    // GOES-East CONUS sector bounding box
    static let west:  Double = -135.0
    static let east:  Double =  -60.0
    static let north: Double =   55.0
    static let south: Double =   15.0

    /// Returns normalised (0–1, 0–1) position for a given lat/lon within the CONUS frame.
    /// x increases left→right; y increases top→bottom (image coordinate space).
    static func fraction(latitude: Double, longitude: Double) -> CGPoint {
        let x = (longitude - west)  / (east  - west)
        let y = (north - latitude)  / (north - south)
        return CGPoint(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }
}
