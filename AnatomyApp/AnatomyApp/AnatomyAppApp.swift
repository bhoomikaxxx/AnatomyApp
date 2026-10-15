import SwiftUI

@main
struct AnatomyAppApp: App {
    @State private var immersionStyle: ImmersionStyle = .mixed
    @State private var launcherPage: LauncherPage = .welcome

    var body: some Scene {
        WindowGroup(id: "Launcher") {
            ContentView(page: $launcherPage)
        }
        .windowStyle(.volumetric)

        ImmersiveSpace(id: "AnatomySpace") {
            ImmersiveView(launcherPage: $launcherPage)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)

        ImmersiveSpace(id: "ClinicalMixMatchSpace") {
            ClinicalMixMatchView(launcherPage: $launcherPage)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)

        ImmersiveSpace(id: "HeartDeformitySpace") {
            HeartDeformityView(launcherPage: $launcherPage)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
