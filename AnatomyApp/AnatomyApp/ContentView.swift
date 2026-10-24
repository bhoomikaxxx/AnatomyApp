import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Binding var page: LauncherPage
    let chatContext: TimelineChatContext
    @State private var isOpeningExploration = false
    @State private var isShowingComingSoon = false
    @State private var comingSoonTitle = ""
    @State private var isShowingLaunchError = false
    @State private var selectedTimelinePoint = 0.0
    @State private var crossSectionPercentage = 100.0
    @State private var timelineScale = 1.0
    @State private var timelineRotationRadians = 0.0
    @State private var timelineRotationStartRadians: Double?
    @State private var isTimelineModelExploded = false
    @State private var selectedTimelinePartName: String?

    private let timelineStages = [
        TimelineStage(
            age: "18 days",
            description: "The cardiogenic area forms near the head end of the embryo. Cardiac precursor cells begin organising, and primitive blood vessels start developing around the embryo.",
            assetName: "stage 0 - 18 days"
        ),
        TimelineStage(
            age: "19 days",
            description: "The cardiogenic cells continue organising into paired endocardial tubes as the early cardiovascular system develops.",
            assetName: nil
        ),
        TimelineStage(
            age: "20 days",
            description: "Two endocardial tubes form on either side of the embryo. Early blood flow begins through these paired tubes as the cardiovascular system starts functioning.",
            assetName: "newd20CrossSection"
        ),
        TimelineStage(
            age: "21 days",
            description: "Embryonic folding brings the two endocardial tubes together, and they begin fusing into a single primitive heart tube along the midline.",
            assetName: "stage 2 - 21 days"
        ),
        TimelineStage(
            age: "22 days",
            description: "The primitive heart tube is established. Distinct regions such as the truncus arteriosus, bulbus cordis, primitive ventricle, and primitive atrium can be identified, and the heart is already contracting.",
            assetName: "stage 3 - 22 days"
        ),
        TimelineStage(
            age: "23 days",
            description: "The heart tube starts cardiac looping. The ventricular region moves forward and to the right, while the atrial region begins shifting backward and upward.",
            assetName: "stage 4 - 23 days"
        ),
        TimelineStage(
            age: "24 days",
            description: "Looping becomes more pronounced, giving the heart a curved, S-like shape. The primitive ventricle enlarges and the atrial and sinus venosus regions become more clearly positioned.",
            assetName: "stage 5 - 24 days"
        ),
        TimelineStage(
            age: "28 days",
            description: "Septation begins. The septum primum starts dividing the atria, the interventricular septum grows upward between the ventricles, and the endocardial cushions help divide the atrioventricular canal.",
            assetName: "stage 5.5 - 28 days"
        ),
        TimelineStage(
            age: "35 days",
            description: "The heart has a much more recognisable shape. The right and left atrial regions are distinct, the ventricles are enlarged, and the outflow tract connects with the developing aortic arch arteries.",
            assetName: nil
        ),
        TimelineStage(
            age: "8 weeks",
            description: "The heart has a largely established four-chamber structure. The right and left atria and ventricles are separated, the tricuspid and mitral valves are forming, and the foramen ovale remains open for fetal circulation.",
            assetName: "stage 8 - 8 weeks"
        )
    ]

    private var selectedTimelineStage: TimelineStage {
        timelineStages[Int(selectedTimelinePoint)]
    }

    private func updateTimelineChatContext() {
        chatContext.selectedAge = selectedTimelineStage.age
        chatContext.developmentalDescription = selectedTimelineStage.description
    }

    private var timelineMagnificationRotationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if timelineRotationStartRadians == nil {
                    timelineRotationStartRadians = timelineRotationRadians
                }

                guard let timelineRotationStartRadians else { return }
                let turn = Double(value.magnification - 1) * 2 * Double.pi
                self.timelineRotationRadians = timelineRotationStartRadians + turn
            }
            .onEnded { _ in
                timelineRotationStartRadians = nil
            }
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
            timelineTopPanel

            HStack(spacing: 18) {
                crossSectionPanel

                Group {
                    if let assetName = selectedTimelineStage.assetName {
                        TimelineRealityModelView(
                            assetName: assetName,
                            crossSectionPercentage: crossSectionPercentage,
                            rotationRadians: timelineRotationRadians,
                            displayScale: Float(timelineScale),
                            isExploded: $isTimelineModelExploded,
                            selectedPartName: $selectedTimelinePartName
                        )
                        .gesture(timelineMagnificationRotationGesture)
                        .accessibilityLabel("Heart model at \(selectedTimelineStage.age)")
                        .accessibilityHint("Pinch with two fingers and adjust the pinch to rotate")
                    } else {
                        ContentUnavailableView(
                            "Yet to be added",
                            systemImage: "cube.transparent",
                            description: Text("The \(selectedTimelineStage.age) heart model is not available yet.")
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                explodePanel
            }
            .frame(height: 210)

            timelineBottomPanel
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .onAppear {
            updateTimelineChatContext()
            openWindow(id: "TimelineChat")
        }
        .onChange(of: selectedTimelinePoint) {
            isTimelineModelExploded = false
            selectedTimelinePartName = nil
            crossSectionPercentage = 100
            updateTimelineChatContext()
        }
        .onDisappear {
            dismissWindow(id: "TimelineChat")
        }
    }

    private var timelineTopPanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Timeline Guided Content")
                    .font(.largeTitle.bold())

                Text("Explore each stage of heart development")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Text("Scale")
                    .font(.headline)

                Slider(value: $timelineScale, in: 1...2.5)
                    .frame(maxWidth: 420)
                    .accessibilityLabel("Heart model scale")

                Text("\(timelineScale, format: .number.precision(.fractionLength(1)))×")
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .glassBackgroundEffect()
    }

    private var crossSectionPanel: some View {
        VStack(spacing: 10) {
            Text("Cross Section")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)

            Text(crossSectionPercentage / 100, format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit())

            VerticalCrossSectionSlider(value: $crossSectionPercentage)
                .frame(width: 44, height: 120)
        }
        .padding(16)
        .frame(width: 180)
        .glassBackgroundEffect()
    }

    @ViewBuilder
    private var explodePanel: some View {
        if selectedTimelineStage.assetName != nil {
            VStack(spacing: 12) {
                Text("Model")
                    .font(.headline)

                Button {
                    selectedTimelinePartName = nil
                    isTimelineModelExploded.toggle()
                } label: {
                    Label(
                        isTimelineModelExploded ? "Reassemble" : "Explode",
                        systemImage: isTimelineModelExploded
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint(
                    isTimelineModelExploded
                        ? "Returns all parts to the complete model"
                        : "Moves the model parts apart"
                )
            }
            .padding(16)
            .frame(width: 180)
            .glassBackgroundEffect()
        } else {
            Color.clear
                .frame(width: 180)
        }
    }

    private var timelineBottomPanel: some View {
        VStack(spacing: 12) {
            Text(selectedTimelineStage.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760)
                .contentTransition(.opacity)

            if isTimelineModelExploded {
                Text(selectedTimelinePartName ?? "Touch or click a part to identify it")
                    .font(.headline.bold())
                    .foregroundStyle(selectedTimelinePartName == nil ? .secondary : .primary)
                    .contentTransition(.opacity)
                    .accessibilityLabel("Selected heart part")
            }

            VStack(spacing: 8) {
                Slider(
                    value: $selectedTimelinePoint,
                    in: 0...Double(timelineStages.count - 1),
                    step: 1
                )
                .accessibilityLabel("Heart development stage")
                .accessibilityValue(selectedTimelineStage.age)

                HStack(spacing: 0) {
                    ForEach(timelineStages.indices, id: \.self) { index in
                        Text(timelineStages[index].age)
                            .font(.caption)
                            .fontWeight(index == Int(selectedTimelinePoint) ? .bold : .regular)
                            .foregroundStyle(
                                index == Int(selectedTimelinePoint)
                                    ? AnyShapeStyle(.tint)
                                    : AnyShapeStyle(.secondary)
                            )
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)

            Button("Back to Learning Experiences") {
                page = .contentMenu
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
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

private struct TimelineRealityModelView: View {
    let assetName: String
    let crossSectionPercentage: Double
    let rotationRadians: Double
    let displayScale: Float
    @Binding var isExploded: Bool
    @Binding var selectedPartName: String?

    @State private var modelCache: [String: CachedTimelineModel] = [:]
    @State private var cacheOrder: [String] = []
    @State private var isLoading = true
    @State private var loadError = false
    @State private var clippingContainer = Entity()
    @State private var modelContainer = Entity()

    private let targetDimension: Float = 0.18
    private let maximumCachedModels = 3

    var body: some View {
        ZStack {
            RealityView { content in
                clippingContainer.addChild(modelContainer)
                content.add(clippingContainer)
            } update: { _ in
                updatePresentation()
            }
            .realityViewLayoutBehavior(.centered)
            .modifier(
                TimelineCrossSectionFallback(
                    percentage: crossSectionPercentage
                )
            )

            if isLoading {
                ProgressView()
            } else if loadError {
                ContentUnavailableView(
                    "Unable to load model",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .simultaneousGesture(partSelectionGesture)
        .task(id: assetName) {
            await displayModel(named: assetName)
        }
        .onChange(of: isExploded) { _, newValue in
            if newValue {
                explodeModel()
            } else {
                reassembleModel()
            }
        }
    }

    @MainActor
    private func displayModel(named name: String) async {
        isLoading = true
        loadError = false
        isExploded = false
        selectedPartName = nil

        if let cachedModel = modelCache[name] {
            present(cachedModel)
            markAsRecentlyUsed(name)
            isLoading = false
            return
        }

        do {
            let resourceName = "bfore/\(name)"
            let loadedEntity = try await Entity(
                named: resourceName,
                in: realityKitContentBundle
            )
            let cachedModel = prepareForDisplay(loadedEntity)
            modelCache[name] = cachedModel
            markAsRecentlyUsed(name)
            trimCache(excluding: name)

            guard !Task.isCancelled else { return }
            present(cachedModel)
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadError = true
            isLoading = false
        }
    }

    @MainActor
    private func prepareForDisplay(_ entity: Entity) -> CachedTimelineModel {
        let root = Entity()
        root.addChild(entity)

        let originalBounds = entity.visualBounds(
            recursive: true,
            relativeTo: entity,
            excludeInactive: false
        )
        let largestExtent = max(
            originalBounds.extents.x,
            originalBounds.extents.y,
            originalBounds.extents.z
        )
        let uniformScale = largestExtent > 0
            ? targetDimension / largestExtent
            : 1

        entity.scale = SIMD3(repeating: uniformScale)
        entity.position = SIMD3(
            -originalBounds.center.x * uniformScale,
            -originalBounds.center.y * uniformScale,
            -originalBounds.min.z * uniformScale + 0.001
        )

        let parts = makeExplodableParts(from: entity)

        return CachedTimelineModel(entity: root, parts: parts)
    }

    @MainActor
    private func present(_ cachedModel: CachedTimelineModel) {
        for child in modelContainer.children {
            child.removeFromParent()
        }
        modelContainer.addChild(cachedModel.entity)
        updatePresentation()
    }

    @MainActor
    private func updatePresentation() {
        let interactiveRotation = simd_quatf(
            angle: Float(rotationRadians),
            axis: SIMD3<Float>(0, 1, 0)
        )
        modelContainer.orientation = interactiveRotation
        modelContainer.scale = SIMD3(repeating: displayScale)

        let visibleFraction = Float(crossSectionPercentage / 100)
        clippingContainer.isEnabled = visibleFraction > 0

        guard visibleFraction > 0 else { return }
        if #available(visionOS 27.0, *) {
            guard visibleFraction < 0.999 else {
                clippingContainer.components.remove(ClippingComponent.self)
                return
            }

            let displayedBounds = modelContainer.visualBounds(
                recursive: true,
                relativeTo: clippingContainer,
                excludeInactive: false
            )
            let clippedMaximumY = displayedBounds.min.y
                + displayedBounds.extents.y * visibleFraction
            var clipping = ClippingComponent(
                bounds: BoundingBox(
                    min: displayedBounds.min,
                    max: SIMD3(
                        displayedBounds.max.x,
                        clippedMaximumY,
                        displayedBounds.max.z
                    )
                )
            )
            clipping.shouldClipSelf = true
            clipping.shouldClipChildren = true
            clippingContainer.components.set(clipping)
        }
    }

    private var partSelectionGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard isExploded,
                      let part = currentModel?.parts.first(where: {
                          belongsToPart(value.entity, part: $0.entity)
                      }) else {
                    return
                }

                selectedPartName = anatomicalLabel(for: part.entity)
            }
    }

    private var currentModel: CachedTimelineModel? {
        modelCache[assetName]
    }

    private func makeExplodableParts(from root: Entity) -> [TimelineExplodablePart] {
        if assetName == "stage 1 - 20 days" {
            let tubeNames = [
                "Left_Heart_tube_and_blood_cells",
                "Right_Heart_tube_and_blood_cells"
            ]

            return tubeNames.enumerated().compactMap { index, name in
                guard let tube = root.findEntity(named: name) else { return nil }
                configureInteraction(for: tube)
                return TimelineExplodablePart(
                    entity: tube,
                    originalTransform: tube.transform,
                    offset: explosionOffset(for: tube, index: index)
                )
            }
        }

        var parts: [TimelineExplodablePart] = []

        func visit(_ entity: Entity) {
            if entity.components.has(ModelComponent.self) {
                entity.generateCollisionShapes(recursive: false)
                entity.components.set(InputTargetComponent())
                parts.append(
                    TimelineExplodablePart(
                        entity: entity,
                        originalTransform: entity.transform,
                        offset: explosionOffset(for: entity, index: parts.count)
                    )
                )
            }

            for child in entity.children {
                visit(child)
            }
        }

        visit(root)
        return parts
    }

    private func configureInteraction(for root: Entity) {
        root.generateCollisionShapes(recursive: true)

        func visit(_ entity: Entity) {
            if entity.components.has(ModelComponent.self) {
                entity.components.set(InputTargetComponent())
            }

            for child in entity.children {
                visit(child)
            }
        }

        visit(root)
    }

    private func explodeModel() {
        guard let currentModel else { return }
        selectedPartName = nil

        for part in currentModel.parts {
            part.entity.stopAllAnimations(recursive: false)
            var target = part.originalTransform
            target.translation += part.offset
            part.entity.components[Transform.self] = target
            part.entity.components.set(HoverEffectComponent())
        }

        updatePresentation()
    }

    private func reassembleModel() {
        guard let currentModel else { return }
        selectedPartName = nil

        for part in currentModel.parts {
            part.entity.stopAllAnimations(recursive: false)
            part.entity.components.remove(HoverEffectComponent.self)
            part.entity.components[Transform.self] = part.originalTransform
        }

        updatePresentation()
    }

    private func explosionOffset(for entity: Entity, index: Int) -> SIMD3<Float> {
        let center = entity.visualBounds(
            recursive: true,
            relativeTo: entity.parent,
            excludeInactive: false
        ).center
        let horizontal = SIMD3<Float>(center.x, center.y * 0.35, center.z)

        if simd_length_squared(horizontal) > 0.000_001 {
            return simd_normalize(horizontal) * 0.45
        }

        let angle = Float(index) * 2.399_963
        return SIMD3(cos(angle), sin(angle) * 0.35, sin(angle)) * 0.45
    }

    private func anatomicalLabel(for entity: Entity) -> String {
        let tag = entity.name.isEmpty ? entity.parent?.name ?? "Heart Structure" : entity.name
        return tag
            .replacingOccurrences(of: "_GEO", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.first.map { String($0).uppercased() + word.dropFirst() } ?? ""
            }
            .joined(separator: " ")
    }

    private func belongsToPart(_ entity: Entity, part: Entity) -> Bool {
        var candidate: Entity? = entity

        while let current = candidate {
            if current === part {
                return true
            }
            candidate = current.parent
        }

        return false
    }

    @MainActor
    private func markAsRecentlyUsed(_ name: String) {
        cacheOrder.removeAll { $0 == name }
        cacheOrder.append(name)
    }

    @MainActor
    private func trimCache(excluding activeName: String) {
        while cacheOrder.count > maximumCachedModels {
            let nameToRemove = cacheOrder.removeFirst()
            guard nameToRemove != activeName else { continue }
            modelCache[nameToRemove]?.entity.removeFromParent()
            modelCache[nameToRemove] = nil
        }
    }
}

private struct VerticalCrossSectionSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = max(geometry.size.height - 20, 1)
            let fraction = value / 100

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.secondary.opacity(0.25))
                    .frame(width: 8, height: trackHeight)

                Capsule()
                    .fill(.tint)
                    .frame(width: 8, height: trackHeight * fraction)

                Circle()
                    .fill(.white)
                    .stroke(.tint, lineWidth: 3)
                    .frame(width: 24, height: 24)
                    .offset(y: -trackHeight * fraction + 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let position = min(
                            max(drag.location.y - 10, 0),
                            trackHeight
                        )
                        value = (1 - position / trackHeight) * 100
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Cross section")
        .accessibilityValue("\(Int(value)) percent visible")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 1, 100)
            case .decrement:
                value = max(value - 1, 0)
            @unknown default:
                break
            }
        }
    }
}

private struct TimelineCrossSectionFallback: ViewModifier {
    let percentage: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(visionOS 27.0, *) {
            content
        } else if percentage >= 99.9 {
            content
        } else {
            content.mask(alignment: .bottom) {
                GeometryReader { geometry in
                    Rectangle()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height * percentage / 100
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

private struct CachedTimelineModel {
    let entity: Entity
    let parts: [TimelineExplodablePart]
}

private struct TimelineExplodablePart {
    let entity: Entity
    let originalTransform: Transform
    let offset: SIMD3<Float>
}

private struct TimelineStage {
    let age: String
    let description: String
    let assetName: String?
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
    ContentView(
        page: .constant(.welcome),
        chatContext: TimelineChatContext()
    )
}
