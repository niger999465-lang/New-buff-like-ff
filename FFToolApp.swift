import SwiftUI

@main
struct FFToolApp: App {
    init() { AutoLike.registerBackground() }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
