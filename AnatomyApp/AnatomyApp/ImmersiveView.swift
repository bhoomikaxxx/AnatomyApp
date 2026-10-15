import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Binding var launcherPage: LauncherPage
    @State private var heart: Entity?
    @State private var explodableParts: [ExplodablePart] = []
    @State private var isExploded = false
    @State private var selectedPartName: String?

    @State private var draggedEntity: Entity?
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var magnificationRotatedEntity: Entity?
    @State private var magnificationStartOrientation: simd_quatf?
    @State private var rotatedEntity: Entity?
    @State private var rotationStartOrientation: simd_quatf?
    @State private var scaleMultiplier = 1.0

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

                let parts = makeExplodableParts(from: heart)
                for part in parts {
                    ManipulationComponent.configureEntity(part.entity)
                    disableIndividualManipulation(for: part.entity)
                }

                content.add(heart)

                if let explodeControl = attachments.entity(
                    for: "ExplodeControl"
                ) {
                    explodeControl.position = [0.58, 1.3, -0.75]
                    explodeControl.scale = SIMD3(repeating: interfaceScale)
                    content.add(explodeControl)
                }

                if let header = attachments.entity(for: "HeartHeader") {
                    header.position = [0, 1.72, -0.75]
                    header.scale = SIMD3(repeating: interfaceScale)
                    content.add(header)
                }

                if let scaleControl = attachments.entity(for: "ScaleControl") {
                    scaleControl.position = [0, 0.62, -0.68]
                    scaleControl.scale = SIMD3(repeating: interfaceScale)
                    content.add(scaleControl)
                }

                self.heart = heart
                explodableParts = parts
            } catch {
                print("Unable to load heart.usdc: \(error)")
            }
        } attachments: {
            Attachment(id: "HeartHeader") {
                VStack(spacing: 6) {
                    Text("EXPLORATION CONTENT")
                        .font(.headline.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)

                    Text("Fully Formed Embryonic Heart")
                        .font(.system(size: 46, weight: .bold, design: .rounded))

                    if isExploded {
                        Divider()
                            .padding(.vertical, 6)

                        Text("SELECTED PART")
                            .font(.title3.weight(.bold))
                            .tracking(1.5)

                        Text(selectedPartName ?? "Look at a part and pinch to identify it")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                selectedPartName == nil ? .secondary : .primary
                            )
                    }
                }
                    .padding(.horizontal, 38)
                    .padding(.vertical, 22)
                    .glassBackgroundEffect()
            }

            Attachment(id: "ScaleControl") {
                scaleControl
            }

            Attachment(id: "ExplodeControl") {
                VStack(spacing: 18) {
                    if isExploded {
                        Button {
                            animateToExplodedLayout()
                        } label: {
                            Label(
                                "Reset Layout",
                                systemImage: "arrow.counterclockwise"
                            )
                            .frame(width: 280, height: 70)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint(
                            "Returns moved parts to their exploded positions"
                        )

                        Button {
                            reassembleHeart()
                        } label: {
                            Label(
                                "Reassemble",
                                systemImage: "arrow.down.right.and.arrow.up.left"
                            )
                            .frame(width: 280, height: 70)
                        }
                        .accessibilityHint(
                            "Returns all parts to the complete heart"
                        )
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            isExploded = true
                            selectedPartName = nil
                            animateToExplodedLayout()
                        } label: {
                            Label(
                                "Explode",
                                systemImage: "arrow.up.left.and.arrow.down.right"
                            )
                            .frame(width: 280, height: 70)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Moves the heart parts apart")
                    }

                    Button {
                        returnToHome()
                    } label: {
                        Label("Back to Home", systemImage: "house.fill")
                            .frame(width: 280, height: 70)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Closes exploration and returns to the home page")
                }
                .padding(22)
                .glassBackgroundEffect()
                .font(.title2.weight(.bold))
                .controlSize(.extraLarge)
            }

        }
        .gesture(moveGesture)
        .simultaneousGesture(magnificationRotationGesture)
        .simultaneousGesture(rotationGesture)
        .simultaneousGesture(partSelectionGesture)
    }

    private func returnToHome() {
        launcherPage = .contentMenu
        openWindow(id: "Launcher")

        Task {
            await dismissImmersiveSpace()
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let entityToMove = transformTarget(for: value.entity) else { return }
                guard let parent = entityToMove.parent else { return }

                if draggedEntity !== entityToMove {
                    entityToMove.stopAllAnimations(recursive: false)
                    draggedEntity = entityToMove
                    dragStartPosition = entityToMove.position
                }

                guard let dragStartPosition else { return }

                let translation = value.convert(
                    value.gestureValue.translation3D,
                    from: .local,
                    to: parent
                )

                entityToMove.position = dragStartPosition + translation
            }
            .onEnded { _ in
                draggedEntity = nil
                dragStartPosition = nil
            }
    }

    private var magnificationRotationGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let entityToRotate = transformTarget(for: value.entity) else { return }

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

    private var rotationGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let entityToRotate = transformTarget(for: value.entity) else { return }

                if rotatedEntity !== entityToRotate {
                    rotatedEntity = entityToRotate
                    rotationStartOrientation = entityToRotate.orientation
                }

                guard let rotationStartOrientation else { return }

                let rotation = value.gestureValue.rotation
                let axis = rotation.axis.vector
                let delta = simd_quatf(
                    angle: Float(rotation.angle.radians),
                    axis: SIMD3(Float(axis.x), Float(axis.y), Float(axis.z))
                )
                entityToRotate.orientation = simd_normalize(
                    delta * rotationStartOrientation
                )
            }
            .onEnded { _ in
                rotatedEntity = nil
                rotationStartOrientation = nil
            }
    }

    private var partSelectionGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard isExploded,
                      let part = explodableParts.first(where: {
                          value.entity === $0.entity
                      }) else {
                    return
                }

                selectedPartName = anatomicalLabel(for: part.entity)
            }
    }

    private func makeExplodableParts(from root: Entity) -> [ExplodablePart] {
        var parts: [ExplodablePart] = []

        func visit(_ entity: Entity) {
            if entity.components.has(ModelComponent.self) {
                parts.append(
                    ExplodablePart(
                        entity: entity,
                        originalTransform: entity.transform,
                        offset: explosionOffset(for: entity)
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

    private func anatomicalLabel(for entity: Entity) -> String {
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
            return "Heart Structure"
        }
    }

    private func explosionOffset(for entity: Entity) -> SIMD3<Float> {
        switch entity.parent?.name {
        case "polySurface3":
            return [1.28, 0, -0.32]
        case "polySurface4":
            return [-1.28, 0, 0.32]
        case "Mitral_Valve_GEO":
            return [-0.72, 0.44, -0.96]
        case "Tricuspid_Valve_GEO":
            return [0.84, -0.44, -0.96]
        case "Pulmonary_Semilunar_Valve_GEO":
            return [0.96, 1.08, 0.72]
        case "Aortice_Semilunar_Valve_GEO":
            return [-0.72, 1.20, 0.72]
        case "Heart_Exteror_Vains_1_GEO":
            return [-1.16, 1.04, 0]
        case "Heart_Exteror_Vains_2_GEO":
            return [1.16, 1.04, 0]
        default:
            return .zero
        }
    }

    private func animateToExplodedLayout() {
        for part in explodableParts {
            part.entity.stopAllAnimations(recursive: false)

            var target = part.originalTransform
            target.translation += part.offset
            part.entity.components[Transform.self] = target

            part.entity.components.set(HoverEffectComponent())
        }
    }

    private func disableIndividualManipulation(for entity: Entity) {
        entity.components.remove(ManipulationComponent.self)
        entity.components.remove(HoverEffectComponent.self)
    }

    private func reassembleHeart() {
        isExploded = false
        selectedPartName = nil

        for part in explodableParts {
            part.entity.stopAllAnimations(recursive: false)
            disableIndividualManipulation(for: part.entity)
            part.entity.components[Transform.self] = part.originalTransform
        }

    }

    private func transformTarget(for targetedEntity: Entity) -> Entity? {
        guard let heart, belongsToHeart(targetedEntity, heart: heart) else {
            return nil
        }

        guard isExploded else { return heart }

        return explodableParts.first(where: { part in
            belongsToHeart(targetedEntity, heart: part.entity)
        })?.entity
    }

    private func belongsToHeart(_ entity: Entity, heart: Entity) -> Bool {
        var current: Entity? = entity

        while let candidate = current {
            if candidate === heart {
                return true
            }
            current = candidate.parent
        }

        return false
    }
}

private struct ExplodablePart {
    let entity: Entity
    let originalTransform: Transform
    let offset: SIMD3<Float>
}
