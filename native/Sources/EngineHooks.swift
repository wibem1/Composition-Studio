import AppKit

final class EngineHooks: NSObject {
    static let shared = EngineHooks()
    private var timer: Timer?
    private weak var playButton: NSButton?
    private weak var timeLabel: NSTextField?
    private weak var statusLabel: NSTextField?

    private override init() { super.init() }

    func install() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidLaunch), name: NSApplication.didFinishLaunchingNotification, object: nil)
    }

    @objc private func applicationDidLaunch() {
        DispatchQueue.main.async { [weak self] in
            self?.connectUI()
        }
    }

    private func connectUI() {
        let engine = CompositionStudioEngine.shared
        let ok = engine.initialize()

        guard let window = NSApp.windows.first, let root = window.contentView else { return }
        let views = flatten(root)
        let buttons = views.compactMap { $0 as? NSButton }
        let labels = views.compactMap { $0 as? NSTextField }

        if let play = buttons.first(where: { $0.title == "▶" || $0.title == "❚❚" }) {
            play.target = self
            play.action = #selector(playPause)
            playButton = play
        }
        if let stop = buttons.first(where: { $0.title == "■" }) {
            stop.target = self
            stop.action = #selector(stop)
        }
        if let record = buttons.first(where: { $0.title == "●" }) {
            record.target = self
            record.action = #selector(record)
        }

        timeLabel = labels.first(where: { $0.stringValue == "00:00.000" })
        statusLabel = labels.first(where: { $0.stringValue == "Gespeichert" })

        if let pluginLabel = labels.first(where: { $0.stringValue == "Plugins" }) {
            pluginLabel.stringValue = ok ? "Plugins (\(engine.pluginCount))" : "Plugins"
        }
        statusLabel?.stringValue = ok ? "Audio-Engine bereit" : "Audio-Engine Fehler"

        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(refreshTransport), userInfo: nil, repeats: true)
        refreshTransport()
    }

    private func flatten(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { flatten($0) }
    }

    @objc private func playPause() {
        let engine = CompositionStudioEngine.shared
        if engine.isPlaying { engine.pause() } else { engine.play() }
        refreshTransport()
    }

    @objc private func stop() {
        let engine = CompositionStudioEngine.shared
        engine.stop()
        engine.locate(seconds: 0)
        refreshTransport()
    }

    @objc private func record() {
        CompositionStudioEngine.shared.record()
        refreshTransport()
    }

    @objc private func refreshTransport() {
        let engine = CompositionStudioEngine.shared
        guard engine.isReady else { return }
        playButton?.title = engine.isPlaying ? "❚❚" : "▶"
        statusLabel?.stringValue = engine.isRecording ? "Aufnahme" : (engine.isPlaying ? "Wiedergabe" : "Bereit")
        let elapsed = max(0, engine.positionSeconds)
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        let ms = Int((elapsed - floor(elapsed)) * 1000)
        timeLabel?.stringValue = String(format: "%02d:%02d.%03d", m, s, ms)
    }
}

func installCompositionStudioEngineHooks() {
    EngineHooks.shared.install()
}
