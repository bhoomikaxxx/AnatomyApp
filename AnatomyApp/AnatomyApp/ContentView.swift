import SwiftUI

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var openingResult: OpenImmersiveSpaceAction.Result?

    var body: some View {
        VStack(spacing: 16) {
            Text("Interactive Heart")
                .font(.title)

            Text("Bring your index and middle fingertips together to rotate the heart.")
                .multilineTextAlignment(.center)

            if openingResult == .error {
                Button("Enter Anatomy Space") {
                    Task {
                        await enterAnatomySpace()
                    }
                }
            }
        }
        .padding(32)
        .task {
            guard openingResult == nil else { return }
            await enterAnatomySpace()
        }
    }

    private func enterAnatomySpace() async {
        let result = await openImmersiveSpace(id: "AnatomySpace")
        openingResult = result

        if result == .opened {
            dismissWindow(id: "Launcher")
        }
    }
}

#Preview {
    ContentView()
}
