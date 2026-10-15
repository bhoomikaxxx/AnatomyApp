import SwiftUI
import RealityKit
import RealityKitContent

struct ClinicalMixMatchView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Binding var launcherPage: LauncherPage

    @State private var heart: Entity?
    @State private var parts: [ClinicalHeartPart] = []
    @State private var phase: ClinicalActivityPhase = .naming
    @State private var currentPartIndex = 0
    @State private var answer = ""
    @State private var feedback = ""
    @State private var matchedPartNames: Set<String> = []
    @State private var targetGuide: Entity?
    @State private var subscriptions: [EventSubscription] = []
    @State private var scaleMultiplier = 1.0
    @State private var magnificationRotatedEntity: Entity?
    @State private var magnificationStartOrientation: simd_quatf?
    @FocusState private var answerFieldIsFocused: Bool

    private let baseHeartScale: Float = 4.5
    private let interfaceScale: Float = 0.7

    var body: some View {
        RealityView { content, attachments in
            do {
                let heart = try await Entity(
                    named: "heart",
                    in: realityKitContentBundle
                )
                heart.position = [0, 1.25, -0.75]
                heart.scale = SIMD3(repeating: baseHeartScale)
                content.add(heart)

                let parts = makeClinicalParts(from: heart)
                let targetGuide = makeTargetGuide(for: heart)
                content.add(targetGuide)

                for part in parts {
                    ManipulationComponent.configureEntity(part.entity)
                    part.entity.components.set(HoverEffectComponent())
                    part.entity.isEnabled = false
                }

                if let header = attachments.entity(for: "ClinicalHeader") {
                    header.position = [0, 1.72, -0.75]
                    header.scale = SIMD3(repeating: interfaceScale)
                    content.add(header)
                }

                if let questionPanel = attachments.entity(for: "ClinicalQuestionPanel") {
                    questionPanel.position = [0.68, 1.24, -0.75]
                    questionPanel.scale = SIMD3(repeating: interfaceScale)
                    content.add(questionPanel)
                }

                if let actionPanel = attachments.entity(for: "ClinicalActionPanel") {
                    actionPanel.position = [0, 0.68, -0.68]
                    actionPanel.scale = SIMD3(repeating: interfaceScale)
                    content.add(actionPanel)
                }

                if let scaleControl = attachments.entity(for: "ScaleControl") {
                    scaleControl.position = [0, 0.38, -0.68]
                    scaleControl.scale = SIMD3(repeating: interfaceScale)
                    content.add(scaleControl)
                }

                let subscription = content.subscribe(
                    to: ManipulationEvents.WillEnd.self
                ) { event in
                    Task { @MainActor in
                        handleReleasedEntity(event.entity)
                    }
                }

                self.heart = heart
                self.parts = parts
                self.targetGuide = targetGuide
                subscriptions = [subscription]
                showCurrentNamingPart(in: parts)
            } catch {
                print("Unable to load clinical heart model: \(error)")
            }
        } attachments: {
            Attachment(id: "ClinicalHeader") {
                VStack(spacing: 6) {
                    Text("CLINICAL CASE")
                        .font(.headline.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)

                    Text("Heart Mix & Match")
                        .font(.system(size: 46, weight: .bold, design: .rounded))

                    Text(phaseSubtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 38)
                .padding(.vertical, 22)
                .glassBackgroundEffect()
            }

            Attachment(id: "ClinicalQuestionPanel") {
                clinicalQuestionPanel
            }

            Attachment(id: "ClinicalActionPanel") {
                clinicalActionPanel
            }

            Attachment(id: "ScaleControl") {
                scaleControl
            }
        }
        .simultaneousGesture(magnificationRotationGesture)
        .onDisappear {
            subscriptions.removeAll()
        }
    }

    private var scaleControl: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Scale")
                    .font(.title2.bold())

                Spacer()

                Text(scaleMultiplier, format: .number.precision(.fractionLength(1)))
                    .font(.title2.monospacedDigit().bold())
                + Text("×")
                    .font(.title2.bold())
            }

            Slider(value: $scaleMultiplier, in: 1...5)
                .frame(width: 420)
                .onChange(of: scaleMultiplier) { _, newValue in
                    heart?.scale = SIMD3(
                        repeating: baseHeartScale * Float(newValue)
                    )
                }

            HStack {
                Text("1×")
                Spacer()
                Text("5×")
            }
            .font(.headline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .glassBackgroundEffect()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Heart scale")
    }

    private var magnificationRotationGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let entityToRotate = clinicalTransformTarget(for: value.entity) else {
                    return
                }

                if magnificationRotatedEntity !== entityToRotate {
                    magnificationRotatedEntity = entityToRotate
                    magnificationStartOrientation = entityToRotate.orientation
                }

                guard let magnificationStartOrientation else { return }

                let turn = Float(value.gestureValue.magnification - 1) * 2 * .pi
                let delta = simd_quatf(angle: turn, axis: [0, 1, 0])
                entityToRotate.orientation = simd_normalize(
                    delta * magnificationStartOrientation
                )
            }
            .onEnded { _ in
                magnificationRotatedEntity = nil
                magnificationStartOrientation = nil
            }
    }

    private func clinicalTransformTarget(for targetedEntity: Entity) -> Entity? {
        parts.first { part in
            var current: Entity? = targetedEntity
            while let candidate = current {
                if candidate === part.entity {
                    return true
                }
                current = candidate.parent
            }
            return false
        }?.entity
    }

    @ViewBuilder
    private var clinicalQuestionPanel: some View {
        Group {
            switch phase {
            case .naming:
                namingPanel
            case .matching:
                matchingPanel
            case .complete:
                completionPanel
            }
        }
        .font(.title3)
        .padding(24)
        .glassBackgroundEffect()
    }

    @ViewBuilder
    private var clinicalActionPanel: some View {
        VStack(spacing: 16) {
            if phase == .naming {
                HStack(spacing: 24) {
                    Button(action: checkAnswer) {
                        Label("Answer", systemImage: "checkmark.circle.fill")
                            .frame(width: 340, height: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    Button(action: skipCurrentPart) {
                        Label("Skip", systemImage: "forward.end.fill")
                            .frame(width: 340, height: 100)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.system(size: 34, weight: .bold))
                .controlSize(.extraLarge)
            }

            Button {
                returnToClinicalMenu()
            } label: {
                Label("Back to Clinical Cases", systemImage: "chevron.backward")
                    .frame(width: 300, height: 52)
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .glassBackgroundEffect()
    }

    private var namingPanel: some View {
        VStack(spacing: 20) {
            Text("Identify This Structure")
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("Part \(min(currentPartIndex + 1, parts.count)) of \(parts.count)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(maskedPartName)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .tracking(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            TextField("Type the anatomical name", text: $answer)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($answerFieldIsFocused)
                .frame(width: 520, height: 64)
                .onSubmit(checkAnswer)

            if !feedback.isEmpty {
                Text(feedback)
                    .font(.headline)
                    .foregroundStyle(feedback == "Correct!" ? .green : .orange)
            }
        }
        .onAppear {
            answerFieldIsFocused = true
        }
    }

    private var matchingPanel: some View {
        VStack(spacing: 12) {
            Text("Rebuild the Heart")
                .font(.title.bold())

            Text("Move every part near its correct location. It will snap into place when close.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 380)

            Text("\(matchedPartNames.count) of \(parts.count) matched")
                .font(.title2.bold())
                .foregroundStyle(.tint)
        }
    }

    private var completionPanel: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text("Heart Reassembled!")
                .font(.title.bold())

            Text("You identified and matched all eight structures.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var currentPartName: String {
        guard parts.indices.contains(currentPartIndex) else { return "" }
        return parts[currentPartIndex].name
    }

    private var maskedPartName: String {
        let typedCharacters = answer.filter {
            $0.isLetter || $0.isNumber
        }
        var typedIterator = typedCharacters.makeIterator()

        return currentPartName.map { expectedCharacter in
            if expectedCharacter.isWhitespace {
                return "   "
            }

            if expectedCharacter.isLetter || expectedCharacter.isNumber {
                let displayedCharacter = typedIterator.next().map {
                    String($0).uppercased()
                } ?? "_"
                return "\(displayedCharacter) "
            }

            return "\(expectedCharacter) "
        }.joined()
    }

    private var phaseSubtitle: String {
        switch phase {
        case .naming:
            return "Name each anatomical structure"
        case .matching:
            return "Move the structures back into place"
        case .complete:
            return "Activity complete"
        }
    }

    private func checkAnswer() {
        guard normalize(answer) == normalize(currentPartName) else {
            feedback = "Try again"
            answerFieldIsFocused = true
            return
        }

        feedback = "Correct!"

        advanceToNextPart()
    }

    private func skipCurrentPart() {
        feedback = ""
        advanceToNextPart()
    }

    private func advanceToNextPart() {
        if currentPartIndex + 1 < parts.count {
            parts[currentPartIndex].entity.isEnabled = false
            currentPartIndex += 1
            parts[currentPartIndex].entity.isEnabled = true
            answer = ""
            feedback = ""
            answerFieldIsFocused = true
        } else {
            answerFieldIsFocused = false
            beginMatchingPhase()
        }
    }

    private func beginMatchingPhase() {
        phase = .matching
        answer = ""
        feedback = ""
        targetGuide?.isEnabled = true

        for (index, part) in parts.enumerated() {
            part.entity.isEnabled = true
            part.entity.stopAllAnimations(recursive: false)
            part.entity.components[Transform.self] = part.originalTransform
            part.entity.setPosition(
                part.originalWorldPosition + randomRoomOffset(
                    at: index,
                    count: parts.count
                ),
                relativeTo: nil
            )

            var manipulation = ManipulationComponent()
            manipulation.releaseBehavior = .stay
            part.entity.components.set(manipulation)
        }
    }

    private func handleReleasedEntity(_ entity: Entity) {
        guard phase == .matching,
              let part = parts.first(where: { $0.entity === entity }),
              !matchedPartNames.contains(part.name) else {
            return
        }

        let distance = simd_distance(
            entity.position(relativeTo: nil),
            part.originalWorldPosition
        )

        // World-space metres make this snap zone independent of model scale.
        guard distance <= 0.3 else { return }

        entity.components.remove(ManipulationComponent.self)
        entity.move(
            to: part.originalTransform,
            relativeTo: entity.parent,
            duration: 0.35,
            timingFunction: .easeInOut
        )
        matchedPartNames.insert(part.name)

        if matchedPartNames.count == parts.count {
            phase = .complete
            targetGuide?.isEnabled = false
        }
    }

    private func showCurrentNamingPart(in parts: [ClinicalHeartPart]) {
        guard let firstPart = parts.first else { return }
        firstPart.entity.isEnabled = true
    }

    private func makeClinicalParts(from root: Entity) -> [ClinicalHeartPart] {
        var parts: [ClinicalHeartPart] = []

        func visit(_ entity: Entity) {
            if entity.components.has(ModelComponent.self),
               let name = anatomicalName(for: entity) {
                parts.append(
                    ClinicalHeartPart(
                        name: name,
                        entity: entity,
                        originalTransform: entity.transform,
                        originalWorldPosition: entity.position(relativeTo: nil)
                    )
                )
            }

            for child in entity.children {
                visit(child)
            }
        }

        visit(root)
        return parts.sorted { $0.name < $1.name }
    }

    private func makeTargetGuide(for heart: Entity) -> Entity {
        let bounds = heart.visualBounds(
            recursive: true,
            relativeTo: nil,
            excludeInactive: false
        )
        let size = bounds.extents + SIMD3<Float>(repeating: 0.12)
        let thickness: Float = 0.018

        var edgeMaterial = UnlitMaterial(color: .cyan)
        edgeMaterial.blending = .transparent(
            opacity: .init(floatLiteral: 0.78)
        )

        var fillMaterial = UnlitMaterial(color: .cyan)
        fillMaterial.blending = .transparent(
            opacity: .init(floatLiteral: 0.035)
        )

        let guide = Entity()
        guide.name = "Heart Rebuild Target"
        guide.position = bounds.center
        guide.isEnabled = false

        let fill = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.035),
            materials: [fillMaterial]
        )
        guide.addChild(fill)

        func addEdge(size edgeSize: SIMD3<Float>, position: SIMD3<Float>) {
            let edge = ModelEntity(
                mesh: .generateBox(size: edgeSize, cornerRadius: thickness / 2),
                materials: [edgeMaterial]
            )
            edge.position = position
            guide.addChild(edge)
        }

        for ySign: Float in [-1, 1] {
            for zSign: Float in [-1, 1] {
                addEdge(
                    size: [size.x, thickness, thickness],
                    position: [
                        0,
                        ySign * size.y / 2,
                        zSign * size.z / 2
                    ]
                )
            }
        }

        for xSign: Float in [-1, 1] {
            for zSign: Float in [-1, 1] {
                addEdge(
                    size: [thickness, size.y, thickness],
                    position: [
                        xSign * size.x / 2,
                        0,
                        zSign * size.z / 2
                    ]
                )
            }
        }

        for xSign: Float in [-1, 1] {
            for ySign: Float in [-1, 1] {
                addEdge(
                    size: [thickness, thickness, size.z],
                    position: [
                        xSign * size.x / 2,
                        ySign * size.y / 2,
                        0
                    ]
                )
            }
        }

        return guide
    }

    private func anatomicalName(for entity: Entity) -> String? {
        switch entity.parent?.name {
        case "polySurface3":
            return "Exterior Heart Section A"
        case "polySurface4":
            return "Exterior Heart Section B"
        case "Mitral_Valve_GEO":
            return "Mitral Valve"
        case "Tricuspid_Valve_GEO":
            return "Tricuspid Valve"
        case "Pulmonary_Semilunar_Valve_GEO":
            return "Pulmonary Semilunar Valve"
        case "Aortice_Semilunar_Valve_GEO":
            return "Aortic Semilunar Valve"
        case "Heart_Exteror_Vains_1_GEO":
            return "Exterior Heart Vessels A"
        case "Heart_Exteror_Vains_2_GEO":
            return "Exterior Heart Vessels B"
        default:
            return nil
        }
    }

    private func randomRoomOffset(at index: Int, count: Int) -> SIMD3<Float> {
        let sectionAngle = (Float(index) / Float(max(count, 1))) * 2 * .pi
        let angle = sectionAngle + Float.random(in: -0.28...0.28)
        let radius = Float.random(in: 1.35...2.1)

        return [
            cos(angle) * radius,
            Float.random(in: -0.55...0.8),
            Float.random(in: -0.75...0.2)
        ]
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func returnToClinicalMenu() {
        launcherPage = .clinicalMenu
        openWindow(id: "Launcher")

        Task {
            await dismissImmersiveSpace()
        }
    }
}

private enum ClinicalActivityPhase {
    case naming
    case matching
    case complete
}

private struct ClinicalHeartPart {
    let name: String
    let entity: Entity
    let originalTransform: Transform
    let originalWorldPosition: SIMD3<Float>
}
