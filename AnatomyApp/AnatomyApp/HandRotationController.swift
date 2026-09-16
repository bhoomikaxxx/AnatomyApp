import ARKit
import RealityKit
import simd

@MainActor
final class HandRotationController {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    private var trackingTask: Task<Void, Never>?
    private weak var entity: Entity?

    private var activeHand: HandAnchor.Chirality?
    private var startingHandOrientation: simd_quatf?
    private var startingEntityOrientation: simd_quatf?

    func start(rotating entity: Entity) {
        self.entity = entity
        trackingTask?.cancel()

        trackingTask = Task {
            guard HandTrackingProvider.isSupported else {
                print("Hand tracking is unavailable on this device.")
                return
            }

            do {
                try await session.run([handTracking])

                for await update in handTracking.anchorUpdates {
                    guard !Task.isCancelled else { return }
                    updateRotation(using: update.anchor)
                }
            } catch {
                print("Unable to start hand tracking: \(error)")
            }
        }
    }

    func stop() {
        trackingTask?.cancel()
        trackingTask = nil
        resetGesture()
        session.stop()
    }

    private func updateRotation(using hand: HandAnchor) {
        guard hand.isTracked,
              let handSkeleton = hand.handSkeleton,
              let handOrientation = fingerOrientation(
                hand: hand,
                skeleton: handSkeleton
              ),
              areRotationFingersTogether(
                hand: hand,
                skeleton: handSkeleton
              ) else {
            if activeHand == hand.chirality {
                resetGesture()
            }
            return
        }

        guard activeHand == nil || activeHand == hand.chirality else {
            return
        }

        guard let entity else { return }

        if activeHand == nil {
            activeHand = hand.chirality
            startingHandOrientation = handOrientation
            startingEntityOrientation = entity.orientation
            return
        }

        guard let startingHandOrientation,
              let startingEntityOrientation else {
            return
        }

        let handChange = handOrientation * startingHandOrientation.inverse
        entity.orientation = simd_normalize(
            handChange * startingEntityOrientation
        )
    }

    private func areRotationFingersTogether(
        hand: HandAnchor,
        skeleton: HandSkeleton
    ) -> Bool {
        guard let indexTip = worldPosition(
            of: .indexFingerTip,
            hand: hand,
            skeleton: skeleton
        ), let middleTip = worldPosition(
            of: .middleFingerTip,
            hand: hand,
            skeleton: skeleton
        ), let indexKnuckle = worldPosition(
            of: .indexFingerKnuckle,
            hand: hand,
            skeleton: skeleton
        ), let middleKnuckle = worldPosition(
            of: .middleFingerKnuckle,
            hand: hand,
            skeleton: skeleton
        ) else {
            return false
        }

        let fingertipsAreTogether = distance(indexTip, middleTip) < 0.025
        let indexIsExtended = distance(indexTip, indexKnuckle) > 0.055
        let middleIsExtended = distance(middleTip, middleKnuckle) > 0.06

        return fingertipsAreTogether && indexIsExtended && middleIsExtended
    }

    private func fingerOrientation(
        hand: HandAnchor,
        skeleton: HandSkeleton
    ) -> simd_quatf? {
        guard let indexTip = worldPosition(
            of: .indexFingerTip,
            hand: hand,
            skeleton: skeleton
        ), let middleTip = worldPosition(
            of: .middleFingerTip,
            hand: hand,
            skeleton: skeleton
        ), let indexKnuckle = worldPosition(
            of: .indexFingerKnuckle,
            hand: hand,
            skeleton: skeleton
        ), let middleKnuckle = worldPosition(
            of: .middleFingerKnuckle,
            hand: hand,
            skeleton: skeleton
        ) else {
            return nil
        }

        let knuckleCenter = (indexKnuckle + middleKnuckle) * 0.5
        let fingertipCenter = (indexTip + middleTip) * 0.5

        let fingerDirection = simd_normalize(fingertipCenter - knuckleCenter)
        let acrossFingers = simd_normalize(middleKnuckle - indexKnuckle)
        let palmNormal = simd_normalize(
            simd_cross(acrossFingers, fingerDirection)
        )
        let correctedAcross = simd_normalize(
            simd_cross(fingerDirection, palmNormal)
        )

        guard fingerDirection.allFinite,
              palmNormal.allFinite,
              correctedAcross.allFinite else {
            return nil
        }

        let basis = simd_float3x3(
            correctedAcross,
            fingerDirection,
            palmNormal
        )
        return simd_quatf(basis)
    }

    private func worldPosition(
        of jointName: HandSkeleton.JointName,
        hand: HandAnchor,
        skeleton: HandSkeleton
    ) -> SIMD3<Float>? {
        let joint = skeleton.joint(jointName)
        guard joint.isTracked else { return nil }

        let transform =
            hand.originFromAnchorTransform *
            joint.anchorFromJointTransform

        return SIMD3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    private func resetGesture() {
        activeHand = nil
        startingHandOrientation = nil
        startingEntityOrientation = nil
    }
}

private extension SIMD3 where Scalar == Float {
    var allFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
