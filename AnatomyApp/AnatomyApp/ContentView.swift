import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Binding var page: LauncherPage
    @State private var isOpeningExploration = false
    @State private var isShowingComingSoon = false
    @State private var comingSoonTitle = ""
    @State private var isShowingLaunchError = false
    @State private var selectedTimelinePoint = 0.0

    private let timelineStages = [
        TimelineStage(title: "Stage 0", age: "18 days", assetName: "stage 0 - 18 days"),
        TimelineStage(title: "Stage 1", age: "20 days", assetName: "stage 1 - 20 days"),
        TimelineStage(title: "Stage 2", age: "21 days", assetName: "stage 2 - 21 days"),
        TimelineStage(title: "Stage 3", age: "22 days", assetName: "stage 3 - 22 days"),
        TimelineStage(title: "Stage 4", age: "23 days", assetName: "stage 4 - 23 days"),
        TimelineStage(title: "Stage 5", age: "24 days", assetName: "stage 5 - 24 days"),
        TimelineStage(title: "Stage 5.5", age: "28 days", assetName: "stage 5.5 - 28 days"),
        TimelineStage(title: "Stage 6", age: "35 days", assetName: "stage 6 - 35 days"),
        TimelineStage(title: "Stage 7", age: "42 days", assetName: "stage 7 - 42 days"),
        TimelineStage(title: "Stage 8", age: "8 weeks", assetName: "stage 8 - 8 weeks")
    ]

    private var selectedTimelineStage: TimelineStage {
        timelineStages[Int(selectedTimelinePoint)]
    }

    var body: some View {
        Group {
            switch page {
            case .welcome:
                welcomeView
            case .contentMenu:
                contentMenu
            case .timeline:
                timelineView
            case .clinicalMenu:
                clinicalMenu
            case .mixMatchInstructions:
                mixMatchInstructions
            case .deformitiesMenu:
                deformitiesMenu
            }
        }
        .padding(36)
        .frame(minWidth: 900, minHeight: 560)
        .animation(.smooth, value: page)
        .alert(comingSoonTitle, isPresented: $isShowingComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This learning experience is coming soon.")
        }
        .alert("Unable to Open Exploration", isPresented: $isShowingLaunchError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }

    private var welcomeView: some View {
        HStack(spacing: 42) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Embryology Anatomy")
                    .font(.system(size: 52, weight: .bold, design: .rounded))

                Text("Explore how the human heart forms, develops, and functions.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    page = .contentMenu
                } label: {
                    Text("Start")
                        .frame(width: 260, height: 78)
                }
                .font(.system(size: 30, weight: .bold))
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .padding(.top, 8)
            }
            .frame(maxWidth: 410, alignment: .leading)

            Image("EmbryologyHeart")
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Anatomical model of a human heart")
                .frame(maxWidth: 390, maxHeight: 430)
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private var contentMenu: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Embryology Anatomy")
                    .font(.largeTitle.bold())

                Text("Choose your learning experience")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                contentButton(
                    title: "Timeline Guided Content",
                    description: "Follow heart development step by step.",
                    systemImage: "timeline.selection"
                ) {
                    page = .timeline
                }

                contentButton(
                    title: "Exploration Content",
                    description: "Move, rotate, scale, and explode the heart.",
                    systemImage: "view.3d"
                ) {
                    Task {
                        await enterAnatomySpace()
                    }
                }

                contentButton(
                    title: "Clinical Case",
                    description: "Apply anatomy knowledge to a patient case.",
                    systemImage: "stethoscope"
                ) {
                    page = .clinicalMenu
                }
            }

            Button("Back") {
                page = .welcome
            }
            .disabled(isOpeningExploration)
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private var timelineView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Timeline Guided Content")
                    .font(.largeTitle.bold())

                Text("Explore each stage of heart development")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Model3D(
                named: selectedTimelineStage.assetName,
                bundle: realityKitContentBundle
            ) { model in
                model
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .id(selectedTimelineStage.assetName)
            .frame(height: 190)
            .accessibilityLabel(
                "Heart model at \(selectedTimelineStage.title), \(selectedTimelineStage.age)"
            )

            Text("\(selectedTimelineStage.title) · \(selectedTimelineStage.age)")
                .font(.title.bold())
                .foregroundStyle(.tint)
                .contentTransition(.numericText())

            ScrollView(.horizontal) {
                VStack(spacing: 12) {
                    Slider(
                        value: $selectedTimelinePoint,
                        in: 0...Double(timelineStages.count - 1),
                        step: 1
                    )
                    .accessibilityLabel("Heart development stage")
                    .accessibilityValue(
                        "\(selectedTimelineStage.title), \(selectedTimelineStage.age)"
                    )

                    HStack(spacing: 0) {
                        ForEach(timelineStages.indices, id: \.self) { index in
                            VStack(spacing: 2) {
                                Text(timelineStages[index].title)
                                Text(timelineStages[index].age)
                            }
                            .font(.caption)
                            .fontWeight(index == Int(selectedTimelinePoint) ? .bold : .regular)
                            .foregroundStyle(index == Int(selectedTimelinePoint) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                        }
                    }
                }
                .frame(width: 1_000)
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.visible)

            Button("Back to Learning Experiences") {
                page = .contentMenu
            }
        }
        .padding(24)
        .glassBackgroundEffect()
    }

    private var clinicalMenu: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text("Clinical Case")
                    .font(.largeTitle.bold())

                Text("Choose an activity")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                contentButton(
                    title: "Mix & Match",
                    description: "Name each structure, then rebuild the heart.",
                    systemImage: "puzzlepiece.extension.fill"
                ) {
                    page = .mixMatchInstructions
                }

                contentButton(
                    title: "Heart and Deformities",
                    description: "Compare heart anatomy across different deformities.",
                    systemImage: "heart.text.square.fill"
                ) {
                    page = .deformitiesMenu
                }
            }

            Button("Back to Learning Experiences") {
                page = .contentMenu
            }
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private var deformitiesMenu: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text("Heart and Deformities")
                    .font(.largeTitle.bold())

                Text("Choose a deformity")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                deformityButton(number: "1") {
                    Task {
                        await enterDeformitySpace()
                    }
                }

                deformityButton(number: "2") {
                    showComingSoon(for: "Deformity 2")
                }

                deformityButton(number: "3") {
                    showComingSoon(for: "Deformity 3")
                }
            }

            Button("Back to Clinical Cases") {
                page = .clinicalMenu
            }
            .disabled(isOpeningExploration)
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private var mixMatchInstructions: some View {
        VStack(spacing: 26) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Mix & Match")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "Identify each heart structure by typing its name.",
                    systemImage: "keyboard"
                )
                Label(
                    "After every answer is correct, the parts will scramble.",
                    systemImage: "shuffle"
                )
                Label(
                    "Move each part near its correct location and it will snap into place.",
                    systemImage: "scope"
                )
            }
            .font(.title3)

            HStack(spacing: 18) {
                Button("Back") {
                    page = .clinicalMenu
                }
                .controlSize(.extraLarge)

                Button {
                    Task {
                        await enterMixMatchSpace()
                    }
                } label: {
                    Text("Begin Activity")
                        .frame(width: 220, height: 54)
                }
                .font(.title3.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .disabled(isOpeningExploration)
            }
        }
        .padding(42)
        .glassBackgroundEffect()
    }

    private func contentButton(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.leading)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .padding(24)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .hoverEffect()
        .disabled(isOpeningExploration)
    }

    private func deformityButton(
        number: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 170)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .hoverEffect()
        .disabled(isOpeningExploration)
        .accessibilityLabel(Text("Deformity ") + Text(number))
    }

    private func showComingSoon(for title: String) {
        comingSoonTitle = title
        isShowingComingSoon = true
    }

    private func enterAnatomySpace() async {
        guard !isOpeningExploration else { return }
        isOpeningExploration = true
        let result = await openImmersiveSpace(id: "AnatomySpace")
        isOpeningExploration = false

        if result == .opened {
            dismissWindow(id: "Launcher")
        } else {
            isShowingLaunchError = true
        }
    }

    private func enterDeformitySpace() async {
        guard !isOpeningExploration else { return }
        isOpeningExploration = true
        let result = await openImmersiveSpace(id: "HeartDeformitySpace")
        isOpeningExploration = false

        if result == .opened {
            dismissWindow(id: "Launcher")
        } else {
            isShowingLaunchError = true
        }
    }

    private func enterMixMatchSpace() async {
        guard !isOpeningExploration else { return }
        isOpeningExploration = true
        let result = await openImmersiveSpace(id: "ClinicalMixMatchSpace")
        isOpeningExploration = false

        if result == .opened {
            dismissWindow(id: "Launcher")
        } else {
            isShowingLaunchError = true
        }
    }
}

private struct TimelineStage {
    let title: String
    let age: String
    let assetName: String
}

enum LauncherPage {
    case welcome
    case contentMenu
    case timeline
    case clinicalMenu
    case mixMatchInstructions
    case deformitiesMenu
}

#Preview {
    ContentView(page: .constant(.welcome))
}
