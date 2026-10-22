import SwiftUI
import Foundation

struct GeminiChatView: View {
    let selectedAge: String
    let developmentalContext: String

    @State private var messages: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            text: "Ask me anything about the anatomy topic you are viewing."
        )
    ]
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var speechTranscriber = SpeechTranscriber()
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ask Gemini", systemImage: "sparkles")
                .font(.title2.bold())

            Text("Questions about \(selectedAge)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Thinking…")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                .onChange(of: messages.count) {
                    guard let lastMessage = messages.last else { return }
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            if let displayedError = errorMessage ?? speechTranscriber.errorMessage {
                Text(displayedError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    Task {
                        await speechTranscriber.toggleRecording()
                    }
                } label: {
                    Image(systemName: speechTranscriber.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(speechTranscriber.isRecording ? .red : .primary)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    speechTranscriber.isRecording ? "Stop dictation" : "Start voice dictation"
                )

                TextField(
                    "Message Gemini",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($isComposerFocused)
                .submitLabel(.send)
                .onSubmit(sendMessage)

                Button("Send", systemImage: "arrow.up.circle.fill", action: sendMessage)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedDraft.isEmpty || isSending)
            }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .glassBackgroundEffect()
        .onChange(of: speechTranscriber.transcript) {
            draft = speechTranscriber.transcript
            isComposerFocused = true
        }
        .onChange(of: selectedAge) {
            messages = [
                ChatMessage(
                    role: .assistant,
                    text: "You’re now viewing \(selectedAge). What would you like explained?"
                )
            ]
            errorMessage = nil
            speechTranscriber.stopRecording()
        }
        .onDisappear {
            speechTranscriber.stopRecording()
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 36)
            }

            Text(message.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 250, alignment: message.role == .user ? .trailing : .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(.thinMaterial),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .assistant {
                Spacer(minLength: 36)
            }
        }
    }

    private func sendMessage() {
        let question = trimmedDraft
        guard !question.isEmpty, !isSending else { return }

        draft = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, text: question))
        isSending = true

        let conversation = messages
        let context = """
        The learner is viewing the anatomy topic “\(selectedAge)”.
        Reference description: \(developmentalContext)
        """

        Task {
            do {
                let answer = try await GeminiService.generateReply(
                    messages: conversation,
                    developmentalContext: context
                )
                messages.append(ChatMessage(role: .assistant, text: answer))
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

private struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

private enum GeminiService {
    private static let models = [
        "gemini-3.5-flash-lite",
        "gemini-3.8-flash"
    ]

    static func generateReply(
        messages: [ChatMessage],
        developmentalContext: String
    ) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
              !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let contents = messages.map { message in
            GeminiContent(
                role: message.role == .user ? "user" : "model",
                parts: [GeminiPart(text: message.text)]
            )
        }
        let requestBody = GeminiRequest(
            systemInstruction: GeminiContent(
                role: nil,
                parts: [
                    GeminiPart(
                        text: """
                        You are a concise, friendly embryology tutor in an educational anatomy app.
                        Explain concepts accurately in plain language. Focus on the selected anatomy topic
                        and related embryology only when helpful. Do not diagnose medical conditions.
                        \(developmentalContext)
                        """
                    )
                ]
            ),
            contents: contents
        )
        let encodedBody = try JSONEncoder().encode(requestBody)
        var lastAvailabilityError: GeminiError?

        for model in models {
            do {
                return try await requestReply(
                    model: model,
                    apiKey: apiKey,
                    encodedBody: encodedBody
                )
            } catch let error as GeminiError {
                guard case .modelUnavailable = error else { throw error }
                lastAvailabilityError = error
            }
        }

        throw lastAvailabilityError ?? GeminiError.emptyResponse
    }

    private static func requestReply(
        model: String,
        apiKey: String,
        encodedBody: Data
    ) async throws -> String {
        guard let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        ) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = encodedBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data)
            let message = apiError?.error.message ?? "Gemini returned HTTP \(httpResponse.statusCode)."

            if [404, 429, 503].contains(httpResponse.statusCode) {
                throw GeminiError.modelUnavailable(message)
            }

            throw GeminiError.requestFailed(message)
        }

        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let reply = decodedResponse.candidates?
            .first?
            .content
            .parts
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !reply.isEmpty else {
            throw GeminiError.emptyResponse
        }

        return reply
    }
}

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiAPIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

private enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case modelUnavailable(String)
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GEMINI_API_KEY is missing. Add it to the Run scheme’s environment variables."
        case .invalidURL:
            return "The Gemini service URL is invalid."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case .modelUnavailable:
            return "Gemini is temporarily busy. Please wait a moment and try again."
        case .requestFailed(let message):
            return message
        case .emptyResponse:
            return "Gemini returned no text. Please try another question."
        }
    }
}
