import SwiftUI
import UIKit
import CoreLocation

// MARK: - SatelliteCard

struct SatelliteCard: View {
    @EnvironmentObject private var settings: AppSettings

    let image:       UIImage?
    let captureTime: Date?
    let isLoading:   Bool
    let coordinate:  CLLocationCoordinate2D?
    let timeZone:    TimeZone?
    let placeName:   String

    @State private var isExpanded = false

    var body: some View {
        Button { isExpanded = true } label: { cardContent }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $isExpanded) {
                SatelliteFullScreen(image: image, captureTime: captureTime,
                                    coordinate: coordinate, timeZone: timeZone,
                                    placeName: placeName)
            }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x5BB8FF))
                Text("Live Satellite")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.75)
                } else if let t = captureTime {
                    Text(settings.timeString(t, timeZone: timeZone))
                        .font(.system(size: 15)).foregroundStyle(.white.opacity(0.60))
                }
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption).foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            // ── Thumbnail ─────────────────────────────────────────────
            thumbnailContent
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let img = image {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
                    .clipped()
                compassRose.padding(10)
            }
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
            .clipped()
        } else {
            placeholderView
        }
    }

    // MARK: Compass rose

    private var compassRose: some View {
        VStack(spacing: 1) {
            Text("N")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
            ZStack {
                Circle().stroke(.white.opacity(0.45), lineWidth: 1).frame(width: 20, height: 20)
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Helpers

    private var placeholderView: some View {
        Rectangle()
            .fill(Color(hex: 0x0A1628))
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
            .overlay {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "satellite")
                            .font(.title2).foregroundStyle(.white.opacity(0.4))
                        Text("Loading satellite image…")
                            .font(.system(size: 17)).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
    }
}

// MARK: - SatelliteFullScreen

private struct SatelliteFullScreen: View {
    @EnvironmentObject private var settings: AppSettings

    let image:       UIImage?
    let captureTime: Date?
    let coordinate:  CLLocationCoordinate2D?
    let timeZone:    TimeZone?
    let placeName:   String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let safeTop     = geo.safeAreaInsets.top
            let safeBottom  = geo.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                Color.black

                // ── Full CONUS zoomable image — edge to edge ───────────
                if image != nil {
                    ZoomableImageView(image: image, coordinate: coordinate,
                                      placeName: placeName)
                } else {
                    Color(hex: 0x0A1628)
                        .overlay {
                            VStack(spacing: 14) {
                                Image(systemName: "satellite")
                                    .font(.largeTitle).foregroundStyle(.white.opacity(0.4))
                                Text("No image available")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                }

                // ── Top bar — floats above image, clears notch ─────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Live Satellite")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        if let t = captureTime {
                            Text("Captured " + fmtCapture(t))
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    Spacer()
                    // Close button — minimum 50pt touch target
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.90))
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 20)
                .padding(.top, safeTop + 10)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)

                // ── Scale indicator (landscape only) ──────────────────
                if isLandscape {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(.white.opacity(0.75))
                                    .frame(width: 88, height: 2)
                                Text("≈ 500 mi")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.88))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 9))
                            .padding(.horizontal, 20)
                            .padding(.bottom, safeBottom + 12)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func fmtCapture(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        if let tz = timeZone { f.timeZone = tz }
        let datePart = f.string(from: date)
        let timePart = settings.timeString(date, timeZone: timeZone)
        return "\(datePart), \(timePart)"
    }
}

// MARK: - ZoomableImageView

private struct ZoomableImageView: UIViewRepresentable {
    let image:      UIImage?
    let coordinate: CLLocationCoordinate2D?
    let placeName:  String

    func makeUIView(context: Context) -> SatelliteScrollView { SatelliteScrollView() }

    func updateUIView(_ view: SatelliteScrollView, context: Context) {
        view.configure(image: image, coordinate: coordinate, placeName: placeName)
    }
}

// MARK: - SatelliteScrollView

private final class SatelliteScrollView: UIScrollView, UIScrollViewDelegate {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 8.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator   = false

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage?, coordinate: CLLocationCoordinate2D?, placeName: String) {
        imageView.image = image
        setZoomScale(minimumZoomScale, animated: false)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let img = imageView.image,
              bounds.width > 0, bounds.height > 0 else { return }

        guard abs(zoomScale - minimumZoomScale) < 0.001 else {
            centerImageView(); return
        }

        let scale = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let fw    = img.size.width  * scale
        let fh    = img.size.height * scale
        imageView.frame = CGRect(x: 0, y: 0, width: fw, height: fh)
        contentSize     = CGSize(width: fw, height: fh)
        centerImageView()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImageView() }

    private func centerImageView() {
        let cx = max((bounds.width  - imageView.frame.width)  / 2, 0)
        let cy = max((bounds.height - imageView.frame.height) / 2, 0)
        contentInset = UIEdgeInsets(top: cy, left: cx, bottom: cy, right: cx)
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let pt   = g.location(in: imageView)
            let rect = CGRect(x: pt.x - 60, y: pt.y - 60, width: 120, height: 120)
            zoom(to: rect, animated: true)
        }
    }
}
