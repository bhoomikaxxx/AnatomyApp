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
    @State private var subscriptions: [EventSubscription] = []
    @FocusState private var answerFieldIsFocused: Bool

    var body: some View {
        RealityView { content, attachments in
            do {
                let heart = try await Entity(
                    named: "heart",
                    in: realityKitContentBundle
                )
                heart.position = [0, 1.25, -0.75]
                heart.scale = SIMD3(repeating: 4.5)

                let parts = makeClinicalParts(from: heart)
                for part in parts {
                    ManipulationComponent.configureEntity(part.entity)
                    part.entity.components.set(HoverEffectComponent())
                    part.entity.isEnabled = false
                }

                content.add(heart)

                if let header = attachments.entity(for: "ClinicalHeader") {
                    header.position = [0, 1.72, -0.75]
                    content.add(header)
                }

                if let panel = attachments.entity(for: "ClinicalPanel") {
                    panel.position = [0.74, 1.3, -0.75]
                    content.add(panel)
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

            Attachment(id: "ClinicalPanel") {
                clinicalPanel
            }
        }
        .onDisappear {
            subscriptions.removeAll()
        }
    }

    @ViewBuilder
    private var clinicalPanel: some View {
        VStack(spacing: 18) {
            switch phase {
            case .naming:
                namingPanel
            case .matching:
                matchingPanel
            case .complete:
                completionPanel
            }

            Button {
                returnToClinicalMenu()
            } label: {
                Label("Back to Clinical Cases", systemImage: "chevron.backward")
                    .frame(width: 300, height: 58)
            }
            .buttonStyle(.bordered)
        }
        .font(.title3)
        .padding(24)
        .glassBackgroundEffect()
    }

    private var namingPanel: some View {
        VStack(spacing: 16) {
            Text("Identify This Structure")
                .font(.title.bold())

            Text("Part \(min(currentPartIndex + 1, parts.count)) of \(parts.count)")
                .foregroundStyle(.secondary)

            Text(maskedPartName)
                .font(.system(size: 27, weight: .bold, design: .monospaced))
                .tracking(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            TextField("Type the anatomical name", text: $answer)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($answerFieldIsFocused)
                .frame(width: 380)
                .onSubmit(checkAnswer)

            if !feedback.isEmpty {
                Text(feedback)
                    .font(.headline)
                    .foregroundStyle(feedback == "Correct!" ? .green : .orange)
            }

            Button("Check Answer", action: checkAnswer)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        currentPartName.map { character in
            character == " " ? "   " : "_ "
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

        for (index, part) in parts.enumerated() {
            part.entity.isEnabled = true
            part.entity.stopAllAnimations(recursive: false)

            var scrambledTransform = part.originalTransform
            scrambledTransform.translation += scrambleOffset(at: index)
            part.entity.components[Transform.self] = scrambledTransform

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
            entity.position,
            part.originalTransform.translation
        )

        guard distance <= 0.1 else { return }

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
                        originalTransform: entity.transform
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

    private func scrambleOffset(at index: Int) -> SIMD3<Float> {
        let offsets: [SIMD3<Float>] = [
            [-0.42, 0.28, -0.18],
            [0.44, 0.24, 0.16],
            [-0.34, -0.24, 0.2],
            [0.36, -0.28, -0.18],
            [-0.18, 0.46, 0.22],
            [0.2, 0.48, -0.2],
            [-0.48, 0.02, -0.24],
            [0.5, 0.04, 0.24]
        ]
        return offsets[index % offsets.count]
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
}
