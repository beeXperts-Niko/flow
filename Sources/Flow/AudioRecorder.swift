import AVFoundation
import Foundation

enum RecorderError: LocalizedError {
    case noInput
    case convert

    var errorDescription: String? {
        switch self {
        case .noInput: return L10n.s("audio.noInput")
        case .convert: return L10n.s("audio.convert")
        }
    }
}

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var pcm = Data()
    private var limitReached = false
    private(set) var isRecording = false
    var onLimit: (() -> Void)?
    var onLevel: ((CGFloat) -> Void)?

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )!
    }

    func start() throws {
        lock.lock()
        pcm.removeAll(keepingCapacity: true)
        limitReached = false
        lock.unlock()
        converter = nil

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.consume(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stop() -> Data? {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRecording = false
        lock.lock()
        let captured = pcm
        pcm.removeAll(keepingCapacity: false)
        lock.unlock()
        // Unter 0,25 Sekunden ist kein sinnvolles Diktat.
        guard captured.count >= 8_000 else { return nil }
        return wavData(from: captured)
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        if converter == nil {
            guard buffer.format.sampleRate > 0 else { return }
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: max(capacity, 1)) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channels = output.int16ChannelData else { return }
        let frames = Int(output.frameLength)
        guard frames > 0 else { return }
        let byteCount = frames * MemoryLayout<Int16>.size
        let chunk = Data(bytes: channels[0], count: byteCount)

        var sum: Float = 0
        let samples = channels[0]
        for index in 0..<frames {
            let sample = Float(samples[index]) / 32768
            sum += sample * sample
        }
        let rms = (sum / Float(frames)).squareRoot()
        let decibels = 20 * log10(max(rms, 1e-6))
        let level = CGFloat(max(0, min(1, (decibels + 55) / 45)))
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }

        lock.lock()
        pcm.append(chunk)
        let tooLong = pcm.count > 9_600_000
        let shouldNotify = tooLong && !limitReached
        if shouldNotify { limitReached = true }
        lock.unlock()
        if shouldNotify {
            DispatchQueue.main.async { [weak self] in
                self?.onLimit?()
            }
        }
    }

    private func wavData(from pcm: Data) -> Data {
        var data = Data()
        let dataSize = UInt32(pcm.count)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        data.appendLE(UInt32(36) + dataSize)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(UInt32(16_000))
        data.appendLE(UInt32(32_000))
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        data.appendLE(dataSize)
        data.append(pcm)
        return data
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
