import CoreAudio
import Foundation

enum OthersAudio: String {
    case off
    case quiet
    case mute
}

/// Mutes or ducks every output that exposes a control, then restores the previous values.
/// A small file remembers the previous state so a later launch can undo it if Flow quit mid-recording.
enum OutputSilence {
    private struct SavedControl: Codable {
        var uid: String
        var mute: UInt32?
        var volume: Float?
    }

    private static var holding = false
    private static var file: URL {
        SupportPaths.directory.appendingPathComponent("output-silence.json")
    }

    static func recover() {
        guard !SnapshotMode.isActive else { return }
        restoreFromDisk()
    }

    static func begin(_ mode: OthersAudio) {
        guard !SnapshotMode.isActive, mode != .off, !holding else { return }
        restoreFromDisk()
        let saved = capture(mode)
        guard !saved.isEmpty else { return }
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: file, options: .atomic)
        }
        for item in saved {
            guard let device = deviceID(for: item.uid) else { continue }
            switch mode {
            case .off:
                break
            case .mute:
                if let mute = item.mute, mute == 0 {
                    setMute(device, 1)
                } else if let volume = item.volume, volume > 0 {
                    setVolume(device, 0)
                }
            case .quiet:
                if let volume = item.volume, volume > 0.08 {
                    setVolume(device, max(0.08, volume * 0.22))
                }
            }
        }
        holding = true
    }

    static func end() {
        guard !SnapshotMode.isActive else { return }
        restoreFromDisk()
        holding = false
    }

    private static func restoreFromDisk() {
        guard let data = try? Data(contentsOf: file),
              let saved = try? JSONDecoder().decode([SavedControl].self, from: data) else { return }
        for item in saved {
            guard let device = deviceID(for: item.uid) else { continue }
            if let mute = item.mute {
                setMute(device, mute)
            } else if let volume = item.volume {
                setVolume(device, volume)
            }
        }
        try? FileManager.default.removeItem(at: file)
    }

    private static func capture(_ mode: OthersAudio) -> [SavedControl] {
        outputDevices().compactMap { device in
            guard let uid = deviceUID(device) else { return nil }
            switch mode {
            case .off:
                return nil
            case .quiet:
                if muteIsSettable(device), readMute(device) == 1 { return nil }
                guard volumeIsSettable(device), let volume = readVolume(device), volume > 0.08 else { return nil }
                return SavedControl(uid: uid, mute: nil, volume: volume)
            case .mute:
                if muteIsSettable(device), let mute = readMute(device) {
                    return SavedControl(uid: uid, mute: mute, volume: nil)
                }
                if volumeIsSettable(device), let volume = readVolume(device) {
                    return SavedControl(uid: uid, mute: nil, volume: volume)
                }
                return nil
            }
        }
    }

    private static func outputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.filter(hasOutput)
    }

    private static func hasOutput(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func deviceUID(_ device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func deviceID(for uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let cf = uid as CFString
        var found = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafePointer(to: cf) { pointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                UnsafeMutableRawPointer(mutating: pointer),
                &size,
                &found
            )
        }
        guard status == noErr, found != 0, found != kAudioObjectUnknown else { return nil }
        return found
    }

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func muteIsSettable(_ device: AudioDeviceID) -> Bool {
        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        AudioObjectIsPropertySettable(device, &address, &settable)
        return settable.boolValue
    }

    private static func volumeIsSettable(_ device: AudioDeviceID) -> Bool {
        var address = volumeAddress()
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        AudioObjectIsPropertySettable(device, &address, &settable)
        return settable.boolValue
    }

    private static func readMute(_ device: AudioDeviceID) -> UInt32? {
        var address = muteAddress()
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func readVolume(_ device: AudioDeviceID) -> Float? {
        var address = volumeAddress()
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func setMute(_ device: AudioDeviceID, _ value: UInt32) {
        var address = muteAddress()
        var value = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }

    private static func setVolume(_ device: AudioDeviceID, _ value: Float) {
        var address = volumeAddress()
        var value = Float32(value)
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }
}
