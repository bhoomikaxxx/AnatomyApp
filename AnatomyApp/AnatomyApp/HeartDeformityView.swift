import SwiftUI
import RealityKit
import RealityKitContent

struct HeartDeformityView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Binding var launcherPage: LauncherPage
    @State private var modelLoadMessage: String? = "Loading heart models…"

    private let heartScale: Float = 0.28
    private let interfaceScale: Float = 0.58

    var body: some View {
        RealityView { content, attachments in
            addAttachment(
                named: "DeformityHeader",
                at: [-0.22, 1.35, -0.8],
                to: content,
                attachments: attachments
            )
            addAttachment(
                named: "NormalLabel",
                at: [-0.3, 1.29, -0.72],
                to: content,
                attachments: attachments
            )
            addAttachment(
                named: "DextrocardiaLabel",
                at: [-0.14, 1.29, -0.72],
                to: content,
                attachments: attachments
            )
            addAttachment(
                named: "DeformityDetails",
                at: [-0.22, 0.88, -0.72],
                to: content,
                attachments: attachments
            )
            addAttachment(
                named: "AITutor",
                at: [0.18, 1.08, -0.72],
                to: content,
                attachments: attachments
            )
            addAttachment(
                named: "ModelLoadStatus",
                at: [-0.22, 0.68, -0.72],
                to: content,
                attachments: attachments
            )

            var failedModels: [String] = []

            do {
                let normalHeart = try await Entity(
                    named: "normalDextocardia",
                    in: realityKitContentBundle
                )
                normalHeart.position = [-0.3, 0.98, -0.8]
                normalHeart.scale = SIMD3(repeating: heartScale)
                content.add(normalHeart)
            } catch {
                failedModels.append("normal heart")
                print("Unable to load normalDextocardia.usdz: \(error)")
            }

            do {
                let dextrocardiaHeart = try await Entity(
                    named: "Dextocardia",
                    in: realityKitContentBundle
                )
                dextrocardiaHeart.position = [-0.14, 0.98, -0.8]
                dextrocardiaHeart.scale = SIMD3(repeating: heartScale)
                content.add(dextrocardiaHeart)
            } catch {
                failedModels.append("dextrocardia heart")
                print("Unable to load Dextocardia.usdz: \(error)")
            }

            modelLoadMessage = failedModels.isEmpty
                ? nil
                : "Could not load the \(failedModels.joined(separator: " and "))."
        } attachments: {
            Attachment(id: "DeformityHeader") {
                VStack(spacing: 10) {
                    Text("HEART AND DEFORMITIES")
                        .font(.headline.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)

                    Text("Dextrocardia")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .glassBackgroundEffect()
            }

            Attachment(id: "NormalLabel") {
                modelLabel("Normal")
            }

            Attachment(id: "DextrocardiaLabel") {
                modelLabel("Dextrocardia")
            }

            Attachment(id: "DeformityDetails") {
                VStack(spacing: 14) {
                    Text(TimelineChatContext.dextrocardiaDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 720)

                    Divider()

                    Button {
                        returnToDeformities()
                    } label: {
                        Label("Back to Deformities", systemImage: "chevron.backward")
                            .frame(width: 260, height: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
                .glassBackgroundEffect()
            }

            Attachment(id: "AITutor") {
                GeminiChatView(
                    selectedAge: "Dextrocardia",
                    developmentalContext: TimelineChatContext.dextrocardiaDescription
                )
                .frame(width: 440, height: 600)
            }

            Attachment(id: "ModelLoadStatus") {
                if let modelLoadMessage {
                    Label(modelLoadMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassBackgroundEffect()
                }
            }
        }
    }

    private func modelLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title3.bold())
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .glassBackgroundEffect()
    }

    private func addAttachment(
        named name: String,
        at position: SIMD3<Float>,
        to content: RealityViewContent,
        attachments: RealityViewAttachments
    ) {
        guard let attachment = attachments.entity(for: name) else { return }
        attachment.position = position
        attachment.scale = SIMD3(repeating: interfaceScale)
        content.add(attachment)
    }

    private func returnToDeformities() {
        launcherPage = .deformitiesMenu
        openWindow(id: "Launcher")

        Task {
            await dismissImmersiveSpace()
        }
    }
}
