import AVFoundation
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
    private var windupSound: AVAudioPlayer
    private var dingSound: AVAudioPlayer
    private var rainSound: AVAudioPlayer

    @Published private(set) var isRainPlaying = false

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
        guard !isRainPlaying else {
            return
        }
        rainSound.play()
        isRainPlaying = true
    }

    func stopRain() {
        guard isRainPlaying else {
            return
        }
        rainSound.stop()
        rainSound.currentTime = 0
        isRainPlaying = false
    }

    func toggleRain() {
        if isRainPlaying {
            stopRain()
        } else {
            startRain()
        }
    }
}
