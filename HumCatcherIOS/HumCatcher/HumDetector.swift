import Foundation
import AVFoundation
import UserNotifications
import QuartzCore

final class HumDetector: ObservableObject {
    @Published var humSeconds: Double = 0
    @Published var pitchHz: Double = 0
    @Published var level: Double = 0          // 0..1 display level
    @Published var hearing = false
    @Published var listening = false
    @Published var alarming = false
    @Published var statusText = "idle"

    // settings (bound from UI)
    var triggerSeconds: Double = 3.0
    var sensitivity: Int = 4                  // 1..5

    private let holdMs = 600.0
    private let resetMs = 2500.0
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var beepBuffer: AVAudioPCMBuffer?
    private var lastTonal: Double = 0
    private var lastTime: Double = 0
    private var humMs: Double = 0
    private var alarmTimer: Timer?

    private let sensMap: [Int: (rms: Float, cl: Float)] = [
        1: (0.020, 0.95), 2: (0.012, 0.93), 3: (0.007, 0.91),
        4: (0.004, 0.88), 5: (0.002, 0.85)
    ]

    func start() {
        guard !listening else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            statusText = "audio session failed"
            return
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        makeBeepBuffer(sampleRate: format.sampleRate)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: beepBuffer?.format)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, sampleRate: Float(format.sampleRate))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)

        do {
            try engine.start()
            humMs = 0; lastTime = 0; lastTonal = 0
            DispatchQueue.main.async {
                self.listening = true
                self.statusText = "listening"
            }
        } catch {
            statusText = "mic failed to start"
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        stopAlarm(resume: false)
        listening = false
        humMs = 0; humSeconds = 0; level = 0; hearing = false
        statusText = "paused"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended && listening {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
    }

    // MARK: detection

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Float) {
        guard !alarming, let ch = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 512 else { return }

        var rms: Float = 0
        for i in 0..<n { rms += ch[i] * ch[i] }
        rms = sqrt(rms / Float(n))

        let s = sensMap[sensitivity] ?? sensMap[4]!
        let now = CACurrentMediaTime() * 1000.0
        if lastTime == 0 { lastTime = now }
        let dt = min(now - lastTime, 200)
        lastTime = now

        var pitch: Float = 0
        if rms >= s.rms {
            pitch = autocorrelate(ch, count: n, sampleRate: sampleRate, clarityMin: s.cl)
        }

        if pitch > 0 {
            lastTonal = now
            humMs += dt
        } else {
            let gap = now - lastTonal
            if gap > resetMs { humMs = 0 }
            else if gap > holdMs { humMs = max(0, humMs - dt) }
        }
        let target = triggerSeconds * 1000.0
        if humMs > target { humMs = target }

        let fired = humMs >= target
        let lvl = min(1.0, Double(sqrt(rms / 0.12)))
        let p = Double(pitch)
        let seconds = humMs / 1000.0
        DispatchQueue.main.async {
            self.level = lvl
            self.hearing = rms >= s.rms
            self.pitchHz = p
            self.humSeconds = seconds
            self.statusText = p > 0 ? "humming · \(Int(p)) Hz" : "listening"
            if fired { self.startAlarm() }
        }
    }

    /// Normalized autocorrelation, 65–600 Hz. Returns 0 if not tonal enough.
    private func autocorrelate(_ x: UnsafeMutablePointer<Float>, count n: Int,
                               sampleRate: Float, clarityMin: Float) -> Float {
        let maxLag = Int(sampleRate / 65), minLag = Int(sampleRate / 600)
        guard n > maxLag + 32 else { return 0 }
        let span = n - maxLag
        var e0: Float = 0
        for i in 0..<span { e0 += x[i] * x[i] }
        var bestLag = -1
        var bestCorr: Float = 0
        var lag = minLag
        while lag <= maxLag {
            var corr: Float = 0, e1: Float = 0
            for i in 0..<span {
                let b = x[i + lag]
                corr += x[i] * b
                e1 += b * b
            }
            let denom = sqrt(e0 * e1)
            let c = denom > 0 ? corr / denom : 0
            if c > bestCorr { bestCorr = c; bestLag = lag }
            lag += 1
        }
        if bestCorr < clarityMin || bestLag < 0 { return 0 }
        return sampleRate / Float(bestLag)
    }

    // MARK: alarm

    private func makeBeepBuffer(sampleRate: Double) {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let dur = 0.35
        let frames = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return }
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env = min(1.0, t / 0.02) * min(1.0, (dur - t) / 0.05)
            data[i] = Float(sin(2 * .pi * 880 * t) * 0.6 * env)
        }
        beepBuffer = buf
    }

    private func startAlarm() {
        guard !alarming else { return }
        alarming = true
        statusText = "you were humming"
        bumpCatches()
        playBeep()
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            self?.playBeep()
        }
        let content = UNMutableNotificationContent()
        content.title = "Hum Catcher"
        content.body = "You were humming — open to stop the alarm."
        content.sound = .defaultCritical
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func playBeep() {
        guard let buf = beepBuffer, engine.isRunning else { return }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buf, at: nil, options: [])
    }

    func stopAlarm(resume: Bool = true) {
        alarmTimer?.invalidate(); alarmTimer = nil
        player.stop()
        alarming = false
        humMs = 0; humSeconds = 0
        lastTime = 0; lastTonal = 0
        statusText = resume && listening ? "listening" : statusText
    }

    // MARK: daily count

    @Published var caughtToday: Int = HumDetector.readCatches()

    private static func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "hc-" + f.string(from: Date())
    }
    private static func readCatches() -> Int {
        UserDefaults.standard.integer(forKey: todayKey())
    }
    private func bumpCatches() {
        let k = HumDetector.todayKey()
        let v = UserDefaults.standard.integer(forKey: k) + 1
        UserDefaults.standard.set(v, forKey: k)
        caughtToday = v
    }
}
