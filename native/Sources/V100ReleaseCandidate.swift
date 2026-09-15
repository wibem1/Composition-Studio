import AppKit
import Foundation
import Security
import UniformTypeIdentifiers

private func rcQuantize(_ value:Double,_ grid:Double=0.25) -> Double {
    guard grid > 0 else { return max(0,value) }
    return max(0,(value/grid).rounded()*grid)
}

private final class RCStudioState {
    static let shared=RCStudioState()
    let arrangement=RCArrangementView()
    let piano=RCPianoRollView()
    let notation=RCNotationView()
    let pluginScroll=NSScrollView()
    let pluginContent=FlippedView()
    let mixer=CardView()
    let volume=NSSlider(value:1,minValue:0,maxValue:1,target:nil,action:nil)
    let pan=NSSlider(value:0,minValue:-1,maxValue:1,target:nil,action:nil)
    let output=NSTextField(string:"master")
    let midiInput=NSTextField(string:"")
    let chain=label("Keine Inserts",size:11,color:.secondaryLabelColor)
    let editorMode=NSPopUpButton()
    var toolbar:[NSButton]=[]
    var plugins:[EnginePlugin]=[]
    var pluginMode="Plugins"
    var searchText=""
    var installed=false
    var chatBusy=false
    var lastPluginCount = -1
    var selectedNoteIndex:Int?
}

private final class RCArrangementView:NSView {
    var tracks:[EngineTrack]=[] { didSet { needsDisplay=true } }
    var clips:[EngineClip]=[] { didSet { needsDisplay=true } }
    var names:[Int:String]=[:] { didSet { needsDisplay=true } }
    var selectedTrackID:Int? { didSet { needsDisplay=true } }
    var selectedClipID:Int? { didSet { needsDisplay=true } }
    var playheadBeat:Double=0 { didSet { needsDisplay=true } }
    var onSelectTrack:((Int)->Void)?
    var onSelectClip:((Int,Int)->Void)?
    var onMoveClip:((Int,Double,Int)->Void)?
    var onResizeClip:((Int,Double)->Void)?
    var onSeek:((Double)->Void)?
    private var dragClip:Int?
    private var dragTrack:Int?
    private var dragOriginalStart=0.0
    private var dragOriginalLength=0.0
    private var dragGrabOffset=0.0
    private var dragPreviewStart:Double?
    private var dragPreviewLength:Double?
    private var dragPreviewTrack:Int?
    private var resizeMode=false
    private let colors:[NSColor]=[.systemBlue,.systemRed,.systemGreen,.systemOrange,.systemPurple,.systemTeal,.systemGray]
    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
    required init?(coder:NSCoder){fatalError()}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true}
    private var header:CGFloat { 170 }
    private var top:CGFloat { 58 }
    private var maxBeat:Double {
        let end=clips.map{$0.startBeat+$0.lengthBeats}.max() ?? 0
        return max(32,ceil(max(end,playheadBeat+1)/4)*4)
    }
    private var beatW:CGFloat { max(7,(bounds.width-header-12)/CGFloat(maxBeat)) }
    private var rowH:CGFloat { max(52,(bounds.height-top)/CGFloat(max(1,tracks.count))) }
    private func trackIndex(at y:CGFloat)->Int? {
        guard y>=top,!tracks.isEmpty else{return nil}
        return min(tracks.count-1,max(0,Int((y-top)/rowH)))
    }
    private func beat(at x:CGFloat)->Double { max(0,Double((x-header)/beatW)) }
    private func placement(_ clip:EngineClip)->(Double,Double,Int) {
        if clip.id==dragClip { return (dragPreviewStart ?? clip.startBeat,dragPreviewLength ?? clip.lengthBeats,dragPreviewTrack ?? clip.trackId) }
        return (clip.startBeat,clip.lengthBeats,clip.trackId)
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.csArrangement.setFill();bounds.fill()
        NSColor.csPanelStrong.setFill();NSRect(x:0,y:0,width:header,height:bounds.height).fill()
        NSColor.csTop.setFill();NSRect(x:header,y:0,width:max(0,bounds.width-header),height:top).fill()
        let sections=["A – Einführung","B – Entwicklung","C – Höhepunkt","D – Ausklang"]
        let sc=[NSColor.systemGreen.withAlphaComponent(0.16),NSColor.systemBlue.withAlphaComponent(0.15),NSColor.systemRed.withAlphaComponent(0.14),NSColor.systemPurple.withAlphaComponent(0.14)]
        for i in 0..<4 {
            let x=header+CGFloat(i)*(bounds.width-header)/4,w=(bounds.width-header)/4
            sc[i].setFill();NSRect(x:x,y:24,width:w,height:34).fill()
            (sections[i] as NSString).draw(in:NSRect(x:x+5,y:34,width:w-10,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.csText])
        }
        for b in stride(from:0,through:Int(maxBeat),by:4) {
            let x=header+CGFloat(b)*beatW
            NSColor.csLine.setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:x,y:top));p.line(to:NSPoint(x:x,y:bounds.height));p.stroke()
            ("\(b+1)" as NSString).draw(at:NSPoint(x:x+3,y:5),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.secondaryLabelColor])
        }
        for (i,t) in tracks.enumerated() {
            let y=top+CGFloat(i)*rowH,c=colors[i%colors.count]
            (t.id==selectedTrackID ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.12):NSColor.csPanelStrong).setFill();NSRect(x:0,y:y,width:header,height:rowH).fill()
            c.setFill();NSBezierPath(roundedRect:NSRect(x:8,y:y+8,width:16,height:max(24,rowH-16)),xRadius:3,yRadius:3).fill()
            (t.name as NSString).draw(in:NSRect(x:33,y:y+9,width:128,height:18),withAttributes:[.font:NSFont.systemFont(ofSize:13,weight:.semibold),.foregroundColor:NSColor.csText])
            let states="\(t.muted ? "M" : "m")   \(t.soloed ? "S" : "s")   \(t.recordArmed ? "●" : "○")"
            (states as NSString).draw(in:NSRect(x:33,y:y+31,width:110,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.secondaryLabelColor])
            NSColor.csLine.setStroke();let line=NSBezierPath();line.move(to:NSPoint(x:0,y:y+rowH));line.line(to:NSPoint(x:bounds.width,y:y+rowH));line.stroke()
            for clip in clips {
                let pl=placement(clip);guard pl.2==t.id else{continue}
                let x=header+CGFloat(pl.0)*beatW,w=max(12,CGFloat(pl.1)*beatW)
                let r=NSRect(x:x,y:y+8,width:min(w,max(4,bounds.width-x-4)),height:max(20,rowH-16))
                c.withAlphaComponent(clip.id==selectedClipID ? 0.32:0.18).setFill();NSBezierPath(roundedRect:r,xRadius:5,yRadius:5).fill()
                if clip.id==selectedClipID { c.setStroke();let q=NSBezierPath(roundedRect:r,xRadius:5,yRadius:5);q.lineWidth=2;q.stroke() }
                ((names[clip.id] ?? "MIDI Clip") as NSString).draw(in:NSRect(x:r.minX+6,y:r.minY+4,width:max(20,r.width-12),height:14),withAttributes:[.font:NSFont.systemFont(ofSize:10,weight:.medium),.foregroundColor:NSColor.csText])
                for n in clip.notes.prefix(600) {
                    let nx=x+CGFloat(n.startBeat)*beatW,nw=max(2,CGFloat(n.lengthBeats)*beatW)
                    let py=CGFloat(127-n.note)/127
                    let ny=r.minY+20+py*max(1,r.height-25)
                    c.setFill();NSRect(x:nx,y:ny,width:min(nw,max(1,r.maxX-nx)),height:2).fill()
                }
            }
        }
        if tracks.isEmpty { ("Noch keine Spur – MIDI importieren oder + Spur verwenden" as NSString).draw(in:NSRect(x:header+24,y:top+28,width:480,height:28),withAttributes:[.font:NSFont.systemFont(ofSize:15,weight:.medium),.foregroundColor:NSColor.secondaryLabelColor]) }
        let px=header+CGFloat(playheadBeat)*beatW
        if px>=header && px<=bounds.maxX { NSColor.systemRed.withAlphaComponent(0.88).setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:px,y:0));p.line(to:NSPoint(x:px,y:bounds.height));p.lineWidth=1.5;p.stroke();NSColor.systemRed.setFill();NSBezierPath(ovalIn:NSRect(x:px-4,y:3,width:8,height:8)).fill() }
    }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self)
        let p=convert(event.locationInWindow,from:nil)
        if p.y<top,p.x>=header { onSeek?(rcQuantize(beat(at:p.x),0.25));return }
        guard let i=trackIndex(at:p.y) else{return}
        let track=tracks[i];selectedTrackID=track.id;onSelectTrack?(track.id)
        guard p.x>=header else{needsDisplay=true;return}
        let b=beat(at:p.x)
        guard let clip=clips.reversed().first(where:{ c in let pl=placement(c);return pl.2==track.id && b>=pl.0 && b<=pl.0+pl.1 }) else { selectedClipID=nil;needsDisplay=true;return }
        selectedClipID=clip.id;onSelectClip?(track.id,clip.id)
        dragClip=clip.id;dragTrack=clip.trackId;dragOriginalStart=clip.startBeat;dragOriginalLength=clip.lengthBeats;dragGrabOffset=b-clip.startBeat
        let endX=header+CGFloat(clip.startBeat+clip.lengthBeats)*beatW
        resizeMode=abs(p.x-endX)<9
        dragPreviewStart=clip.startBeat;dragPreviewLength=clip.lengthBeats;dragPreviewTrack=clip.trackId
        needsDisplay=true
    }
    override func mouseDragged(with event:NSEvent) {
        guard dragClip != nil else{return}
        let p=convert(event.locationInWindow,from:nil),b=beat(at:p.x)
        if resizeMode { dragPreviewLength=max(0.25,rcQuantize(b-dragOriginalStart,0.25)) }
        else {
            dragPreviewStart=rcQuantize(b-dragGrabOffset,0.25)
            if let i=trackIndex(at:p.y) { dragPreviewTrack=tracks[i].id }
        }
        needsDisplay=true
    }
    override func mouseUp(with event:NSEvent) {
        guard let id=dragClip else{return}
        if resizeMode { onResizeClip?(id,dragPreviewLength ?? dragOriginalLength) }
        else { onMoveClip?(id,dragPreviewStart ?? dragOriginalStart,dragPreviewTrack ?? dragTrack ?? -1) }
        dragClip=nil;dragPreviewStart=nil;dragPreviewLength=nil;dragPreviewTrack=nil;resizeMode=false;needsDisplay=true
    }
    override func keyDown(with event:NSEvent) { super.keyDown(with:event) }
}

private final class RCPianoRollView:NSView {
    var clip:EngineClip? { didSet { selectedIndex=nil;needsDisplay=true } }
    var selectedIndex:Int? { didSet { needsDisplay=true } }
    var onAdd:((Int,Int,Double,Double)->Void)?
    var onUpdate:((Int,Int,Int,Double,Double)->Void)?
    var onDelete:((Int)->Void)?
    var onPreview:((Int)->Void)?
    private var dragIndex:Int?
    private var dragPitch=60
    private var dragStart=0.0
    override var isFlipped:Bool { true }
    override var acceptsFirstResponder:Bool { true }
    required init?(coder:NSCoder){fatalError()}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true}
    private var left:CGFloat { 52 }
    private var top:CGFloat { 28 }
    private var beatMax:Double { max(4,clip?.lengthBeats ?? 4) }
    private var minPitch:Int { max(0,(clip?.notes.map{$0.note}.min() ?? 48)-5) }
    private var maxPitch:Int { min(127,max(minPitch+24,(clip?.notes.map{$0.note}.max() ?? 72)+5)) }
    private var beatW:CGFloat { max(8,(bounds.width-left-8)/CGFloat(beatMax)) }
    private var rowH:CGFloat { max(4,(bounds.height-top-8)/CGFloat(maxPitch-minPitch+1)) }
    private func rect(_ n:EngineMidiNote)->NSRect {
        let x=left+CGFloat(n.startBeat)*beatW,y=top+CGFloat(maxPitch-n.note)*rowH,w=max(4,CGFloat(n.lengthBeats)*beatW)
        return NSRect(x:x,y:y,width:min(w,max(2,bounds.width-x-4)),height:max(4,rowH-1))
    }
    private func pitch(at y:CGFloat)->Int { max(minPitch,min(maxPitch,maxPitch-Int((y-top)/rowH))) }
    private func beat(at x:CGFloat)->Double { rcQuantize(Double((x-left)/beatW),0.25) }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.csEditor.setFill();bounds.fill();NSColor.csLine.setStroke();NSBezierPath(rect:bounds.insetBy(dx:0.5,dy:0.5)).stroke()
        ("Pianoroll" as NSString).draw(at:NSPoint(x:8,y:6),withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:NSColor.csText])
        guard let clip else { ("MIDI-Clip auswählen" as NSString).draw(at:NSPoint(x:70,y:52),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.secondaryLabelColor]);return }
        for b in 0...Int(ceil(beatMax)) { let x=left+CGFloat(b)*beatW;NSColor.csLine.withAlphaComponent(b%4==0 ? 0.75:0.35).setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:x,y:top));p.line(to:NSPoint(x:x,y:bounds.height));p.stroke() }
        for n in minPitch...maxPitch { let y=top+CGFloat(maxPitch-n)*rowH;if n%12==0 { NSColor.csLine.withAlphaComponent(0.45).setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:0,y:y));p.line(to:NSPoint(x:bounds.width,y:y));p.stroke();("C\(n/12-1)" as NSString).draw(at:NSPoint(x:7,y:y+1),withAttributes:[.font:NSFont.systemFont(ofSize:9),.foregroundColor:NSColor.secondaryLabelColor]) } }
        for (i,n) in clip.notes.enumerated() { let r=rect(n);(i==selectedIndex ? NSColor.systemBlue:NSColor.systemGreen).setFill();NSBezierPath(roundedRect:r,xRadius:2,yRadius:2).fill() }
    }
    override func mouseDown(with event:NSEvent) {
        guard let clip else{return};window?.makeFirstResponder(self);let p=convert(event.locationInWindow,from:nil)
        if let i=clip.notes.indices.reversed().first(where:{rect(clip.notes[$0]).contains(p)}) { selectedIndex=i;dragIndex=i;dragPitch=clip.notes[i].note;dragStart=clip.notes[i].startBeat;onPreview?(clip.notes[i].note);if event.clickCount==2{onDelete?(i);dragIndex=nil};return }
        guard p.x>=left,p.y>=top else{return}
        if event.clickCount>=2 { onAdd?(pitch(at:p.y),96,beat(at:p.x),1.0) }
    }
    override func mouseDragged(with event:NSEvent) {
        guard let clip,let i=dragIndex,i<clip.notes.count else{return};let p=convert(event.locationInWindow,from:nil);dragPitch=pitch(at:p.y);dragStart=beat(at:p.x);needsDisplay=true
    }
    override func mouseUp(with event:NSEvent) {
        guard let clip,let i=dragIndex,i<clip.notes.count else{return};let n=clip.notes[i];onUpdate?(i,dragPitch,n.velocity,dragStart,n.lengthBeats);dragIndex=nil
    }
    override func keyDown(with event:NSEvent) {
        if event.keyCode==51 || event.keyCode==117,let i=selectedIndex { onDelete?(i);return }
        super.keyDown(with:event)
    }
}

private final class RCNotationView:NSView {
    var clip:EngineClip? { didSet { needsDisplay=true } }
    override var isFlipped:Bool { true }
    required init?(coder:NSCoder){fatalError()}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true}
    override func draw(_ dirtyRect:NSRect) {
        NSColor.csEditor.setFill();bounds.fill();NSColor.csLine.setStroke();NSBezierPath(rect:bounds.insetBy(dx:0.5,dy:0.5)).stroke()
        ("Notenansicht" as NSString).draw(at:NSPoint(x:8,y:6),withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:NSColor.csText])
        guard let clip,!clip.notes.isEmpty else { ("MIDI-Clip auswählen" as NSString).draw(at:NSPoint(x:70,y:52),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.secondaryLabelColor]);return }
        let left:CGFloat=48,right:CGFloat=12,staffTop=max(46,bounds.midY-30),spacing:CGFloat=10
        for i in 0..<5 { let y=staffTop+CGFloat(i)*spacing;NSColor.csText.withAlphaComponent(0.55).setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:left,y:y));p.line(to:NSPoint(x:bounds.width-right,y:y));p.stroke() }
        ("𝄞" as NSString).draw(at:NSPoint(x:12,y:staffTop-15),withAttributes:[.font:NSFont.systemFont(ofSize:36),.foregroundColor:NSColor.csText])
        let maxBeat=max(4,clip.lengthBeats),usable=max(1,bounds.width-left-right)
        for n in clip.notes.prefix(500) {
            let x=left+CGFloat(n.startBeat/maxBeat)*usable
            let diatonic=CGFloat(n.note-60)*3.5
            let y=staffTop+30-diatonic
            NSColor.csText.setFill();NSBezierPath(ovalIn:NSRect(x:x-4,y:y-3,width:9,height:6)).fill();NSColor.csText.setStroke();let stem=NSBezierPath();stem.move(to:NSPoint(x:x+4,y:y));stem.line(to:NSPoint(x:x+4,y:y-24));stem.stroke()
        }
    }
}

private enum RCProvider:String {
    case anthropic="Claude Fable 5.1"
    case google="Gemini 3.6 Flash"
    case openai="OpenAI GPT-5.6 Sol"
    var account:String { switch self { case .anthropic:return "anthropic";case .google:return "google";case .openai:return "openai" } }
    var defaultModel:String { switch self { case .anthropic:return "claude-fable-5-1";case .google:return "gemini-3.6-flash";case .openai:return "gpt-5.6-sol" } }
}

private enum RCKeychain {
    static let service="net.klangwerke.CompositionStudio.ai"
    static func read(_ account:String)->String? {
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var item:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&item)==errSecSuccess,let data=item as? Data else{return nil};return String(data:data,encoding:.utf8)
    }
    static func write(_ value:String,account:String) {
        let base:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        SecItemDelete(base as CFDictionary)
        var add=base;add[kSecValueData as String]=Data(value.utf8);SecItemAdd(add as CFDictionary,nil)
    }
}

private final class RCAIClient {
    static func request(provider:RCProvider,model:String,key:String,system:String,prompt:String,completion:@escaping(Result<String,Error>)->Void) {
        let url:URL
        var body:[String:Any]
        var headers=["Content-Type":"application/json"]
        switch provider {
        case .anthropic:
            url=URL(string:"https://api.anthropic.com/v1/messages")!
            headers["x-api-key"]=key;headers["anthropic-version"]="2023-06-01"
            body=["model":model,"max_tokens":12000,"system":system,"messages":[["role":"user","content":prompt]]]
        case .google:
            let safe=model.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? model
            url=URL(string:"https://generativelanguage.googleapis.com/v1beta/models/\(safe):generateContent")!
            headers["x-goog-api-key"]=key
            body=["system_instruction":["parts":[["text":system]]],"contents":[["role":"user","parts":[["text":prompt]]]]]
        case .openai:
            url=URL(string:"https://api.openai.com/v1/responses")!
            headers["Authorization"]="Bearer \(key)"
            body=["model":model,"instructions":system,"input":prompt,"max_output_tokens":12000,"store":false]
        }
        var req=URLRequest(url:url);req.httpMethod="POST";for (k,v) in headers{req.setValue(v,forHTTPHeaderField:k)}
        do{req.httpBody=try JSONSerialization.data(withJSONObject:body)}catch{completion(.failure(error));return}
        URLSession.shared.dataTask(with:req){data,response,error in
            if let error { DispatchQueue.main.async{completion(.failure(error))};return }
            guard let data else { DispatchQueue.main.async{completion(.failure(NSError(domain:"CompositionStudioAI",code:-1,userInfo:[NSLocalizedDescriptionKey:"Leere KI-Antwort"]))) };return }
            do {
                let root=try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
                if let http=response as? HTTPURLResponse,http.statusCode>=400 {
                    let message=((root["error"] as? [String:Any])?["message"] as? String) ?? "HTTP \(http.statusCode)"
                    throw NSError(domain:"CompositionStudioAI",code:http.statusCode,userInfo:[NSLocalizedDescriptionKey:message])
                }
                var text=""
                switch provider {
                case .anthropic:
                    if let blocks=root["content"] as? [[String:Any]] { text=blocks.compactMap{$0["text"] as? String}.joined(separator:"\n") }
                case .google:
                    if let candidates=root["candidates"] as? [[String:Any]],let content=candidates.first?["content"] as? [String:Any],let parts=content["parts"] as? [[String:Any]] { text=parts.compactMap{$0["text"] as? String}.joined(separator:"\n") }
                case .openai:
                    if let direct=root["output_text"] as? String { text=direct }
                    if text.isEmpty,let output=root["output"] as? [[String:Any]] { for item in output { if let content=item["content"] as? [[String:Any]] { text += content.compactMap{$0["text"] as? String}.joined(separator:"\n") } } }
                }
                if text.isEmpty { throw NSError(domain:"CompositionStudioAI",code:-2,userInfo:[NSLocalizedDescriptionKey:"Die KI lieferte keinen Text."]) }
                DispatchQueue.main.async{completion(.success(text))}
            } catch { DispatchQueue.main.async{completion(.failure(error))} }
        }.resume()
    }
}

private enum RCMusicXML {
    static func escaped(_ s:String)->String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;") }
    static func pitch(_ midi:Int)->(String,Int,Int) {
        let names:[(String,Int)]=[("C",0),("C",1),("D",0),("D",1),("E",0),("F",0),("F",1),("G",0),("G",1),("A",0),("A",1),("B",0)]
        let p=max(0,min(127,midi)),n=names[p%12];return(n.0,n.1,p/12-1)
    }
    static func document(clip:EngineClip,title:String,tempo:Double)->String {
        let divisions=480,measureBeats=4.0
        let maxEnd=max(4.0,clip.notes.map{$0.startBeat+$0.lengthBeats}.max() ?? 4.0),measures=max(1,Int(ceil(maxEnd/measureBeats)))
        var xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">\n<score-partwise version=\"4.0\"><work><work-title>\(escaped(title))</work-title></work><part-list><score-part id=\"P1\"><part-name>MIDI</part-name></score-part></part-list><part id=\"P1\">"
        for m in 0..<measures {
            xml += "<measure number=\"\(m+1)\">"
            if m==0 { xml += "<attributes><divisions>\(divisions)</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes><direction placement=\"above\"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>\(Int(tempo.rounded()))</per-minute></metronome></direction-type></direction>" }
            let start=Double(m)*measureBeats,end=start+measureBeats,notes=clip.notes.filter{$0.startBeat>=start && $0.startBeat<end}.sorted{$0.startBeat<$1.startBeat}
            if notes.isEmpty { xml += "<note><rest/><duration>\(divisions*4)</duration><voice>1</voice><type>whole</type></note>" }
            else {
                for (i,n) in notes.enumerated() {
                    let p=pitch(n.note),local=max(0,n.startBeat-start),dur=max(1,Int((n.lengthBeats*Double(divisions)).rounded()))
                    if i>0 { xml += "<backup><duration>\(divisions*4)</duration></backup>" }
                    let forward=max(0,Int((local*Double(divisions)).rounded()));if forward>0{xml += "<forward><duration>\(forward)</duration></forward>"}
                    xml += "<note><pitch><step>\(p.0)</step>\(p.1==0 ? "" : "<alter>\(p.1)</alter>")<octave>\(p.2)</octave></pitch><duration>\(dur)</duration><voice>\(i+1)</voice></note>"
                }
            }
            xml += "</measure>"
        }
        return xml+"</part></score-partwise>"
    }
}

extension StudioViewController {
    func installV100ReleaseCandidate() {
        let s=RCStudioState.shared;guard !s.installed else{return};s.installed=true
        let live=LiveStudioState.shared;live.arrangement.isHidden=true;live.piano.isHidden=true
        arrangementCard.addSubview(s.arrangement,positioned:.above,relativeTo:nil)
        inspectorCard.addSubview(s.mixer,positioned:.above,relativeTo:nil);inspectorCard.addSubview(s.piano,positioned:.above,relativeTo:nil);inspectorCard.addSubview(s.notation,positioned:.above,relativeTo:nil);s.notation.isHidden=true
        s.mixer.fillColor=.csEditor
        setupRCToolbar();setupRCMixer();setupRCBrowser();setupRCChat();setupRCArrangement();setupRCPiano();setupRCEditorMode()
        refreshV100UI()
    }

    private func setupRCToolbar() {
        let s=RCStudioState.shared
        let items:[(String,Selector)]=[("＋ Spur",#selector(rcAddTrack)),("＋ Clip",#selector(rcAddClip)),("MIDI Import",#selector(rcImportMIDI)),("MIDI Export",#selector(rcExportMIDI)),("Duplizieren",#selector(rcDuplicateClip)),("Löschen",#selector(rcDeleteClip)),("Neu",#selector(rcNewProject))]
        for item in items { let b=NSButton(title:item.0,target:self,action:item.1);styleButton(b,strong:item.0.contains("Import") || item.0=="＋ Clip");arrangementCard.addSubview(b,positioned:.above,relativeTo:nil);s.toolbar.append(b) }
    }

    private func setupRCArrangement() {
        let s=RCStudioState.shared
        s.arrangement.onSelectTrack={[weak self] id in LiveStudioState.shared.selectedTrackID=id;self?.refreshV100UI()}
        s.arrangement.onSelectClip={[weak self] track,clip in LiveStudioState.shared.selectedTrackID=track;LiveStudioState.shared.selectedClipID=clip;self?.refreshV100UI()}
        s.arrangement.onMoveClip={[weak self] clip,start,track in CompositionStudioEngine.shared.moveClip(clip,startBeat:start,trackId:track);self?.statusLabel.stringValue="Clip verschoben";self?.refreshV100UI()}
        s.arrangement.onResizeClip={[weak self] clip,length in CompositionStudioEngine.shared.resizeClip(clip,lengthBeats:length);self?.statusLabel.stringValue="Clip skaliert";self?.refreshV100UI()}
        s.arrangement.onSeek={ beat in let e=CompositionStudioEngine.shared;e.locate(seconds:beat*60/max(20,e.tempo)) }
    }

    private func setupRCPiano() {
        let s=RCStudioState.shared
        s.piano.onAdd={[weak self] pitch,vel,start,length in guard let cid=LiveStudioState.shared.selectedClipID else{return};_ = CompositionStudioEngine.shared.addMidiNote(clipId:cid,pitch:pitch,velocity:vel,startBeat:start,lengthBeats:length);self?.statusLabel.stringValue="Note eingefügt";self?.refreshV100UI()}
        s.piano.onUpdate={[weak self] index,pitch,vel,start,length in guard let cid=LiveStudioState.shared.selectedClipID else{return};_ = CompositionStudioEngine.shared.updateMidiNote(clipId:cid,index:index,pitch:pitch,velocity:vel,startBeat:start,lengthBeats:length);self?.statusLabel.stringValue="Note verschoben";self?.refreshV100UI()}
        s.piano.onDelete={[weak self] index in guard let cid=LiveStudioState.shared.selectedClipID else{return};CompositionStudioEngine.shared.deleteMidiNote(clipId:cid,index:index);self?.statusLabel.stringValue="Note gelöscht";self?.refreshV100UI()}
        s.piano.onPreview={ pitch in guard let tid=LiveStudioState.shared.selectedTrackID else{return};let e=CompositionStudioEngine.shared;e.previewNote(trackId:tid,pitch:pitch,on:true);DispatchQueue.main.asyncAfter(deadline:.now()+0.18){e.previewNote(trackId:tid,pitch:pitch,velocity:0,on:false)} }
    }

    private func setupRCMixer() {
        let s=RCStudioState.shared
        let title=label("Mixer / Routing",size:12,weight:.bold);title.identifier=NSUserInterfaceItemIdentifier("rc_mix_title");s.mixer.addSubview(title)
        let vl=label("Lautstärke",size:10);vl.identifier=NSUserInterfaceItemIdentifier("rc_vol_label");s.mixer.addSubview(vl);s.volume.target=self;s.volume.action=#selector(rcVolumeChanged(_:));s.mixer.addSubview(s.volume)
        let pl=label("Pan",size:10);pl.identifier=NSUserInterfaceItemIdentifier("rc_pan_label");s.mixer.addSubview(pl);s.pan.target=self;s.pan.action=#selector(rcPanChanged(_:));s.mixer.addSubview(s.pan)
        let ol=label("Audio Out",size:10);ol.identifier=NSUserInterfaceItemIdentifier("rc_out_label");s.mixer.addSubview(ol);s.output.placeholderString="master";s.output.target=self;s.output.action=#selector(rcOutputChanged(_:));s.mixer.addSubview(s.output)
        let ml=label("MIDI In",size:10);ml.identifier=NSUserInterfaceItemIdentifier("rc_midi_label");s.mixer.addSubview(ml);s.midiInput.placeholderString="all oder Geräte-ID";s.midiInput.target=self;s.midiInput.action=#selector(rcMidiInputChanged(_:));s.mixer.addSubview(s.midiInput)
        s.chain.lineBreakMode=.byTruncatingTail;s.mixer.addSubview(s.chain)
    }

    private func setupRCEditorMode() {
        let s=RCStudioState.shared;s.editorMode.addItems(withTitles:["Pianoroll","Noten","MusicXML exportieren"]);s.editorMode.target=self;s.editorMode.action=#selector(rcEditorModeChanged(_:));inspectorCard.addSubview(s.editorMode,positioned:.above,relativeTo:nil)
        inspectorButtons.forEach{$0.isHidden=true};inspectorCard.subviews.filter{$0.identifier?.rawValue.hasPrefix("chain_")==true}.forEach{$0.isHidden=true};inspectorCard.subviews.filter{$0.identifier?.rawValue.hasPrefix("editor_")==true}.forEach{$0.isHidden=true}
    }

    private func setupRCBrowser() {
        let s=RCStudioState.shared
        browserList.isHidden=true
        s.pluginScroll.documentView=s.pluginContent;s.pluginScroll.hasVerticalScroller=true;s.pluginScroll.borderType=.noBorder;s.pluginScroll.drawsBackground=false;browserCard.addSubview(s.pluginScroll,positioned:.above,relativeTo:nil)
        for b in browserButtons { b.isEnabled=true;b.target=self;b.action=#selector(rcBrowserTab(_:)) }
        if let search=browserCard.subviews.compactMap({$0 as? NSSearchField}).first(where:{$0.identifier?.rawValue=="browserSearch"}) { search.isEnabled=true;search.placeholderString="Plugins suchen…";search.target=self;search.action=#selector(rcPluginSearch(_:)) }
        rebuildRCPlugins()
    }

    private func setupRCChat() {
        let s=RCStudioState.shared
        sectionButtons.forEach{$0.isHidden=true}
        chatCard.subviews.first{$0.identifier?.rawValue=="hello"}?.isHidden=true;chatCard.subviews.first{$0.identifier?.rawValue=="intro"}?.isHidden=true
        chatText.isEditable=false;chatText.string="MusicChat ist bereit. Wähle oben Claude, Gemini oder OpenAI. Mit „＋ KI“ hinterlegst du Modell und API-Schlüssel sicher im Schlüsselbund."
        chatInput.isEnabled=true;chatInput.delegate=nil;chatInput.target=self;chatInput.action=#selector(rcSendChat)
        if let send=chatCard.subviews.compactMap({$0 as? NSButton}).first(where:{$0.identifier?.rawValue=="send"}) { send.isEnabled=true;send.target=self;send.action=#selector(rcSendChat) }
        if let ai=topControls.compactMap({$0 as? NSPopUpButton}).first { ai.removeAllItems();ai.addItems(withTitles:[RCProvider.anthropic.rawValue,RCProvider.google.rawValue,RCProvider.openai.rawValue]);ai.selectItem(at:0) }
        if let ki=topControls.compactMap({$0 as? NSButton}).first(where:{$0.title.contains("KI")}) { ki.target=self;ki.action=#selector(rcConfigureAI) }
        _=s
    }

    func refreshV100UI() {
        let s=RCStudioState.shared;guard s.installed else{return};let e=CompositionStudioEngine.shared;guard e.isReady else{return}
        let tracks=e.tracks(),clips=e.clips(),live=LiveStudioState.shared
        if live.selectedTrackID==nil || !tracks.contains(where:{$0.id==live.selectedTrackID}) { live.selectedTrackID=tracks.first?.id }
        if let c=live.selectedClipID,!clips.contains(where:{$0.id==c}) { live.selectedClipID=nil }
        s.arrangement.tracks=tracks;s.arrangement.clips=clips;s.arrangement.names=Dictionary(uniqueKeysWithValues:clips.map{($0.id,e.clipName($0.id))});s.arrangement.selectedTrackID=live.selectedTrackID;s.arrangement.selectedClipID=live.selectedClipID;s.arrangement.playheadBeat=e.positionSeconds*e.tempo/60
        let selected=clips.first(where:{$0.id==live.selectedClipID});s.piano.clip=selected;s.notation.clip=selected
        if let tid=live.selectedTrackID,let t=tracks.first(where:{$0.id==tid}) {
            inspectorTitle.stringValue="Spur: \(t.name)"
            if s.volume.currentEditor()==nil { s.volume.floatValue=e.trackVolume(tid) };if s.pan.currentEditor()==nil { s.pan.floatValue=e.trackPan(tid) }
            if s.output.currentEditor()==nil { s.output.stringValue=e.trackAudioOutput(tid) };if s.midiInput.currentEditor()==nil { s.midiInput.stringValue=e.trackMidiInput(tid) }
            s.chain.stringValue=e.trackChainSummary(tid)
        } else { inspectorTitle.stringValue="Keine Spur";s.chain.stringValue="Keine Inserts" }
        if e.plugins().count != s.lastPluginCount { s.lastPluginCount=e.plugins().count;rebuildRCPlugins() }
        layoutRC()
    }

    private func layoutRC() {
        let s=RCStudioState.shared,w=arrangementCard.bounds.width
        var x:CGFloat=12
        for b in s.toolbar { let bw=max(62,min(105,CGFloat(b.title.count)*7+22));b.frame=NSRect(x:x,y:8,width:bw,height:28);x+=bw+5 }
        s.arrangement.frame=NSRect(x:8,y:42,width:max(100,w-16),height:max(80,arrangementCard.bounds.height-50))
        let iw=inspectorCard.bounds.width
        s.mixer.frame=NSRect(x:14,y:34,width:max(300,iw-28),height:72)
        s.mixer.subviews.first{$0.identifier?.rawValue=="rc_mix_title"}?.frame=NSRect(x:10,y:7,width:105,height:16)
        s.mixer.subviews.first{$0.identifier?.rawValue=="rc_vol_label"}?.frame=NSRect(x:122,y:7,width:70,height:16);s.volume.frame=NSRect(x:120,y:24,width:130,height:22)
        s.mixer.subviews.first{$0.identifier?.rawValue=="rc_pan_label"}?.frame=NSRect(x:265,y:7,width:40,height:16);s.pan.frame=NSRect(x:260,y:24,width:115,height:22)
        s.mixer.subviews.first{$0.identifier?.rawValue=="rc_out_label"}?.frame=NSRect(x:390,y:7,width:65,height:16);s.output.frame=NSRect(x:385,y:24,width:120,height:23)
        s.mixer.subviews.first{$0.identifier?.rawValue=="rc_midi_label"}?.frame=NSRect(x:520,y:7,width:55,height:16);s.midiInput.frame=NSRect(x:515,y:24,width:145,height:23)
        s.chain.frame=NSRect(x:675,y:24,width:max(80,s.mixer.bounds.width-685),height:23)
        s.editorMode.frame=NSRect(x:14,y:112,width:170,height:26)
        let editorFrame=NSRect(x:14,y:144,width:max(100,iw-28),height:max(70,inspectorCard.bounds.height-154));s.piano.frame=editorFrame;s.notation.frame=editorFrame
        let bw=browserCard.bounds.width;s.pluginScroll.frame=NSRect(x:12,y:112,width:max(100,bw-24),height:max(70,browserCard.bounds.height-124));s.pluginContent.frame=NSRect(x:0,y:0,width:s.pluginScroll.contentSize.width,height:max(s.pluginScroll.contentSize.height,CGFloat(s.pluginContent.subviews.count)*49+8))
        if let sc=chatCard.subviews.first(where:{$0.identifier?.rawValue=="chatScroll"}) { sc.frame=NSRect(x:14,y:48,width:max(100,chatCard.bounds.width-28),height:max(100,chatCard.bounds.height-105)) }
        chatInput.frame=NSRect(x:14,y:chatCard.bounds.height-48,width:max(80,chatCard.bounds.width-58),height:31);chatCard.subviews.first{$0.identifier?.rawValue=="send"}?.frame=NSRect(x:chatCard.bounds.width-39,y:chatCard.bounds.height-48,width:28,height:31)
    }

    private func rebuildRCPlugins() {
        let s=RCStudioState.shared;s.pluginContent.subviews.forEach{$0.removeFromSuperview()};let all=CompositionStudioEngine.shared.plugins();s.plugins=all
        let q=s.searchText.lowercased();let filtered=all.filter{ p in let modeOK=s.pluginMode=="Plugins" || (s.pluginMode=="Instrumente" && p.isInstrument) || (s.pluginMode=="Effekte" && !p.isInstrument);let queryOK=q.isEmpty || p.name.lowercased().contains(q) || p.format.lowercased().contains(q);return modeOK && queryOK }
        var y:CGFloat=4
        for p in filtered { let b=NSButton(title:"\(p.name)\n\(p.isInstrument ? "Instrument" : "Effekt") · \(p.format)",target:self,action:#selector(rcLoadPlugin(_:)));b.alignment=.left;b.tag=p.index;b.bezelStyle=.rounded;b.font=.systemFont(ofSize:11);s.pluginContent.addSubview(b);b.frame=NSRect(x:0,y:y,width:max(120,browserCard.bounds.width-42),height:43);y+=48 }
        if filtered.isEmpty { let l=label(s.pluginMode=="Dateien" ? "MIDI-Dateien werden über MIDI Import geladen." : "Keine passenden Plugins gefunden.",size:12,color:.secondaryLabelColor);s.pluginContent.addSubview(l);l.frame=NSRect(x:8,y:12,width:max(160,browserCard.bounds.width-52),height:40);y=60 }
        s.pluginContent.frame=NSRect(x:0,y:0,width:max(100,browserCard.bounds.width-42),height:max(y,s.pluginScroll.contentSize.height))
        browserTitle.stringValue=s.pluginMode
    }

    @objc private func rcAddTrack(){let e=CompositionStudioEngine.shared;let id=e.createTrack(name:"MIDI Spur \(e.tracks().count+1)");if id>=0{LiveStudioState.shared.selectedTrackID=id;statusLabel.stringValue="Spur angelegt"};refreshV100UI()}
    @objc private func rcAddClip(){guard let tid=LiveStudioState.shared.selectedTrackID else{statusLabel.stringValue="Zuerst eine Spur auswählen";return};let e=CompositionStudioEngine.shared,start=rcQuantize(e.positionSeconds*e.tempo/60,4);let id=e.createMidiClip(trackId:tid,startBeat:start,lengthBeats:16,name:"MIDI Clip");if id>=0{LiveStudioState.shared.selectedClipID=id;statusLabel.stringValue="MIDI-Clip angelegt"};refreshV100UI()}
    @objc private func rcDeleteClip(){guard let id=LiveStudioState.shared.selectedClipID else{return};CompositionStudioEngine.shared.deleteClip(id);LiveStudioState.shared.selectedClipID=nil;statusLabel.stringValue="Clip gelöscht";refreshV100UI()}
    @objc private func rcDuplicateClip(){guard let id=LiveStudioState.shared.selectedClipID else{return};let n=CompositionStudioEngine.shared.duplicateClip(id);if n>=0{LiveStudioState.shared.selectedClipID=n;statusLabel.stringValue="Clip dupliziert"};refreshV100UI()}
    @objc private func rcNewProject(){let alert=NSAlert();alert.messageText="Neues Projekt";alert.informativeText="Das aktuelle Projekt wird verworfen. Falls nötig, vorher speichern.";alert.addButton(withTitle:"Neu anlegen");alert.addButton(withTitle:"Abbrechen");guard alert.runModal()==.alertFirstButtonReturn else{return};if CompositionStudioEngine.shared.newProject(){LiveStudioState.shared.selectedTrackID=nil;LiveStudioState.shared.selectedClipID=nil;model.projectName="Unbenannt";projectLabel.stringValue="Projekt: Unbenannt";statusLabel.stringValue="Neues Projekt";refreshV100UI()}}
    @objc private func rcImportMIDI(){let p=NSOpenPanel();p.allowedContentTypes=[.midi];p.allowsMultipleSelection=false;guard let w=view.window else{return};p.beginSheetModal(for:w){[weak self] r in guard r==.OK,let u=p.url,let self else{return};let id=CompositionStudioEngine.shared.importMIDIMultitrack(path:u.path,startBeat:0);if id>=0{let c=CompositionStudioEngine.shared.clips().first(where:{$0.id==id});LiveStudioState.shared.selectedClipID=id;LiveStudioState.shared.selectedTrackID=c?.trackId;self.statusLabel.stringValue="MIDI importiert"}else{self.statusLabel.stringValue="MIDI-Import fehlgeschlagen"};self.refreshV100UI()}}
    @objc private func rcExportMIDI(){let p=NSSavePanel();p.allowedContentTypes=[.midi];p.nameFieldStringValue=(LiveStudioState.shared.selectedClipID != nil ? "MIDI-Clip.mid":"Projekt.mid");guard let w=view.window else{return};p.beginSheetModal(for:w){[weak self] r in guard r==.OK,let u=p.url,let self else{return};let e=CompositionStudioEngine.shared;let ok=LiveStudioState.shared.selectedClipID.map{e.exportClipMIDI($0,to:u.path)} ?? e.exportProjectMIDI(to:u.path);self.statusLabel.stringValue=ok ? "MIDI exportiert":"MIDI-Export fehlgeschlagen"}}
    @objc private func rcVolumeChanged(_ v:NSSlider){guard let id=LiveStudioState.shared.selectedTrackID else{return};CompositionStudioEngine.shared.setTrackVolume(id,v.floatValue)}
    @objc private func rcPanChanged(_ v:NSSlider){guard let id=LiveStudioState.shared.selectedTrackID else{return};CompositionStudioEngine.shared.setTrackPan(id,v.floatValue)}
    @objc private func rcOutputChanged(_ f:NSTextField){guard let id=LiveStudioState.shared.selectedTrackID else{return};CompositionStudioEngine.shared.setTrackAudioOutput(id,f.stringValue.isEmpty ? "master":f.stringValue);statusLabel.stringValue="Routing aktualisiert"}
    @objc private func rcMidiInputChanged(_ f:NSTextField){guard let id=LiveStudioState.shared.selectedTrackID else{return};CompositionStudioEngine.shared.setTrackMidiInput(id,f.stringValue);statusLabel.stringValue="MIDI-Eingang aktualisiert"}
    @objc private func rcBrowserTab(_ b:NSButton){RCStudioState.shared.pluginMode=b.title;rebuildRCPlugins()}
    @objc private func rcPluginSearch(_ f:NSSearchField){RCStudioState.shared.searchText=f.stringValue;rebuildRCPlugins()}
    @objc private func rcLoadPlugin(_ b:NSButton){guard let tid=LiveStudioState.shared.selectedTrackID else{statusLabel.stringValue="Zuerst eine Spur auswählen";return};guard let plugin=RCStudioState.shared.plugins.first(where:{$0.index==b.tag}) else{return};let id=CompositionStudioEngine.shared.addPlugin(trackId:tid,pluginIndex:plugin.index);statusLabel.stringValue=id>=0 ? "\(plugin.name) geladen":"Plugin konnte nicht geladen werden";refreshV100UI()}
    @objc private func rcEditorModeChanged(_ p:NSPopUpButton){let s=RCStudioState.shared;if p.indexOfSelectedItem==0{s.piano.isHidden=false;s.notation.isHidden=true}else if p.indexOfSelectedItem==1{s.piano.isHidden=true;s.notation.isHidden=false}else{p.selectItem(at:1);s.piano.isHidden=true;s.notation.isHidden=false;rcExportMusicXML()}}
    private func rcExportMusicXML(){guard let id=LiveStudioState.shared.selectedClipID,let clip=CompositionStudioEngine.shared.clips().first(where:{$0.id==id}) else{statusLabel.stringValue="Zuerst einen MIDI-Clip auswählen";return};let p=NSSavePanel();if let t=UTType(filenameExtension:"musicxml"){p.allowedContentTypes=[t]};p.nameFieldStringValue=CompositionStudioEngine.shared.clipName(id)+".musicxml";guard let w=view.window else{return};p.beginSheetModal(for:w){[weak self] r in guard r==.OK,let u=p.url,let self else{return};let xml=RCMusicXML.document(clip:clip,title:CompositionStudioEngine.shared.clipName(id),tempo:CompositionStudioEngine.shared.tempo);do{try xml.write(to:u,atomically:true,encoding:.utf8);self.statusLabel.stringValue="MusicXML exportiert"}catch{self.statusLabel.stringValue="MusicXML-Export fehlgeschlagen"}}}

    private func currentRCProvider()->RCProvider { let title=topControls.compactMap{$0 as? NSPopUpButton}.first?.titleOfSelectedItem ?? RCProvider.anthropic.rawValue;return RCProvider(rawValue:title) ?? .anthropic }
    private func rcModel(for provider:RCProvider)->String { UserDefaults.standard.string(forKey:"CompositionStudio.Model.\(provider.account)") ?? provider.defaultModel }
    @objc private func rcConfigureAI(){let provider=currentRCProvider();let alert=NSAlert();alert.messageText="\(provider.rawValue) – Zugang";alert.informativeText="Der API-Schlüssel wird im macOS-Schlüsselbund gespeichert.";alert.addButton(withTitle:"Speichern");alert.addButton(withTitle:"Abbrechen");let box=NSView(frame:NSRect(x:0,y:0,width:390,height:82));let ml=label("Modell",size:11);ml.frame=NSRect(x:0,y:56,width:70,height:20);let modelField=NSTextField(string:rcModel(for:provider));modelField.frame=NSRect(x:75,y:52,width:315,height:24);let kl=label("API-Schlüssel",size:11);kl.frame=NSRect(x:0,y:20,width:75,height:20);let key= NSSecureTextField(string:RCKeychain.read(provider.account) ?? "");key.frame=NSRect(x:75,y:16,width:315,height:24);[ml,modelField,kl,key].forEach{box.addSubview($0)};alert.accessoryView=box;guard alert.runModal()==.alertFirstButtonReturn else{return};let k=key.stringValue.trimmingCharacters(in:.whitespacesAndNewlines),m=modelField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);if !k.isEmpty{RCKeychain.write(k,account:provider.account)};if !m.isEmpty{UserDefaults.standard.set(m,forKey:"CompositionStudio.Model.\(provider.account)")};statusLabel.stringValue="KI-Zugang gespeichert"}

    @objc private func rcSendChat(){let s=RCStudioState.shared;guard !s.chatBusy else{return};let text=chatInput.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else{return};let provider=currentRCProvider();guard let key=RCKeychain.read(provider.account),!key.isEmpty else{statusLabel.stringValue="Für \(provider.rawValue) zuerst API-Schlüssel über ＋ KI speichern";rcConfigureAI();return};chatText.string += "\n\nDu: \(text)\n\n\(provider.rawValue): …";chatInput.stringValue="";s.chatBusy=true;statusLabel.stringValue="KI arbeitet…";let prompt=rcProjectContext()+"\n\nNutzerauftrag:\n"+text;RCAIClient.request(provider:provider,model:rcModel(for:provider),key:key,system:rcAISystemPrompt(),prompt:prompt){[weak self] result in guard let self else{return};s.chatBusy=false;switch result{case .failure(let error):self.chatText.string += "\nFehler: \(error.localizedDescription)";self.statusLabel.stringValue="KI-Fehler";case .success(let raw):let (visible,actions)=self.rcExtractActions(raw);self.chatText.string += "\n"+visible;if let actions{let count=self.rcApplyActions(actions);self.statusLabel.stringValue=count>0 ? "KI-Antwort · \(count) Studio-Änderungen angewendet":"KI-Antwort"}else{self.statusLabel.stringValue="KI-Antwort"};self.refreshV100UI()}}
    }

    private func rcProjectContext()->String { let e=CompositionStudioEngine.shared,tracks=e.tracks(),clips=e.clips();var lines=["Projektkontext Composition Studio","Tempo: \(String(format:"%.2f",e.tempo)) BPM","Spuren: "+tracks.map{"\($0.id):\($0.name)"}.joined(separator:", ")];if let cid=LiveStudioState.shared.selectedClipID,let c=clips.first(where:{$0.id==cid}){let notes=c.notes.prefix(300).map{"p\($0.note) v\($0.velocity) s\(String(format:"%.3f",$0.startBeat)) l\(String(format:"%.3f",$0.lengthBeats))"}.joined(separator:"; ");lines.append("Ausgewählter Clip: id=\(c.id), Spur=\(c.trackId), Start=\(c.startBeat), Länge=\(c.lengthBeats), Name=\(e.clipName(c.id))");lines.append("Noten: \(notes)")}else{lines.append("Kein MIDI-Clip ausgewählt.")};return lines.joined(separator:"\n")}
    private func rcAISystemPrompt()->String { """
Du bist MusicChat innerhalb von Composition Studio. Du arbeitest als musikalischer Dialogpartner und Kompositionsassistent. Halte den musikalischen Auftrag des Nutzers offen und eigenständig; füge keine stilistischen Regeln hinzu, die der Nutzer nicht verlangt hat. Besprich Analyse, Idee und Gestaltung normal in Textform.
Wenn der Nutzer eine konkrete Änderung oder Komposition im Studio verlangt und eine direkte Ausführung sinnvoll ist, hänge GENAU EINEN Block in dieser Form an:
<composition-studio-actions>{"actions":[...]}</composition-studio-actions>
Zulässige Aktionen: {"op":"setTempo","bpm":120}; {"op":"createTrack","name":"Cello","id":"cello"}; {"op":"createClip","track":"cello","startBeat":0,"lengthBeats":16,"name":"Thema","id":"thema"}; {"op":"clearClip","clipId":12}; {"op":"addNote","clip":"thema","pitch":60,"velocity":90,"startBeat":0,"lengthBeats":1}; {"op":"deleteClip","clipId":12}; {"op":"moveClip","clipId":12,"startBeat":8,"trackId":3}; {"op":"renameTrack","trackId":3,"name":"Violine"}; {"op":"setMixer","trackId":3,"volume":0.8,"pan":-0.2}.
Bei createTrack/createClip dürfen die id-Felder lokale Text-Aliase für spätere Aktionen desselben Blocks sein. Für bestehende Elemente verwende numerische IDs aus dem Projektkontext. Erzeuge nur Änderungen, die der Nutzer tatsächlich verlangt. Der Text außerhalb des Blocks soll verständlich erklären, was du musikalisch getan oder vorgeschlagen hast.
""" }
    private func rcExtractActions(_ raw:String)->(String,String?){let a="<composition-studio-actions>",b="</composition-studio-actions>";guard let r1=raw.range(of:a),let r2=raw.range(of:b,range:r1.upperBound..<raw.endIndex) else{return(raw,nil)};let json=String(raw[r1.upperBound..<r2.lowerBound]);var visible=raw;visible.removeSubrange(r1.lowerBound..<r2.upperBound);return(visible.trimmingCharacters(in:.whitespacesAndNewlines),json)}
    private func rcApplyActions(_ json:String)->Int { guard let data=json.data(using:.utf8),let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let actions=root["actions"] as? [[String:Any]] else{return 0};let e=CompositionStudioEngine.shared;var trackAliases:[String:Int]=[:],clipAliases:[String:Int]=[:],count=0
        func intValue(_ v:Any?)->Int?{if let n=v as? NSNumber{return n.intValue};if let s=v as? String{return Int(s)};return nil}
        func doubleValue(_ v:Any?)->Double?{if let n=v as? NSNumber{return n.doubleValue};if let s=v as? String{return Double(s)};return nil}
        func resolveTrack(_ a:[String:Any])->Int?{if let id=intValue(a["trackId"]){return id};if let key=a["track"] as? String{if let id=trackAliases[key]{return id};if let t=e.tracks().first(where:{$0.name.caseInsensitiveCompare(key)==.orderedSame}){return t.id}};return LiveStudioState.shared.selectedTrackID}
        func resolveClip(_ a:[String:Any])->Int?{if let id=intValue(a["clipId"]){return id};if let key=a["clip"] as? String,let id=clipAliases[key]{return id};return LiveStudioState.shared.selectedClipID}
        for a in actions { guard let op=a["op"] as? String else{continue};switch op {
        case "setTempo":if let bpm=doubleValue(a["bpm"]){e.setTempo(bpm);count+=1}
        case "createTrack":if let name=a["name"] as? String{let id=e.createTrack(name:name);if id>=0{if let alias=a["id"] as? String{trackAliases[alias]=id};LiveStudioState.shared.selectedTrackID=id;count+=1}}
        case "createClip":if let tid=resolveTrack(a){let id=e.createMidiClip(trackId:tid,startBeat:doubleValue(a["startBeat"]) ?? 0,lengthBeats:doubleValue(a["lengthBeats"]) ?? 16,name:(a["name"] as? String) ?? "MIDI Clip");if id>=0{if let alias=a["id"] as? String{clipAliases[alias]=id};LiveStudioState.shared.selectedTrackID=tid;LiveStudioState.shared.selectedClipID=id;count+=1}}
        case "clearClip":if let cid=resolveClip(a){e.clearMidiNotes(cid);count+=1}
        case "addNote":if let cid=resolveClip(a),let pitch=intValue(a["pitch"]){if e.addMidiNote(clipId:cid,pitch:pitch,velocity:intValue(a["velocity"]) ?? 90,startBeat:doubleValue(a["startBeat"]) ?? 0,lengthBeats:doubleValue(a["lengthBeats"]) ?? 1){count+=1}}
        case "deleteClip":if let cid=resolveClip(a){e.deleteClip(cid);if LiveStudioState.shared.selectedClipID==cid{LiveStudioState.shared.selectedClipID=nil};count+=1}
        case "moveClip":if let cid=resolveClip(a){let existing=e.clips().first(where:{$0.id==cid});let tid=resolveTrack(a) ?? existing?.trackId ?? -1;e.moveClip(cid,startBeat:doubleValue(a["startBeat"]) ?? existing?.startBeat ?? 0,trackId:tid);count+=1}
        case "renameTrack":if let tid=resolveTrack(a),let name=a["name"] as? String{e.setTrackName(id:tid,name:name);count+=1}
        case "setMixer":if let tid=resolveTrack(a){if let v=doubleValue(a["volume"]){e.setTrackVolume(tid,Float(v))};if let p=doubleValue(a["pan"]){e.setTrackPan(tid,Float(p))};count+=1}
        default:break }
        }
        return count
    }
}
