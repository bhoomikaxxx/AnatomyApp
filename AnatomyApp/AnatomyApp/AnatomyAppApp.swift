import SwiftUI

@main
struct AnatomyAppApp: App {
    @State private var immersionStyle: ImmersionStyle = .mixed
    @State private var launcherPage: LauncherPage = .welcome
    @State private var timelineChatContext = TimelineChatContext()

    var body: some Scene {
        WindowGroup(id: "Launcher") {
            ContentView(
                page: $launcherPage,
                chatContext: timelineChatContext
            )
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1_000, height: 700, depth: 300)

        Window("AI Tutor", id: "TimelineChat") {
            GeminiChatView(
                selectedAge: timelineChatContext.selectedAge,
                developmentalContext: timelineChatContext.developmentalDescription
            )
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 520, height: 700, depth: 300)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { _, context in
            if let timelineWindow = context.windows.first(
                where: { $0.id == "Launcher" }
            ) {
                WindowPlacement(
                    .trailing(timelineWindow),
                    width: 520,
                    height: 700,
                    depth: 300
                )
            } else {
                WindowPlacement(width: 520, height: 700, depth: 300)
            }
        }

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
