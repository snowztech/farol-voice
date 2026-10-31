import AVFoundation

enum MicrophoneError: LocalizedError {
    case unavailable

    var errorDescription: String? { "No microphone is available." }
}

/// The default input as 16 kHz mono. Make a new one per recording, so it follows the input the Mac is using now.
final class Microphone {
    private let engine = AVAudioEngine()

    func start(_ onSamples: @escaping ([Float]) -> Void) throws {
        let input = engine.inputNode.outputFormat(forBus: 0)
        guard input.sampleRate > 0,
              let output = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1),
              let converter = AVAudioConverter(from: input, to: output) else { throw MicrophoneError.unavailable }

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: input) { buffer, _ in
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16000 / input.sampleRate) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return }
            var delivered = false
            converter.convert(to: converted, error: nil) { _, status in
                if delivered {
                    status.pointee = .noDataNow
                    return nil
                }
                delivered = true
                status.pointee = .haveData
                return buffer
            }
            guard let samples = converted.floatChannelData?[0], converted.frameLength > 0 else { return }
            onSamples(Array(UnsafeBufferPointer(start: samples, count: Int(converted.frameLength))))
        }
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
