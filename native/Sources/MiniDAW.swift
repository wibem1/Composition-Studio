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
@_silgen_name("md_prepare_plugin_audio") func md_prepare_plugin_audio() -> Bool
@_silgen_name("md_plugin_audio_device_name") func md_plugin_audio_device_name(_ out: UnsafeMutablePointer<CChar>, _ cap: Int32) -> Bool
@_silgen_name("md_plugin_audio_active_outputs") func md_plugin_audio_active_outputs() -> Int32
@_silgen_name("md_plugin_audio_error") func md_plugin_audio_error(_ out: UnsafeMutablePointer<CChar>, _ cap: Int32) -> Bool

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
    let status = NSTextField(labelWithString: "Bereit für AudioDeviceCore-Test")
    let directStatus = NSTextField(labelWithString: "AudioDeviceCore: geschlossen")
    let engineStatus = NSTextField(labelWithString: "Plugin-Engine: noch nicht gestartet")
    let transportStatus = NSTextField(labelWithString: "Transport: –")
    let audioThreadStatus = NSTextField(labelWithString: "Plugin-Audio: –")
    let pluginStatus = NSTextField(labelWithString: "Pianoteq: wird beim Laden gezielt aus der bekannten Liste gewählt")
    let directStart = NSButton(title: "1  AudioDeviceCore öffnen", target: nil, action: nil)
    let directTone = NSButton(title: "2  Direkten Testton", target: nil, action: nil)
    let load = NSButton(title: "3  Pianoteq laden", target: nil, action: nil)
    let preview = NSButton(title: "4  Pianoteq-Ton", target: nil, action: nil)
    let play = NSButton(title: "5  Play", target: nil, action: nil)
    let stop = NSButton(title: "Stop", target: nil, action: nil)
    let head = PlayheadView()
    var pianoteqIndex: Int32 = -1, pianoteqName = "", track: Int32 = -1, timer: Timer?, engineStarted = false

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 500)) }
    override func viewDidLoad() {
        super.viewDidLoad()
        let title = NSTextField(labelWithString: "MiniDAW – Funktionsnachweis · Build \(miniDAWBuildNumber)"); title.font = .systemFont(ofSize: 24, weight: .bold)
        let explain = NSTextField(wrappingLabelWithString: "Der direkte JUCE-Test und die Plugin-Engine besitzen nicht gleichzeitig das Audiogerät. Vor dem Pianoteq-Test werden JUCE-Ausgänge und Tracktion-Wave-Ausgänge der Plugin-Engine ausdrücklich aktiviert."); explain.textColor = .secondaryLabelColor
        [title, explain, status, directStatus, engineStatus, transportStatus, audioThreadStatus, pluginStatus, directStart, directTone, load, preview, play, stop, head].forEach { view.addSubview($0) }
        title.frame = NSRect(x: 24, y: 448, width: 700, height: 32); explain.frame = NSRect(x: 24, y: 402, width: 700, height: 42)
        directStart.frame = NSRect(x: 24, y: 354, width: 190, height: 30); directTone.frame = NSRect(x: 224, y: 354, width: 170, height: 30); directStatus.frame = NSRect(x: 410, y: 358, width: 326, height: 22)
        load.frame = NSRect(x: 24, y: 306, width: 170, height: 30); pluginStatus.frame = NSRect(x: 210, y: 310, width: 526, height: 22)
        preview.frame = NSRect(x: 24, y: 261, width: 150, height: 30); play.frame = NSRect(x: 184, y: 261, width: 120, height: 30); stop.frame = NSRect(x: 314, y: 261, width: 100, height: 30)
        head.frame = NSRect(x: 24, y: 166, width: 712, height: 70); status.frame = NSRect(x: 24, y: 132, width: 712, height: 22); status.font = .systemFont(ofSize: 13, weight: .semibold)
        engineStatus.frame = NSRect(x: 24, y: 102, width: 712, height: 20); transportStatus.frame = NSRect(x: 370, y: 74, width: 366, height: 20); audioThreadStatus.frame = NSRect(x: 24, y: 74, width: 330, height: 20)
        directStart.target = self; directStart.action = #selector(startDirect); directTone.target = self; directTone.action = #selector(toneDirect); load.target = self; load.action = #selector(loadPianoteq); preview.target = self; preview.action = #selector(previewNote); play.target = self; play.action = #selector(doPlay); stop.target = self; stop.action = #selector(doStop)
        preview.isEnabled = false; play.isEnabled = false; stop.isEnabled = false
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }

    @objc func startDirect() {
        guard !engineStarted else { status.stringValue = "Plugin-Engine besitzt jetzt das Audiogerät; direkter Test bleibt geschlossen"; return }
        let ok = md_direct_audio_start(); status.stringValue = ok ? "AudioDeviceCore geöffnet – direkter JUCE-Pfad aktiv" : directError()
    }
    @objc func toneDirect() { guard md_direct_audio_running() else { status.stringValue = "AudioDeviceCore zuerst öffnen"; return }; md_direct_audio_test_tone(1.0); status.stringValue = "Direkter 440-Hz-Testton läuft 1 Sekunde" }
    func directError() -> String { var b = [CChar](repeating: 0, count: 512); return md_direct_audio_error(&b, 512) ? "AudioDeviceCore FEHLER: \(String(cString: b))" : "AudioDeviceCore FEHLER" }
    func pluginError() -> String { var b = [CChar](repeating: 0, count: 512); return md_plugin_audio_error(&b, 512) ? String(cString: b) : "unbekannter Audiofehler" }

    func findPianoteq() {
        pianoteqIndex = -1; pianoteqName = ""
        for i in 0..<Int(cs_plugin_count()) where cs_plugin_is_instrument_at(Int32(i)) {
            var b = [CChar](repeating: 0, count: 512)
            if cs_plugin_name_at(Int32(i), &b, 512) { let name = String(cString: b); if name.localizedCaseInsensitiveContains("Pianoteq") { pianoteqIndex = Int32(i); pianoteqName = name; break } }
        }
    }

    @objc func loadPianoteq() {
        if md_direct_audio_running() { md_direct_audio_stop() }
        directStart.isEnabled = false; directTone.isEnabled = false
        if !engineStarted {
            guard cs_engine_initialize() else { engineStatus.stringValue = "Plugin-Engine: FEHLER beim Start"; status.stringValue = "Plugin-Engine konnte nicht gestartet werden"; return }
            engineStarted = true
        }
        guard md_prepare_plugin_audio() else { engineStatus.stringValue = "Plugin-Engine: Audio FEHLER"; status.stringValue = "Plugin-Audio: \(pluginError())"; return }
        var out = [CChar](repeating: 0, count: 512)
        let audioName = md_plugin_audio_device_name(&out, 512) ? String(cString: out) : "?"
        engineStatus.stringValue = "Plugin-Engine: bereit · \(audioName) · \(md_plugin_audio_active_outputs()) Ausgänge"
        if track < 0 { track = md_create_test_session() }
        findPianoteq()
        guard track >= 0 else { status.stringValue = "FEHLER: Testspur konnte nicht erzeugt werden"; return }
        guard pianoteqIndex >= 0 else { pluginStatus.stringValue = "Pianoteq nicht in der vorhandenen Plugin-Liste"; status.stringValue = "Pianoteq nicht verfügbar"; return }
        let device = cs_track_add_plugin_at(track, pianoteqIndex)
        guard device >= 0 else { status.stringValue = "FEHLER: Pianoteq konnte nicht in die Spur geladen werden"; return }
        pluginStatus.stringValue = "Pianoteq geladen: \(pianoteqName) · Device \(device)"
        status.stringValue = "Plugin-Audio aktiv – jetzt Pianoteq-Ton testen"
        preview.isEnabled = true; play.isEnabled = true; stop.isEnabled = true; load.isEnabled = false
    }

    @objc func previewNote() { guard engineStarted, track >= 0 else { return }; md_preview_note(track, 60, true); DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [track] in md_preview_note(track, 60, false) } }
    @objc func doPlay() { guard engineStarted else { return }; cs_engine_locate_seconds(0); cs_engine_play() }
    @objc func doStop() { if engineStarted { cs_engine_stop() } }
    @objc func tick() {
        if engineStarted { let pos=cs_engine_position_seconds(), audio=md_audio_thread_position(); head.seconds=pos; transportStatus.stringValue=String(format:"Transport: %@ · %.3f s",cs_engine_is_playing() ? "PLAY":"STOP",pos); audioThreadStatus.stringValue=String(format:"Plugin-Audio: %.3f s",audio) }
        if md_direct_audio_running() { var b=[CChar](repeating:0,count:256); let name=md_direct_audio_device_name(&b,256) ? String(cString:b):"?"; directStatus.stringValue=String(format:"%@ · %.0f Hz · %d smp · %d out · cb %llu · peak %.3f · E %.3f",name,md_direct_audio_sample_rate(),md_direct_audio_buffer_size(),md_direct_audio_active_outputs(),md_direct_audio_callbacks(),md_direct_audio_peak(),md_direct_audio_energy()) } else { directStatus.stringValue="AudioDeviceCore: geschlossen" }
    }
    deinit { timer?.invalidate(); md_direct_audio_stop() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) { let vc=MiniDAWController(); window=NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:500),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false); window.title="MiniDAW Functional Test · Build \(miniDAWBuildNumber)"; window.contentViewController=vc; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}
let app=NSApplication.shared; let delegate=AppDelegate(); app.delegate=delegate; app.setActivationPolicy(.regular); app.run()
