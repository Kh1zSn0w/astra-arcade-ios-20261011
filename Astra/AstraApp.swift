import SwiftUI
import SpriteKit
import AVFoundation
import UIKit

@main
struct AstraApp: App {
    var body: some Scene {
        WindowGroup {
            AstraGameView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct AstraGameView: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: UIScreen.main.bounds)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.isMultipleTouchEnabled = false
        view.backgroundColor = SKColor(red: 0.027, green: 0.062, blue: 0.11, alpha: 1)
        let scene = AstraScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

final class AstraAudio {
    static let shared = AstraAudio()
    private var effects: [String: [AVAudioPlayer]] = [:]
    private var loops: AVAudioPlayer?
    private var soundEnabled = UserDefaults.standard.object(forKey: "astra.audio") as? Bool ?? true
    private var feedbackEnabled = UserDefaults.standard.object(forKey: "astra.haptics") as? Bool ?? true
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in ["shoot", "hit", "explode", "pickup", "click", "bomb", "warning"] {
            guard let url = Bundle.main.url(forResource: effect, withExtension: "wav") else { continue }
            effects[effect] = (0..<4).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = effect == "shoot" ? 0.11 : 0.35
                player?.prepareToPlay()
                return player
            }
        }
        if let url = Bundle.main.url(forResource: "music", withExtension: "wav") {
            loops = try? AVAudioPlayer(contentsOf: url)
            loops?.numberOfLoops = -1
            loops?.volume = 0.19
            loops?.prepareToPlay()
        }
    }

    var isSoundOn: Bool { soundEnabled }
    var isHapticsOn: Bool { feedbackEnabled }

    func startMusic() {
        if soundEnabled, loops?.isPlaying == false { loops?.play() }
    }

    func toggleSound() -> Bool {
        soundEnabled.toggle()
        UserDefaults.standard.set(soundEnabled, forKey: "astra.audio")
        if soundEnabled { startMusic() } else { loops?.stop(); loops?.currentTime = 0 }
        return soundEnabled
    }

    func toggleHaptics() -> Bool {
        feedbackEnabled.toggle()
        UserDefaults.standard.set(feedbackEnabled, forKey: "astra.haptics")
        return feedbackEnabled
    }

    func play(_ name: String) {
        guard soundEnabled, let pool = effects[name] else { return }
        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        player.currentTime = 0
        player.play()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard feedbackEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
