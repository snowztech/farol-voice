import AVFoundation
import CoreAudio

public enum MicrophoneError: LocalizedError {
    case unavailable

    public var errorDescription: String? { "No microphone is available." }
}

/// The default input as 16 kHz mono. Make a new one per recording, so it follows the input the Mac is using now.
public final class Microphone {
    public init() {}

    /// Something has the default input open, which usually means a call. Only ask while this app isn't recording.
    public static var isInUse: Bool {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return false }
        var running = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    private let engine = AVAudioEngine()

    public func start(_ onSamples: @escaping ([Float]) -> Void) throws {
        let input = engine.inputNode.outputFormat(forBus: 0)
        guard input.sampleRate > 0,
              let output = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1),
              let converter = AVAudioConverter(from: input, to: output) else { throw MicrophoneError.unavailable }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: input) { buffer, _ in
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

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
