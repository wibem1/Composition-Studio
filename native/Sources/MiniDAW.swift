import AppKit

@_silgen_name("cs_engine_initialize") func cs_engine_initialize() -> Bool
@_silgen_name("cs_engine_play") func cs_engine_play()
@_silgen_name("cs_engine_stop") func cs_engine_stop()
@_silgen_name("cs_engine_is_playing") func cs_engine_is_playing() -> Bool
@_silgen_name("cs_engine_position_seconds") func cs_engine_position_seconds() -> Double
@_silgen_name("cs_engine_locate_seconds") func cs_engine_locate_seconds(_ s: Double)
@_silgen_name("cs_plugin_count") func cs_plugin_count() -> Int32
@_silgen_name("cs_plugin_name_at") func cs_plugin_name_at(_ i:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32)->Bool
@_silgen_name("cs_plugin_is_instrument_at") func cs_plugin_is_instrument_at(_ i:Int32)->Bool
@_silgen_name("cs_track_add_plugin_at") func cs_track_add_plugin_at(_ track:Int32,_ plugin:Int32)->Int32
@_silgen_name("md_start_plugin_scan") func md_start_plugin_scan()
@_silgen_name("md_plugin_scan_running") func md_plugin_scan_running()->Bool
@_silgen_name("md_create_test_session") func md_create_test_session()->Int32
@_silgen_name("md_audio_thread_position") func md_audio_thread_position()->Double
@_silgen_name("md_preview_note") func md_preview_note(_ track:Int32,_ note:Int32,_ on:Bool)

final class PlayheadView:NSView {
    var seconds:Double=0 { didSet { needsDisplay=true } }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        NSColor.separatorColor.setStroke(); let line=NSBezierPath(); line.move(to:NSPoint(x:20,y:bounds.midY)); line.line(to:NSPoint(x:bounds.width-20,y:bounds.midY)); line.stroke()
        let x=20 + CGFloat(min(max(seconds/4.0,0),1))*(bounds.width-40)
        NSColor.systemRed.setStroke(); let p=NSBezierPath(); p.move(to:NSPoint(x:x,y:12)); p.line(to:NSPoint(x:x,y:bounds.height-12)); p.lineWidth=3; p.stroke()
    }
}

final class MiniDAWController:NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    let status=NSTextField(labelWithString:"Start …")
    let engineStatus=NSTextField(labelWithString:"Engine: –")
    let transportStatus=NSTextField(labelWithString:"Transport: –")
    let audioThreadStatus=NSTextField(labelWithString:"Audio thread: –")
    let pluginStatus=NSTextField(labelWithString:"Plugin: –")
    let combo=NSComboBox()
    let scan=NSButton(title:"1  Plugins suchen",target:nil,action:nil)
    let load=NSButton(title:"2  Instrument laden",target:nil,action:nil)
    let preview=NSButton(title:"3  Ton testen",target:nil,action:nil)
    let play=NSButton(title:"4  Play",target:nil,action:nil)
    let stop=NSButton(title:"Stop",target:nil,action:nil)
    let head=PlayheadView()
    var instruments:[(Int,String)]=[]
    var track:Int32 = -1
    var timer:Timer?

    override func loadView(){ view=NSView(frame:NSRect(x:0,y:0,width:720,height:430)) }
    override func viewDidLoad(){
        super.viewDidLoad(); view.wantsLayer=true
        let title=NSTextField(labelWithString:"MiniDAW – Funktionsnachweis")
        title.font=.systemFont(ofSize:24,weight:.bold)
        let explain=NSTextField(wrappingLabelWithString:"Nur ein Test: eine Spur, vier MIDI-Noten, ein echtes Instrument-Plugin, MAGDA-Transport und hörbare Wiedergabe. Keine weiteren DAW-Funktionen.")
        explain.textColor=.secondaryLabelColor
        [title,explain,status,engineStatus,transportStatus,audioThreadStatus,pluginStatus,combo,scan,load,preview,play,stop,head].forEach{view.addSubview($0)}
        title.frame=NSRect(x:24,y:378,width:650,height:32); explain.frame=NSRect(x:24,y:330,width:650,height:42)
        scan.frame=NSRect(x:24,y:280,width:145,height:30); combo.frame=NSRect(x:180,y:280,width:300,height:30); load.frame=NSRect(x:490,y:280,width:180,height:30)
        preview.frame=NSRect(x:24,y:235,width:145,height:30); play.frame=NSRect(x:180,y:235,width:145,height:30); stop.frame=NSRect(x:335,y:235,width:100,height:30)
        head.frame=NSRect(x:24,y:145,width:646,height:70)
        status.frame=NSRect(x:24,y:112,width:646,height:22); status.font=.systemFont(ofSize:13,weight:.semibold)
        engineStatus.frame=NSRect(x:24,y:82,width:300,height:20); transportStatus.frame=NSRect(x:340,y:82,width:330,height:20)
        audioThreadStatus.frame=NSRect(x:24,y:54,width:300,height:20); pluginStatus.frame=NSRect(x:340,y:54,width:330,height:20)
        combo.usesDataSource=true; combo.dataSource=self; combo.delegate=self
        scan.target=self;scan.action=#selector(scanPlugins);load.target=self;load.action=#selector(loadPlugin);preview.target=self;preview.action=#selector(previewNote);play.target=self;play.action=#selector(doPlay);stop.target=self;stop.action=#selector(doStop)
        let ok=cs_engine_initialize(); engineStatus.stringValue="Engine: \(ok ? "bereit" : "FEHLER")"
        if ok { track=md_create_test_session(); status.stringValue=track>=0 ? "Testspur + C–E–G–C angelegt" : "FEHLER: Testspur konnte nicht angelegt werden" }
        timer=Timer.scheduledTimer(timeInterval:0.05,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        refreshPlugins()
    }
    func numberOfItems(in comboBox:NSComboBox)->Int { instruments.count }
    func comboBox(_ comboBox:NSComboBox,objectValueForItemAt index:Int)->Any? { instruments[index].1 }
    func refreshPlugins(){
        var a:[(Int,String)]=[]
        for i in 0..<Int(cs_plugin_count()) where cs_plugin_is_instrument_at(Int32(i)) {
            var b=[CChar](repeating:0,count:512); if cs_plugin_name_at(Int32(i),&b,512){a.append((i,String(cString:b)))}
        }
        instruments=a; combo.reloadData(); if !a.isEmpty && combo.indexOfSelectedItem<0 {combo.selectItem(at:0)}
        pluginStatus.stringValue="Instrumente gefunden: \(a.count)"
    }
    @objc func scanPlugins(){ status.stringValue="Plugin-Scan läuft …"; md_start_plugin_scan() }
    @objc func loadPlugin(){
        let row=combo.indexOfSelectedItem; guard track>=0,row>=0,row<instruments.count else {status.stringValue="Kein Instrument ausgewählt";return}
        let p=instruments[row]; let device=cs_track_add_plugin_at(track,Int32(p.0)); status.stringValue=device>=0 ? "Instrument geladen: \(p.1) · Device \(device)" : "FEHLER: Instrument konnte nicht geladen werden"
    }
    @objc func previewNote(){ guard track>=0 else{return}; md_preview_note(track,60,true); DispatchQueue.main.asyncAfter(deadline:.now()+0.7){[track] in md_preview_note(track,60,false)} }
    @objc func doPlay(){ cs_engine_locate_seconds(0); cs_engine_play(); status.stringValue="Play an MAGDA gesendet" }
    @objc func doStop(){ cs_engine_stop(); status.stringValue="Stop an MAGDA gesendet" }
    @objc func tick(){
        if !md_plugin_scan_running(){ refreshPlugins() }
        let pos=cs_engine_position_seconds(),audio=md_audio_thread_position(); head.seconds=pos
        transportStatus.stringValue=String(format:"Transport: %@ · %.3f s",cs_engine_is_playing() ? "PLAY":"STOP",pos)
        audioThreadStatus.stringValue=String(format:"Audio thread: %.3f s",audio)
    }
}

final class AppDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    func applicationDidFinishLaunching(_ notification:Notification){
        let vc=MiniDAWController(); window=NSWindow(contentRect:NSRect(x:0,y:0,width:720,height:430),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false);window.title="MiniDAW Proof";window.contentViewController=vc;window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}

let app=NSApplication.shared;let delegate=AppDelegate();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
