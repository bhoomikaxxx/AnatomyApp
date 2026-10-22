import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechTranscriber {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledAudioTap = false

    func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }

        errorMessage = nil

        guard await requestPermissions() else {
            errorMessage = "Allow microphone and speech recognition access in Settings to use dictation."
            return
        }

        do {
            try startRecording()
        } catch {
            stopRecording()
            errorMessage = "Dictation could not start. Please try again."
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func requestPermissions() async -> Bool {
        let speechIsAuthorized = await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechIsAuthorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func startRecording() throws {
        stopRecording()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = [
            "cardiogenic",
            "endocardial",
            "truncus arteriosus",
            "bulbus cordis",
            "septum primum",
            "interventricular",
            "atrioventricular",
            "sinus venosus"
        ]
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: recordingFormat
        ) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasInstalledAudioTap = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) {
            [weak self] result, error in
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let recognitionFailed = error != nil

            Task { @MainActor [weak self] in
                guard let self else { return }

                if let transcription {
                    self.transcript = transcription
                }

                if isFinal || recognitionFailed {
                    self.stopRecording()
                    if recognitionFailed && transcription == nil {
                        self.errorMessage = "I couldn’t understand that. Please try speaking again."
                    }
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }
}

private enum SpeechTranscriberError: Error {
    case recognizerUnavailable
}
