import AppKit

final class EngineHooks: NSObject {
    static let shared = EngineHooks()
    private var timer: Timer?
    private weak var controller: StudioViewController?

    private override init() { super.init() }

    func install() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidLaunch),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc private func applicationDidLaunch() {
        DispatchQueue.main.async { [weak self] in self?.connectUI() }
    }

    private func connectUI() {
        let engine = CompositionStudioEngine.shared
        let ok = engine.initialize()
        guard let vc = NSApp.windows.first?.contentViewController as? StudioViewController else { return }
        controller = vc
        vc.installEngineBindings(engineReady: ok)
        vc.installV071FunctionalBindings()
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(refreshTransport), userInfo: nil, repeats: true)
        refreshTransport()
    }

    @objc private func refreshTransport() {
        controller?.refreshEngineUI()
        controller?.refreshV071FunctionalUI()
    }
}

func installCompositionStudioEngineHooks() { EngineHooks.shared.install() }
