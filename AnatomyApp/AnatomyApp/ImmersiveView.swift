import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @State private var rotationController = HandRotationController()
    @State private var heart: Entity?

    @State private var dragStartPosition: SIMD3<Float>?
    @State private var magnificationStartScale: SIMD3<Float>?

    var body: some View {
        RealityView { content in
            do {
                let heart = try await Entity(
                    named: "heart",
                    in: realityKitContentBundle
                )

                heart.position = [0, 1.25, -0.75]
                heart.scale = SIMD3(repeating: 3)

                ManipulationComponent.configureEntity(heart)
                content.add(heart)

                self.heart = heart
                rotationController.start(rotating: heart)
            } catch {
                print("Unable to load heart.usdc: \(error)")
            }
        }
        .gesture(moveGesture)
        .simultaneousGesture(scaleGesture)
        .onDisappear {
            rotationController.stop()
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard value.entity == heart,
                      let parent = value.entity.parent else {
                    return
                }

                if dragStartPosition == nil {
                    dragStartPosition = value.entity.position
                }

                guard let dragStartPosition else { return }

                let translation = value.convert(
                    value.gestureValue.translation3D,
                    from: .local,
                    to: parent
                )

                value.entity.position = dragStartPosition + translation
            }
            .onEnded { _ in
                dragStartPosition = nil
            }
    }

    private var scaleGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard value.entity == heart else { return }

                if magnificationStartScale == nil {
                    magnificationStartScale = value.entity.scale
                }

                guard let magnificationStartScale else { return }

                let factor = Float(value.gestureValue.magnification)
                let proposedScale = magnificationStartScale * factor
                let clampedScale = min(max(proposedScale.x, 0.75), 8)

                value.entity.scale = SIMD3(repeating: clampedScale)
            }
            .onEnded { _ in
                magnificationStartScale = nil
            }
    }
}
