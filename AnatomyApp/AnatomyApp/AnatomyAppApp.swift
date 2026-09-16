import SwiftUI

@main
struct AnatomyAppApp: App {
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup(id: "Launcher") {
            ContentView()
        }

        ImmersiveSpace(id: "AnatomySpace") {
            ImmersiveView()
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
