import SwiftUI
import RealityKit
import RealityKitContent

struct HeartDeformityView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Binding var launcherPage: LauncherPage

    private let heartScale: Float = 3.2
    private let interfaceScale: Float = 0.7

    var body: some View {
        RealityView { content, attachments in
            do {
                let referenceHeart = try await makeHighlightedHeart()
                referenceHeart.position = [-0.43, 1.25, -0.8]
                referenceHeart.scale = SIMD3(repeating: heartScale)
                content.add(referenceHeart)

                let deformityHeart = try await makeHighlightedHeart()
                deformityHeart.position = [0.43, 1.25, -0.8]
                deformityHeart.scale = SIMD3(repeating: heartScale)
                content.add(deformityHeart)

                if let header = attachments.entity(for: "DeformityHeader") {
                    header.position = [0, 1.78, -0.8]
                    header.scale = SIMD3(repeating: interfaceScale)
                    content.add(header)
                }

                if let labels = attachments.entity(for: "HeartLabels") {
                    labels.position = [0, 0.72, -0.72]
                    labels.scale = SIMD3(repeating: interfaceScale)
                    content.add(labels)
                }
            } catch {
                print("Unable to load deformity comparison hearts: \(error)")
            }
        } attachments: {
            Attachment(id: "DeformityHeader") {
                VStack(spacing: 8) {
                    Text("HEART AND DEFORMITIES")
                        .font(.headline.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)

                    Text("Deformity")
                        .font(.system(size: 46, weight: .bold, design: .rounded))

                    Text("The same exterior structure is highlighted on both hearts.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
                .padding(.vertical, 22)
                .glassBackgroundEffect()
            }

            Attachment(id: "HeartLabels") {
                VStack(spacing: 18) {
                    HStack(spacing: 180) {
                        Text("Reference Heart")
                        Text("Deformity")
                    }
                    .font(.title2.bold())

                    Button {
                        returnToDeformities()
                    } label: {
                        Label("Back to Deformities", systemImage: "chevron.backward")
                            .frame(width: 300, height: 52)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(22)
                .glassBackgroundEffect()
            }
        }
    }

    private func makeHighlightedHeart() async throws -> Entity {
        let heart = try await Entity(
            named: "heart",
            in: realityKitContentBundle
        )

        if let exteriorPart = firstModelEntity(
            in: heart,
            withParentNamed: "polySurface3"
        ) {
            var highlightMaterial = PhysicallyBasedMaterial()
            highlightMaterial.baseColor = .init(tint: .cyan)
            highlightMaterial.roughness = 0.2
            highlightMaterial.metallic = 0.1
            highlightMaterial.emissiveColor = .init(color: .cyan)
            highlightMaterial.emissiveIntensity = 3
            exteriorPart.components[ModelComponent.self]?.materials = [highlightMaterial]
        }

        return heart
    }

    private func firstModelEntity(
        in root: Entity,
        withParentNamed parentName: String
    ) -> ModelEntity? {
        if root.parent?.name == parentName,
           let modelEntity = root as? ModelEntity {
            return modelEntity
        }

        for child in root.children {
            if let match = firstModelEntity(in: child, withParentNamed: parentName) {
                return match
            }
        }

        return nil
    }

    private func returnToDeformities() {
        launcherPage = .deformitiesMenu
        openWindow(id: "Launcher")

        Task {
            await dismissImmersiveSpace()
        }
    }
}
