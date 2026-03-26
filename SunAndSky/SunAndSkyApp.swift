import SwiftUI

@main
struct SunAndSkyApp: App {
    @StateObject private var settings            = AppSettings()
    @StateObject private var proManager          = ProManager()
    @StateObject private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(proManager)
                .environmentObject(notificationManager)
        }
    }
}
