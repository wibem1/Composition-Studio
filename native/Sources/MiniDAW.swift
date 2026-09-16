import AppKit

@_silgen_name("cs_engine_initialize") func cs_engine_initialize() -> Bool
@_silgen_name("cs_engine_play") func cs_engine_play()
@_silgen_name("cs_engine_stop") func cs_engine_stop()
@_silgen_name("cs_engine_is_playing") func cs_engine_is_playing() -> Bool
@_silgen_name("cs_engine_position_seconds") func cs_engine_position_seconds() -> Double
@_silgen_name("cs_engine_locate_seconds") func cs_engine_locate_seconds(_ s: Double)
@_silgen_name("cs_plugin_count") func cs_plugin_count() -> Int32
@_silgen_name("cs_plugin_name_at") func cs_plugin_name_at(_ i: Int32, _ out: UnsafeMutablePointer<CChar>, _ cap: Int32) -> Bool
@_silgen_name("cs_plugin_is_instrument_at") func cs_plugin_is_instrument_at(_ i: Int32) -> Bool
@_silgen_name("cs_track_add_plugin_at") func cs_track_add_plugin_at(_ track: Int32, _ plugin: Int32) -> Int32
@_silgen_name("md_start_plugin_scan") func md_start_plugin_scan()
@_silgen_name("md_plugin_scan_running") func md_plugin_scan_running() -> Bool
@_silgen_name("md_create_test_session") func md_create_test_session() -> Int32
@_silgen_name("md_audio_thread_position") func md_audio_thread_position() -> Double
@_silgen_name("md_preview_note") func md_preview_note(_ track: Int32, _ note: Int32, _ on: Bool)
@_silgen_name("md_direct_audio_start") func md_direct_audio_start() -> Bool
@_silgen_name("md_direct_audio_stop") func md_direct_audio_stop()
@_silgen_name("md_direct_audio_test_tone") func md_direct_audio_test_tone(_ seconds: Double)
@_silgen_name("md_direct_audio_running") func md_direct_audio_running() -> Bool
@_silgen_name("md_direct_audio_callbacks") func md_direct_audio_callbacks() -> UInt64
@_silgen_name("md_direct_audio_sample_rate") func md_direct_audio_sample_rate() -> Double
@_silgen_name("md_direct_audio_buffer_size") func md_direct_audio_buffer_size() -> Int32
@_silgen_name("md_direct_audio_active_outputs") func md_direct_audio_active_outputs() -> Int32
@_silgen_name("md_direct_audio_peak") func md_direct_audio_peak() -> Double
@_silgen_name("md_direct_audio_energy") func md_direct_audio_energy() -> Double
@_silgen_name("md_direct_audio_device_name") func md_direct_audio_device_name(_ out: UnsafeMutablePointer<CChar>, _ cap: Int32) -> Bool
@_silgen_name("md_direct_audio_error") func md_direct_audio_error(_ out: UnsafeMutablePointer<CChar>, _ cap: Int32) -> Bool

final class PlayheadView: NSView {
    var seconds: Double = 0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill(); NSColor.separatorColor.setStroke()
        let line = NSBezierPath(); line.move(to: NSPoint(x: 20, y: bounds.midY)); line.line(to: NSPoint(x: bounds.width - 20, y: bounds.midY)); line.stroke()
        let x = 20 + CGFloat(min(max(seconds / 4.0, 0), 1)) * (bounds.width - 40); NSColor.systemRed.setStroke()
        let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: 12)); p.line(to: NSPoint(x: x, y: bounds.height - 12)); p.lineWidth = 3; p.stroke()
    }
}

final class MiniDAWController: NSViewController {
    let status = NSTextField(labelWithString: "Start …"), directStatus = NSTextField(labelWithString: "AudioDeviceCore: –"), engineStatus = NSTextField(labelWithString: "MAGDA Engine: –"), transportStatus = NSTextField(labelWithString: "Transport: –"), audioThreadStatus = NSTextField(labelWithString: "MAGDA Audio thread: –"), pluginStatus = NSTextField(labelWithString: "Plugin: –")
    let directStart = NSButton(title: "1  AudioDeviceCore öffnen", target: nil, action: nil), directTone = NSButton(title: "2  Direkten Testton", target: nil, action: nil), combo = NSComboBox(), scan = NSButton(title: "3  Plugins suchen", target: nil, action: nil), load = NSButton(title: "4  Instrument laden", target: nil, action: nil), preview = NSButton(title: "5  Plugin-Ton", target: nil, action: nil), play = NSButton(title: "6  Play", target: nil, action: nil), stop = NSButton(title: "Stop", target: nil, action: nil), head = PlayheadView()
    var instruments: [(Int, String)] = [], track: Int32 = -1, timer: Timer?
    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 520)) }
    override func viewDidLoad() {
        super.viewDidLoad(); let title = NSTextField(labelWithString: "MiniDAW – Funktionsnachweis"); title.font = .systemFont(ofSize: 24, weight: .bold)
        let explain = NSTextField(wrappingLabelWithString: "Zuerst wird CoreAudio/JUCE unabhängig von MAGDA geprüft. Erst danach folgen Spur, Plugin und Transport."); explain.textColor = .secondaryLabelColor
        [title, explain, status, directStatus, engineStatus, transportStatus, audioThreadStatus, pluginStatus, directStart, directTone, combo, scan, load, preview, play, stop, head].forEach { view.addSubview($0) }
        title.frame = NSRect(x: 24, y: 468, width: 700, height: 32); explain.frame = NSRect(x: 24, y: 428, width: 700, height: 34)
        directStart.frame = NSRect(x: 24, y: 382, width: 190, height: 30); directTone.frame = NSRect(x: 224, y: 382, width: 170, height: 30); directStatus.frame = NSRect(x: 410, y: 386, width: 326, height: 22)
        scan.frame = NSRect(x: 24, y: 334, width: 150, height: 30); combo.frame = NSRect(x: 184, y: 334, width: 300, height: 30); load.frame = NSRect(x: 494, y: 334, width: 170, height: 30)
        preview.frame = NSRect(x: 24, y: 289, width: 150, height: 30); play.frame = NSRect(x: 184, y: 289, width: 120, height: 30); stop.frame = NSRect(x: 314, y: 289, width: 100, height: 30)
        head.frame = NSRect(x: 24, y: 194, width: 712, height: 70); status.frame = NSRect(x: 24, y: 160, width: 712, height: 22); status.font = .systemFont(ofSize: 13, weight: .semibold)
        engineStatus.frame = NSRect(x: 24, y: 130, width: 330, height: 20); transportStatus.frame = NSRect(x: 370, y: 130, width: 366, height: 20); audioThreadStatus.frame = NSRect(x: 24, y: 102, width: 330, height: 20); pluginStatus.frame = NSRect(x: 370, y: 102, width: 366, height: 20)
        directStart.target = self; directStart.action = #selector(startDirect); directTone.target = self; directTone.action = #selector(toneDirect); scan.target = self; scan.action = #selector(scanPlugins); load.target = self; load.action = #selector(loadPlugin); preview.target = self; preview.action = #selector(previewNote); play.target = self; play.action = #selector(doPlay); stop.target = self; stop.action = #selector(doStop)
        let ok = cs_engine_initialize(); engineStatus.stringValue = "MAGDA Engine: \(ok ? "bereit" : "FEHLER")"; if ok { track = md_create_test_session() }; refreshPlugins(); timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }
    @objc func startDirect() { let ok = md_direct_audio_start(); status.stringValue = ok ? "AudioDeviceCore geöffnet – direkter JUCE-Pfad aktiv" : directError() }
    @objc func toneDirect() { guard md_direct_audio_running() else { status.stringValue = "AudioDeviceCore zuerst öffnen"; return }; md_direct_audio_test_tone(1.0); status.stringValue = "Direkter 440-Hz-Testton läuft 1 Sekunde" }
    func directError() -> String { var b = [CChar](repeating: 0, count: 512); return md_direct_audio_error(&b, 512) ? "AudioDeviceCore FEHLER: \(String(cString: b))" : "AudioDeviceCore FEHLER" }
    func refreshPlugins() { var a: [(Int, String)] = []; for i in 0..<Int(cs_plugin_count()) where cs_plugin_is_instrument_at(Int32(i)) { var b = [CChar](repeating: 0, count: 512); if cs_plugin_name_at(Int32(i), &b, 512) { a.append((i, String(cString: b))) } }; instruments = a; combo.removeAllItems(); a.forEach { combo.addItem(withObjectValue: $0.1) }; if !a.isEmpty { combo.selectItem(at: 0) }; pluginStatus.stringValue = "Instrumente gefunden: \(a.count)" }
    @objc func scanPlugins() { status.stringValue = "Plugin-Scan läuft …"; md_start_plugin_scan() }
    @objc func loadPlugin() { let row = combo.indexOfSelectedItem; guard track >= 0, row >= 0, row < instruments.count else { status.stringValue = "Kein Instrument ausgewählt"; return }; let p = instruments[row]; let d = cs_track_add_plugin_at(track, Int32(p.0)); status.stringValue = d >= 0 ? "Instrument geladen: \(p.1)" : "FEHLER: Instrument konnte nicht geladen werden" }
    @objc func previewNote() { guard track >= 0 else { return }; md_preview_note(track, 60, true); DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [track] in md_preview_note(track, 60, false) } }
    @objc func doPlay() { cs_engine_locate_seconds(0); cs_engine_play() }
    @objc func doStop() { cs_engine_stop() }
    @objc func tick() {
        if !md_plugin_scan_running() { refreshPlugins() }; let pos = cs_engine_position_seconds(), audio = md_audio_thread_position(); head.seconds = pos
        transportStatus.stringValue = String(format: "Transport: %@ · %.3f s", cs_engine_is_playing() ? "PLAY" : "STOP", pos); audioThreadStatus.stringValue = String(format: "MAGDA Audio thread: %.3f s", audio)
        if md_direct_audio_running() { var b = [CChar](repeating: 0, count: 256); let name = md_direct_audio_device_name(&b, 256) ? String(cString: b) : "?"; directStatus.stringValue = String(format: "%@ · %.0f Hz · %d smp · %d out · cb %llu · peak %.3f · E %.3f", name, md_direct_audio_sample_rate(), md_direct_audio_buffer_size(), md_direct_audio_active_outputs(), md_direct_audio_callbacks(), md_direct_audio_peak(), md_direct_audio_energy()) } else { directStatus.stringValue = "AudioDeviceCore: geschlossen" }
    }
    deinit { timer?.invalidate(); md_direct_audio_stop() }
}
final class AppDelegate: NSObject, NSApplicationDelegate { var window: NSWindow!; func applicationDidFinishLaunching(_ n: Notification) { let vc = MiniDAWController(); window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false); window.title = "MiniDAW Functional Test"; window.contentViewController = vc; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }; func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true } }
let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
