import AVFoundation
import CoreAudio
import SwiftUI

private func makePlayer(assetName: String, fileTypeHint: String? = nil) -> AVAudioPlayer {
    guard let asset = NSDataAsset(name: assetName) else {
        fatalError("Missing audio asset: \(assetName)")
    }

    do {
        return try AVAudioPlayer(data: asset.data, fileTypeHint: fileTypeHint)
    } catch {
        fatalError("Error initializing player for asset \(assetName): \(error)")
    }
}

class TBPlayer: ObservableObject {
    private let rainVolumeMultiplier = 0.15
    private var externalAudioMonitor: DispatchSourceTimer?
    private var windupSound: AVAudioPlayer
    private var dingSound: AVAudioPlayer
    private var rainSound: AVAudioPlayer

    @Published private(set) var isRainEnabled = false
    @Published private(set) var isRainPlaying = false
    @Published private(set) var isRainAutoPaused = false

    @AppStorage("windupVolume") var windupVolume: Double = 1.0 {
        didSet {
            setVolume(windupSound, windupVolume)
        }
    }
    @AppStorage("dingVolume") var dingVolume: Double = 1.0 {
        didSet {
            setVolume(dingSound, dingVolume)
        }
    }
    @AppStorage("rainVolume") var rainVolume: Double = 1.0 {
        didSet {
            setRainVolume()
        }
    }

    private func setVolume(_ sound: AVAudioPlayer, _ volume: Double) {
        sound.setVolume(Float(volume), fadeDuration: 0)
    }

    private func setRainVolume() {
        /*
         The bundled rain track is much louder than the event sounds.
         Apply an app-level attenuation so the slider has a more usable range.
         */
        setVolume(rainSound, rainVolume * rainVolumeMultiplier)
    }

    init() {
        let wav = AVFileType.wav.rawValue
        windupSound = makePlayer(assetName: "windup", fileTypeHint: wav)
        dingSound = makePlayer(assetName: "ding", fileTypeHint: wav)
        rainSound = makePlayer(assetName: "rain")

        windupSound.prepareToPlay()
        dingSound.prepareToPlay()
        rainSound.numberOfLoops = -1
        rainSound.prepareToPlay()

        setVolume(windupSound, windupVolume)
        setVolume(dingSound, dingVolume)
        setRainVolume()
    }

    func playWindup() {
        windupSound.play()
    }

    func playDing() {
        dingSound.play()
    }

    func startRain() {
        guard !isRainEnabled else {
            return
        }
        isRainEnabled = true
        TBStatusItem.shared.setRainEnabled(true)
        startExternalAudioMonitor()
        refreshRainPlaybackForExternalAudio()
    }

    func stopRain() {
        guard isRainEnabled else {
            return
        }
        isRainEnabled = false
        isRainAutoPaused = false
        stopExternalAudioMonitor()
        stopRainPlayback(resetPosition: true)
        TBStatusItem.shared.setRainEnabled(false)
    }

    func toggleRain() {
        if isRainEnabled {
            stopRain()
        } else {
            startRain()
        }
    }

    private func startExternalAudioMonitor() {
        guard externalAudioMonitor == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.refreshRainPlaybackForExternalAudio()
        }
        externalAudioMonitor = timer
        timer.resume()
    }

    private func stopExternalAudioMonitor() {
        externalAudioMonitor?.cancel()
        externalAudioMonitor = nil
    }

    private func playRainPlayback() {
        guard !rainSound.isPlaying else {
            return
        }
        rainSound.play()
        isRainPlaying = true
    }

    private func stopRainPlayback(resetPosition: Bool) {
        if rainSound.isPlaying {
            rainSound.stop()
        }
        if resetPosition {
            rainSound.currentTime = 0
        }
        isRainPlaying = false
    }

    private func refreshRainPlaybackForExternalAudio() {
        guard isRainEnabled else {
            return
        }

        if isExternalAudioPlaying() {
            isRainAutoPaused = true
            stopRainPlayback(resetPosition: false)
        } else {
            isRainAutoPaused = false
            playRainPlayback()
        }
    }

    private func isExternalAudioPlaying() -> Bool {
        let ownPID = getpid()

        for processObject in audioObjectIDs(
            selector: kAudioHardwarePropertyProcessObjectList,
            objectID: AudioObjectID(kAudioObjectSystemObject)
        ) {
            guard let pid = audioProperty(
                selector: kAudioProcessPropertyPID,
                objectID: processObject,
                valueType: pid_t.self
            ), pid != ownPID else {
                continue
            }

            let isRunningOutput = audioProperty(
                selector: kAudioProcessPropertyIsRunningOutput,
                objectID: processObject,
                valueType: UInt32.self
            ) ?? 0
            if isRunningOutput != 0 {
                return true
            }
        }

        return false
    }

    private func audioObjectIDs(
        selector: AudioObjectPropertySelector,
        objectID: AudioObjectID,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else {
            return []
        }

        var values = Array(repeating: AudioObjectID(), count: count)
        guard AudioObjectGetPropertyData(objectID,
                                         &address,
                                         0,
                                         nil,
                                         &dataSize,
                                         &values) == noErr else {
            return []
        }
        return values
    }

    private func audioProperty<T>(
        selector: AudioObjectPropertySelector,
        objectID: AudioObjectID,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        valueType: T.Type
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<T>.size)
        var data = Data(count: MemoryLayout<T>.size)

        let status = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return kAudioHardwareUnspecifiedError
            }
            return AudioObjectGetPropertyData(objectID,
                                              &address,
                                              0,
                                              nil,
                                              &dataSize,
                                              baseAddress)
        }

        guard status == noErr else {
            return nil
        }

        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return nil
            }
            return baseAddress.assumingMemoryBound(to: T.self).pointee
        }
    }
}
