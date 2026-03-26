import SwiftUI
import WidgetKit

// MARK: - Watch Complication
//
// NOTE: To activate these complications on the watch face, add a
// "Watch App Complication Extension" target in Xcode and move this file there.
// The views are ready to use once the Widget Extension target exists.

// MARK: - Timeline Entry

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let phaseName: String
    let phaseColor: Color
    let nextEventName: String
    let nextEventCountdown: String
    let isPro: Bool
}

// MARK: - Provider

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: .now, phaseName: "Golden Hour",
                               phaseColor: Color(hex: 0xC86420),
                               nextEventName: "Sunset", nextEventCountdown: "1h 22m",
                               isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }
}

// MARK: - Circular Complication View

struct WatchCircularComplicationView: View {
    let entry: WatchComplicationEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(entry.phaseColor.opacity(0.25))
            VStack(spacing: 1) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(entry.phaseColor)
                Text(entry.nextEventCountdown)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Rectangular Complication View

struct WatchRectangularComplicationView: View {
    let entry: WatchComplicationEntry

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(entry.phaseColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.phaseName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(entry.nextEventName) in \(entry.nextEventCountdown)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Widget configuration (activate in extension target)

struct WatchComplicationWidget: Widget {
    let kind = "WatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            WatchCircularComplicationView(entry: entry)
                .containerBackground(.black.opacity(0), for: .widget)
        }
        .configurationDisplayName("Chase the Light")
        .description("Next light event countdown")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
