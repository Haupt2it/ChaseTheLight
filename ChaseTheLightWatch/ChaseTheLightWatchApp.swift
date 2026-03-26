import SwiftUI

@main
struct ChaseTheLightWatchApp: App {
    @StateObject private var solarManager = WatchSolarManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(solarManager)
        }
    }
}
