import SwiftUI

@main
struct ZerohStackApp: App {
    @StateObject private var ble = BLEManager()
    @StateObject private var log = LogStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .environmentObject(log)
                .preferredColorScheme(.dark)
                .onAppear {
                    ble.attach(log: log)
                }
        }
    }
}
