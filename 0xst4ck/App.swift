import SwiftUI

@main
struct ZerohStackApp: App {
    @StateObject private var ble = BLEManager()
    @StateObject private var log = LogStore()
    @StateObject private var discord = DiscordSink()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .environmentObject(log)
                .environmentObject(discord)
                .preferredColorScheme(.dark)
                .onAppear {
                    ble.attach(log: log)
                    log.attach(discord: discord)
                }
        }
    }
}
