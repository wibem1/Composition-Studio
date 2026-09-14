import AppKit
import UniformTypeIdentifiers

final class StudioModel: NSObject {
    var selectedTrack = 2
    var selectedRegion = 2
    var projectName = "Abendlicht"
    var tracks = ["Piano", "Violine", "Cello", "Holzbläser", "Synth Pads", "Percussion", "Audio"]
    var regions = ["Piano – Thema", "Violine – Melodie", "Cello – Begleitung", "Holzbläser – Flächen", "Pads", "Percussion", "Ambience"]
}

private extension NSColor {
    static let csWindow = NSColor(calibratedRed: 0.885, green: 0.925, blue: 0.965, alpha: 1)
    static let csTop = NSColor(calibratedRed: 0.955, green: 0.975, blue: 0.995, alpha: 1)
    static let csPanel = NSColor(calibratedRed: 0.972, green: 0.985, blue: 0.998, alpha: 1)
    static let csPanelStrong = NSColor(calibratedRed: 0.915, green: 0.945, blue: 0.975, alpha: 1)
    static let csArrangement = NSColor(calibratedRed: 0.885, green: 0.925, blue: 0.965, alpha: 1)
    static let csEditor = NSColor(calibratedRed: 0.945, green: 0.968, blue: 0.990, alpha: 1)
    static let csTransport = NSColor(calibratedRed: 0.900, green: 0.935, blue: 0.970, alpha: 1)
    static let csLine = NSColor(calibratedRed: 0.71, green: 0.78, blue: 0.86, alpha: 1)
    static let csText = NSColor(calibratedRed: 0.055, green: 0.11, blue: 0.20, alpha: 1)
    static let csBlue = NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.92, alpha: 1)
    static let csGreen = NSColor(calibratedRed: 0.05, green: 0.63, blue: 0.36, alpha: 1)
}

private final class FlippedView: NSView { override var isFlipped: Bool { true } }

private final class CardView: FlippedView {
    var fillColor: NSColor = .csPanel
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        fillColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8).fill()
        NSColor.csLine.setStroke()
        let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        p.lineWidth = 1
        p.stroke()
    }
}

private func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .csText) -> NSTextField {
    let f = NSTextField(labelWithString: text)
    f.font = .systemFont(ofSize: size, weight: weight)
    f.textColor = color
    f.lineBreakMode = .byTruncatingTail
    return f
}

private func styleButton(_ b: NSButton, strong: Bool = false) {
    b.bezelStyle = .rounded
    b.font = .systemFont(ofSize: 11, weight: strong ? .semibold : .regular)
    if strong { b.contentTintColor = .csBlue }
}

private final class ArrangementView: FlippedView {
    let model: StudioModel
    var selectionChanged: (() -> Void)?
    var regionChanged: (() -> Void)?
    private let colors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemYellow, .systemPurple, .systemTeal, .systemGray]

    init(model: StudioModel) { self.model = model; super.init(frame: .zero); wantsLayer = true }
    required init?(coder: NSCoder) { fatalError() }

    private func text(_ s: String, _ r: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .csText, align: NSTextAlignment = .left) {
        let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byTruncatingTail
        (s as NSString).draw(in: r, withAttributes: [.font:NSFont.systemFont(ofSize:size, weight:weight), .foregroundColor:color, .paragraphStyle:p])
    }
    private func fill(_ r: NSRect, _ c: NSColor, radius: CGFloat = 0) { c.setFill(); radius > 0 ? NSBezierPath(roundedRect:r, xRadius:radius, yRadius:radius).fill() : r.fill() }
    private func line(_ a: NSPoint, _ b: NSPoint, _ c: NSColor, _ w: CGFloat = 1) { c.setStroke(); let p=NSBezierPath(); p.move(to:a); p.line(to:b); p.lineWidth=w; p.stroke() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        fill(bounds, .csArrangement)
        let headerW: CGFloat = 164
        let top: CGFloat = 58
        fill(NSRect(x:0,y:0,width:headerW,height:bounds.height), .csPanelStrong)
        fill(NSRect(x:headerW,y:0,width:bounds.width-headerW,height:top), .csTop)
        line(NSPoint(x:headerW,y:0), NSPoint(x:headerW,y:bounds.height), .csLine)
        line(NSPoint(x:0,y:top), NSPoint(x:bounds.width,y:top), .csLine)
        text("◫  ◧  ↔  ⊕  ⌁", NSRect(x:12,y:11,width:130,height:18), size:11, color:.secondaryLabelColor)

        let tx = headerW
        let tw = bounds.width - headerW
        for i in 0...9 {
            let x = tx + CGFloat(i) * tw / 9
            text("\(1+i*4)", NSRect(x:x-10,y:5,width:28,height:15), size:9, color:.secondaryLabelColor, align:.center)
            line(NSPoint(x:x,y:top), NSPoint(x:x,y:bounds.height), NSColor(calibratedWhite:0.79, alpha:0.48))
        }
        let sections: [(String,NSColor)] = [
            ("A – Einführung", NSColor(calibratedRed:0.74,green:0.94,blue:0.89,alpha:1)),
            ("B – Entwicklung", NSColor(calibratedRed:0.72,green:0.84,blue:0.98,alpha:1)),
            ("C – Höhepunkt", NSColor(calibratedRed:0.99,green:0.78,blue:0.75,alpha:1)),
            ("D – Ausklang", NSColor(calibratedRed:0.82,green:0.75,blue:0.96,alpha:1))]
        for i in 0..<4 {
            let x = tx + CGFloat(i)*tw/4
            fill(NSRect(x:x,y:24,width:tw/4,height:34), sections[i].1)
            text(sections[i].0, NSRect(x:x,y:34,width:tw/4,height:16), size:10, weight:.medium, align:.center)
        }

        let n = max(1, model.tracks.count)
        let rowH = (bounds.height-top)/CGFloat(n)
        for i in 0..<n {
            let y = top + CGFloat(i)*rowH
            let selected = i == model.selectedTrack
            fill(NSRect(x:0,y:y,width:headerW,height:rowH), selected ? NSColor(calibratedRed:0.82,green:0.90,blue:0.98,alpha:1) : .csPanelStrong)
            fill(NSRect(x:8,y:y+7,width:16,height:rowH-14), colors[i % colors.count], radius:3)
            text("\(i+1)", NSRect(x:9,y:y+18,width:14,height:14), size:10, weight:.bold, color:.white, align:.center)
            text(model.tracks[i], NSRect(x:33,y:y+8,width:118,height:18), size:11, weight:.semibold)
            text("M   S    ●", NSRect(x:33,y:y+29,width:90,height:16), size:10, color:.secondaryLabelColor)
            line(NSPoint(x:0,y:y+rowH), NSPoint(x:bounds.width,y:y+rowH), NSColor(calibratedWhite:0.78,alpha:0.58))

            let start = tx + 12 + CGFloat((i % 3) * 18)
            let width = max(80, tw * (i == 3 ? 0.68 : (i == 5 ? 0.60 : 0.83)))
            let rc = colors[i % colors.count]
            let regionRect = NSRect(x:start,y:y+7,width:min(width,tw-24),height:rowH-14)
            fill(regionRect, rc.withAlphaComponent(model.selectedRegion == i ? 0.28 : 0.18), radius:5)
            if model.selectedRegion == i { rc.setStroke(); let p=NSBezierPath(roundedRect:regionRect,xRadius:5,yRadius:5); p.lineWidth=1.5; p.stroke() }
            let title = i < model.regions.count ? model.regions[i] : "Region"
            text(title, NSRect(x:start+8,y:y+10,width:regionRect.width-16,height:15), size:10, weight:.medium)
            if model.tracks[i] == "Audio" {
                var xx=start+10; while xx < regionRect.maxX-8 { let a=CGFloat((Int(xx)/5)%18)+3; line(NSPoint(x:xx,y:y+rowH/2-a/2),NSPoint(x:xx,y:y+rowH/2+a/2),.systemGray); xx += 3 }
            } else if model.tracks[i] == "Percussion" {
                var xx=start+12; while xx < regionRect.maxX-10 { line(NSPoint(x:xx,y:y+26),NSPoint(x:xx,y:y+42),rc,1.3); xx += 14 }
            } else {
                var xx=start+10; var step=0; while xx < regionRect.maxX-18 { let yy=y+rowH/2+CGFloat((step*7+i*5)%22)-11; line(NSPoint(x:xx,y:yy),NSPoint(x:xx+16,y:yy),rc,1.5); xx += 20; step += 1 }
            }
        }
        let playX = tx + tw*0.46
        line(NSPoint(x:playX,y:top),NSPoint(x:playX,y:bounds.height),NSColor(calibratedRed:0.05,green:0.16,blue:0.33,alpha:1),1.3)
        fill(NSRect(x:playX-4,y:top-4,width:8,height:8),NSColor(calibratedRed:0.05,green:0.16,blue:0.33,alpha:1),radius:4)
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from:nil)
        let top: CGFloat = 58; let headerW: CGFloat = 164
        guard p.y >= top, model.tracks.count > 0 else { return }
        let rowH = (bounds.height-top)/CGFloat(model.tracks.count)
        let row = min(model.tracks.count-1, max(0, Int((p.y-top)/rowH)))
        model.selectedTrack = row
        if p.x > headerW { model.selectedRegion = row; regionChanged?() }
        selectionChanged?(); needsDisplay = true
    }
}

private final class PianoRollView: FlippedView {
    var selectedTrackName = "Cello" { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.csEditor.setFill(); bounds.fill()
        let keyW: CGFloat = 48; let top: CGFloat = 22
        NSColor(calibratedRed:0.91,green:0.94,blue:0.97,alpha:1).setFill(); NSRect(x:0,y:top,width:keyW,height:bounds.height-top).fill()
        NSColor.csLine.setStroke(); let border=NSBezierPath(rect:bounds.insetBy(dx:0.5,dy:0.5)); border.lineWidth=1; border.stroke()
        for i in 0...16 {
            let x=keyW+CGFloat(i)*(bounds.width-keyW)/16
            NSColor(calibratedWhite:0.75,alpha:0.45).setStroke(); let p=NSBezierPath(); p.move(to:NSPoint(x:x,y:top)); p.line(to:NSPoint(x:x,y:bounds.height)); p.stroke()
            if i<16 { ("\(i+1)" as NSString).draw(in:NSRect(x:x+3,y:3,width:24,height:14),withAttributes:[.font:NSFont.systemFont(ofSize:8),.foregroundColor:NSColor.secondaryLabelColor]) }
        }
        for i in 0...6 {
            let y=top+CGFloat(i)*(bounds.height-top)/6
            NSColor(calibratedWhite:0.78,alpha:0.5).setStroke(); let p=NSBezierPath(); p.move(to:NSPoint(x:0,y:y)); p.line(to:NSPoint(x:bounds.width,y:y)); p.stroke()
        }
        (selectedTrackName as NSString).draw(in:NSRect(x:6,y:3,width:120,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:10,weight:.semibold),.foregroundColor:NSColor.csText])
        let green=NSColor(calibratedRed:0.08,green:0.68,blue:0.36,alpha:1)
        for i in 0..<15 {
            let x=keyW+18+CGFloat(i)*((bounds.width-keyW-55)/15)
            let y=top+18+CGFloat((i*3)%5)*18
            green.setFill(); NSBezierPath(roundedRect:NSRect(x:x,y:y,width:46,height:6),xRadius:3,yRadius:3).fill()
        }
    }
}

final class StudioViewController: NSViewController, NSTextFieldDelegate {
    private let model = StudioModel()
    private let topBar = CardView(); private let chatCard = CardView(); private let arrangementCard = CardView(); private let browserCard = CardView(); private let inspectorCard = CardView(); private let transportCard = CardView()
    private lazy var arrangement = ArrangementView(model:model)
    private let pianoRoll = PianoRollView()
    private let chatText = NSTextView(); private let chatInput = NSTextField(); private let browserList = FlippedView(); private let statusLabel = label("Gespeichert",size:11,color:.csGreen)
    private let projectLabel = label("Projekt: Abendlicht",size:11,weight:.medium)
    private let inspectorTitle = label("Spur: Cello",size:13,weight:.bold)
    private let timeLabel = label("00:00.000",size:17,weight:.medium)
    private let browserTitle = label("Plugins",size:13,weight:.bold,color:.csBlue)
    private let tracksBox = FlippedView()
    private var browserButtons:[NSButton]=[]
    private var topControls:[NSView]=[]
    private var inspectorButtons:[NSButton]=[]
    private var sectionButtons:[NSButton]=[]
    private let playButton=NSButton(title:"▶",target:nil,action:nil); private let stopButton=NSButton(title:"■",target:nil,action:nil); private let recordButton=NSButton(title:"●",target:nil,action:nil)

    override func loadView() {
        view = FlippedView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.csWindow.cgColor
        buildUI()
    }

    private func add(_ child:NSView,to parent:NSView){ parent.addSubview(child) }
    private func button(_ title:String,_ action:Selector,strong:Bool=false)->NSButton{ let b=NSButton(title:title,target:self,action:action); styleButton(b,strong:strong); return b }

    private func buildUI() {
        topBar.fillColor = .csTop; chatCard.fillColor = .csPanel; arrangementCard.fillColor = .csArrangement; browserCard.fillColor = .csPanel; inspectorCard.fillColor = .csPanelStrong; transportCard.fillColor = .csTransport
        [topBar,chatCard,arrangementCard,browserCard,inspectorCard,transportCard].forEach{view.addSubview($0)}

        let brand=label("COMPOSITION STUDIO",size:18,weight:.bold); let by=label("by Klangwerke",size:10,color:.secondaryLabelColor); let dot=label("●",size:12,color:.csGreen)
        let ai=NSPopUpButton(); ai.addItems(withTitles:["Claude 3.5 Sonnet","Gemini","OpenAI"]); ai.font=.systemFont(ofSize:11)
        let ki=button("＋ KI",#selector(focusChat),strong:true); let browser=button("▣ Browser",#selector(focusBrowser),strong:true); let display=button("Darstellung",#selector(displayAction))
        topControls=[brand,by,projectLabel,dot,statusLabel,ai,ki,browser,display]; topControls.forEach{topBar.addSubview($0)}

        let tabs=[button("KI-Dialog",#selector(chatTab(_:)),strong:true),button("Verlauf",#selector(chatTab(_:))),button("Ideen",#selector(chatTab(_:))]
        tabs.forEach{chatCard.addSubview($0)}
        let hello=label("Hallo!",size:17,weight:.bold); let intro=label("Ich bin dein musikalischer Partner.\nWir können gemeinsam komponieren, Arrangements entwickeln, Spuren bearbeiten oder neue Ideen ausprobieren.\n\nWas möchtest du heute tun?",size:12)
        intro.maximumNumberOfLines=8; intro.lineBreakMode=.byWordWrapping
        chatCard.addSubview(hello); chatCard.addSubview(intro)
        chatText.isEditable=false; chatText.font=.systemFont(ofSize:11); chatText.backgroundColor=.clear; chatText.string=""
        let scroll=NSScrollView(); scroll.documentView=chatText; scroll.hasVerticalScroller=true; scroll.borderType=.noBorder; scroll.drawsBackground=false; chatCard.addSubview(scroll); scroll.identifier=NSUserInterfaceItemIdentifier("chatScroll")
        let prompts=["Eine neue Komposition im kammermusikalischen Stil erstellen","Nur die Cellostimme überarbeiten","Drei Varianten für den Mittelteil erzeugen","Harmonische Alternativen vorschlagen","Diese Passage analysieren"]
        for p in prompts { let b=button(p,#selector(promptPressed(_:))); b.alignment=.left; sectionButtons.append(b); chatCard.addSubview(b) }
        chatInput.placeholderString="Schreibe eine Nachricht…"; chatInput.delegate=self; chatCard.addSubview(chatInput); let send=button("➤",#selector(sendChat),strong:true); chatCard.addSubview(send); send.identifier=NSUserInterfaceItemIdentifier("send")
        hello.identifier=NSUserInterfaceItemIdentifier("hello"); intro.identifier=NSUserInterfaceItemIdentifier("intro")

        arrangementCard.addSubview(arrangement)
        let plus=button("＋",#selector(addTrack)); let minus=button("−",#selector(removeTrack)); plus.identifier=NSUserInterfaceItemIdentifier("arrPlus"); minus.identifier=NSUserInterfaceItemIdentifier("arrMinus"); arrangementCard.addSubview(plus); arrangementCard.addSubview(minus)
        arrangement.selectionChanged={ [weak self] in self?.selectionChanged() }; arrangement.regionChanged={ [weak self] in self?.statusLabel.stringValue="Region ausgewählt" }

        let browserTabs=[button("Plugins",#selector(browserTab(_:)),strong:true),button("Dateien",#selector(browserTab(_:))),button("Instrumente",#selector(browserTab(_:))),button("Effekte",#selector(browserTab(_:))]
        browserTabs.forEach{browserCard.addSubview($0); browserButtons.append($0)}
        browserCard.addSubview(browserTitle)
        let search=NSSearchField(); search.placeholderString="Suchen…"; browserCard.addSubview(search); search.identifier=NSUserInterfaceItemIdentifier("browserSearch")
        browserCard.addSubview(browserList)
        rebuildBrowserList()

        inspectorCard.addSubview(inspectorTitle)
        let sections=["Routing","Instrumente","Effekte","MIDI Einstellungen","Audio Einstellungen","Notizen"]
        for s in sections { let b=button(s,#selector(inspectorSection(_:)),strong:s=="Routing"); b.alignment=.left; inspectorButtons.append(b); inspectorCard.addSubview(b) }
        let chainTitles=["MIDI Eingang","MIDI Verarbeitung","Instrument / Plugin","Audio Effekte","Audio Ausgang"]
        for t in chainTitles { let v=CardView(); v.fillColor=.csEditor; v.identifier=NSUserInterfaceItemIdentifier("chain_\(t)"); let h=label(t,size:11,weight:.semibold); v.addSubview(h); h.frame=NSRect(x:10,y:9,width:130,height:16); inspectorCard.addSubview(v) }
        let editorTabs=["Pianoroll","Velocity","Controller","Notenexpression","Skalen","Akkorde"]
        for (i,t) in editorTabs.enumerated(){ let b=button(t,#selector(editorTab(_:)),strong:i==0); b.identifier=NSUserInterfaceItemIdentifier("editor_\(i)"); inspectorCard.addSubview(b) }
        inspectorCard.addSubview(pianoRoll)

        let undo=button("↶",#selector(genericAction(_:))); let redo=button("↷",#selector(genericAction(_:))); transportCard.addSubview(undo); transportCard.addSubview(redo)
        transportCard.addSubview(timeLabel); let bars=label("13 . 1 . 1 . 0",size:14,weight:.medium); transportCard.addSubview(bars); bars.identifier=NSUserInterfaceItemIdentifier("bars")
        [stopButton,playButton,recordButton].forEach{ styleButton($0,strong:true); transportCard.addSubview($0) }; recordButton.contentTintColor=.systemRed
        let tempo=label("Tempo\n120.00",size:10); let meter=label("Taktart\n4/4",size:10); let metro=button("♩ Metronom",#selector(genericAction(_:))); transportCard.addSubview(tempo); transportCard.addSubview(meter); transportCard.addSubview(metro); tempo.identifier=NSUserInterfaceItemIdentifier("tempo"); meter.identifier=NSUserInterfaceItemIdentifier("meter")
        let open=button("Öffnen",#selector(openProject)); let save=button("Speichern",#selector(saveProject)); transportCard.addSubview(open); transportCard.addSubview(save); open.identifier=NSUserInterfaceItemIdentifier("open"); save.identifier=NSUserInterfaceItemIdentifier("save")

        selectionChanged()
    }

    private func rebuildBrowserList() {
        browserList.subviews.forEach{$0.removeFromSuperview()}
        let items=[("Pianoteq","Modartt"),("Vital","Spectral Synthesizer"),("Kontakt 7","Native Instruments"),("Valhalla Supermassive","Valhalla DSP"),("FabFilter Pro-Q 3","FabFilter"),("Scaler 2","Plugin Boutique"),("Soothe2","oeksound"),("RX 11","iZotope")]
        for (i,item) in items.enumerated(){ let b=button("\(item.0)\n\(item.1)",#selector(browserItem(_:))); b.alignment=.left; b.identifier=NSUserInterfaceItemIdentifier("plugin_\(i)"); browserList.addSubview(b) }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let W=view.bounds.width, H=view.bounds.height
        let margin:CGFloat=8, gap:CGFloat=7, topH:CGFloat=50, transportH:CGFloat=58
        let chatW=max(300,min(330,W*0.205)), browserW=max(315,min(350,W*0.225))
        let contentTop=margin+topH+gap, bottomY=H-margin-transportH
        topBar.frame=NSRect(x:margin,y:margin,width:W-2*margin,height:topH)
        chatCard.frame=NSRect(x:margin,y:contentTop,width:chatW,height:bottomY-contentTop-gap)
        browserCard.frame=NSRect(x:W-margin-browserW,y:contentTop,width:browserW,height:bottomY-contentTop-gap)
        let centerX=margin+chatW+gap, centerW=W-2*margin-chatW-browserW-2*gap
        let centerH=bottomY-contentTop-gap, arrH=max(390,centerH*0.58)
        arrangementCard.frame=NSRect(x:centerX,y:contentTop,width:centerW,height:arrH)
        inspectorCard.frame=NSRect(x:centerX,y:contentTop+arrH+gap,width:centerW,height:centerH-arrH-gap)
        transportCard.frame=NSRect(x:margin,y:bottomY,width:W-2*margin,height:transportH)
        layoutTop(); layoutChat(); layoutArrangement(); layoutBrowser(); layoutInspector(); layoutTransport()
    }

    private func layoutTop(){ guard topControls.count==9 else{return}; let h=topBar.bounds.height; topControls[0].frame=NSRect(x:18,y:13,width:225,height:24); topControls[1].frame=NSRect(x:214,y:17,width:90,height:18); topControls[2].frame=NSRect(x:topBar.bounds.width*0.31,y:17,width:135,height:18); topControls[3].frame=NSRect(x:topBar.bounds.width*0.40,y:17,width:14,height:18); topControls[4].frame=NSRect(x:topBar.bounds.width*0.412,y:17,width:90,height:18); topControls[5].frame=NSRect(x:topBar.bounds.width-535,y:10,width:150,height:28); topControls[6].frame=NSRect(x:topBar.bounds.width-375,y:10,width:62,height:28); topControls[7].frame=NSRect(x:topBar.bounds.width-305,y:10,width:92,height:28); topControls[8].frame=NSRect(x:topBar.bounds.width-205,y:10,width:100,height:28); _=h }

    private func layoutChat(){ let w=chatCard.bounds.width; let tabs=chatCard.subviews.compactMap{$0 as? NSButton}.filter{$0.title=="KI-Dialog"||$0.title=="Verlauf"||$0.title=="Ideen"}; for (i,b) in tabs.enumerated(){b.frame=NSRect(x:12+CGFloat(i)*82,y:10,width:78,height:28)}; chatCard.subviews.first{$0.identifier?.rawValue=="hello"}?.frame=NSRect(x:62,y:58,width:w-78,height:24); chatCard.subviews.first{$0.identifier?.rawValue=="intro"}?.frame=NSRect(x:62,y:85,width:w-78,height:112); if let sc=chatCard.subviews.first(where:{$0.identifier?.rawValue=="chatScroll"}){sc.frame=NSRect(x:14,y:205,width:w-28,height:72)}; var y:CGFloat=286; for b in sectionButtons{b.frame=NSRect(x:14,y:y,width:w-28,height:38); y+=45}; let send=chatCard.subviews.first{$0.identifier?.rawValue=="send"}; chatInput.frame=NSRect(x:14,y:chatCard.bounds.height-48,width:w-58,height:31); send?.frame=NSRect(x:w-39,y:chatCard.bounds.height-48,width:28,height:31) }

    private func layoutArrangement(){ arrangement.frame=NSRect(x:8,y:8,width:arrangementCard.bounds.width-16,height:arrangementCard.bounds.height-16); arrangementCard.subviews.first{$0.identifier?.rawValue=="arrPlus"}?.frame=NSRect(x:arrangementCard.bounds.width-72,y:12,width:27,height:24); arrangementCard.subviews.first{$0.identifier?.rawValue=="arrMinus"}?.frame=NSRect(x:arrangementCard.bounds.width-42,y:12,width:27,height:24) }

    private func layoutBrowser(){ let w=browserCard.bounds.width; let tabs=browserButtons.prefix(4); for (i,b) in tabs.enumerated(){b.frame=NSRect(x:10+CGFloat(i)*(w-20)/4,y:10,width:(w-24)/4,height:28)}; browserTitle.frame=NSRect(x:14,y:48,width:140,height:22); browserCard.subviews.first{$0.identifier?.rawValue=="browserSearch"}?.frame=NSRect(x:12,y:74,width:w-24,height:30); browserList.frame=NSRect(x:12,y:112,width:w-24,height:browserCard.bounds.height-124); let bs=browserList.subviews.compactMap{$0 as? NSButton}; var y:CGFloat=0; for b in bs{b.frame=NSRect(x:0,y:y,width:browserList.bounds.width,height:52); y+=58} }

    private func layoutInspector(){ let w=inspectorCard.bounds.width,h=inspectorCard.bounds.height; let side:CGFloat=170; inspectorTitle.frame=NSRect(x:15,y:12,width:145,height:20); var y:CGFloat=42; for b in inspectorButtons{b.frame=NSRect(x:12,y:y,width:145,height:27); y+=29}; let chain=inspectorCard.subviews.compactMap{$0 as? CardView}.filter{$0.identifier?.rawValue.hasPrefix("chain_")==true}; let chainX=side+8, chainY:CGFloat=14, chainGap:CGFloat=7; let each=(w-chainX-14-chainGap*4)/5; for (i,v) in chain.enumerated(){v.frame=NSRect(x:chainX+CGFloat(i)*(each+chainGap),y:chainY,width:each,height:78); if let l=v.subviews.first as? NSTextField{l.frame=NSRect(x:8,y:8,width:each-16,height:18)}}; let tabs=inspectorCard.subviews.compactMap{$0 as? NSButton}.filter{$0.identifier?.rawValue.hasPrefix("editor_")==true}.sorted{$0.identifier!.rawValue<$1.identifier!.rawValue}; let tabY:CGFloat=101; var x=chainX; for b in tabs{let ww=max(62,CGFloat(b.title.count)*7+20); b.frame=NSRect(x:x,y:tabY,width:ww,height:25); x+=ww+4}; pianoRoll.frame=NSRect(x:chainX,y:132,width:w-chainX-12,height:max(80,h-142)) }

    private func layoutTransport(){ let w=transportCard.bounds.width; let undo=transportCard.subviews.compactMap{$0 as? NSButton}.first{$0.title=="↶"}; let redo=transportCard.subviews.compactMap{$0 as? NSButton}.first{$0.title=="↷"}; undo?.frame=NSRect(x:10,y:15,width:32,height:28); redo?.frame=NSRect(x:45,y:15,width:32,height:28); timeLabel.frame=NSRect(x:w*0.22,y:15,width:110,height:27); transportCard.subviews.first{$0.identifier?.rawValue=="bars"}?.frame=NSRect(x:w*0.31,y:17,width:100,height:23); stopButton.frame=NSRect(x:w*0.46-44,y:12,width:34,height:34); playButton.frame=NSRect(x:w*0.46,y:9,width:40,height:40); recordButton.frame=NSRect(x:w*0.46+48,y:9,width:40,height:40); transportCard.subviews.first{$0.identifier?.rawValue=="tempo"}?.frame=NSRect(x:w*0.62,y:11,width:72,height:37); transportCard.subviews.first{$0.identifier?.rawValue=="meter"}?.frame=NSRect(x:w*0.69,y:11,width:62,height:37); let metro=transportCard.subviews.compactMap{$0 as? NSButton}.first{$0.title.contains("Metronom")}; metro?.frame=NSRect(x:w*0.76,y:14,width:100,height:30); transportCard.subviews.first{$0.identifier?.rawValue=="open"}?.frame=NSRect(x:w-170,y:14,width:72,height:30); transportCard.subviews.first{$0.identifier?.rawValue=="save"}?.frame=NSRect(x:w-92,y:14,width:78,height:30) }

    private func selectionChanged(){ guard model.selectedTrack>=0,model.selectedTrack<model.tracks.count else{return}; let n=model.tracks[model.selectedTrack]; inspectorTitle.stringValue="Spur: \(n)"; pianoRoll.selectedTrackName=n; statusLabel.stringValue="\(n) ausgewählt" }
    @objc private func addTrack(){ model.tracks.append("Neue Spur \(model.tracks.count+1)"); model.regions.append("Neue Region"); model.selectedTrack=model.tracks.count-1; model.selectedRegion=model.selectedTrack; arrangement.needsDisplay=true; selectionChanged(); statusLabel.stringValue="Spur hinzugefügt" }
    @objc private func removeTrack(){ guard model.tracks.count>1 else{return}; let i=min(model.selectedTrack,model.tracks.count-1); model.tracks.remove(at:i); if i<model.regions.count{model.regions.remove(at:i)}; model.selectedTrack=max(0,min(i,model.tracks.count-1)); model.selectedRegion=model.selectedTrack; arrangement.needsDisplay=true; selectionChanged(); statusLabel.stringValue="Spur gelöscht" }
    @objc private func promptPressed(_ s:NSButton){ chatInput.stringValue=s.title; chatInput.window?.makeFirstResponder(chatInput) }
    @objc private func sendChat(){ let t=chatInput.stringValue.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return}; chatText.string += (chatText.string.isEmpty ? "" : "\n\n") + "Du: \(t)\nComposition Studio: Auftrag übernommen. Die gewählte Spur und Region bleiben im aktuellen Arbeitskontext."; chatInput.stringValue=""; statusLabel.stringValue="KI-Auftrag erfasst" }
    func controlTextDidEndEditing(_ obj:Notification){ sendChat() }
    @objc private func chatTab(_ s:NSButton){ statusLabel.stringValue=s.title; if s.title=="Verlauf"{chatText.string="Verlauf\n\nNoch keine gespeicherten KI-Schritte."} else if s.title=="Ideen"{chatText.string="Ideen\n\nHier werden musikalische Ideen gesammelt."} }
    @objc private func focusChat(){ chatInput.window?.makeFirstResponder(chatInput) }
    @objc private func focusBrowser(){ statusLabel.stringValue="Browser aktiv" }
    @objc private func displayAction(){ statusLabel.stringValue="Darstellung" }
    @objc private func browserTab(_ s:NSButton){ browserTitle.stringValue=s.title; statusLabel.stringValue="Browser: \(s.title)" }
    @objc private func browserItem(_ s:NSButton){ statusLabel.stringValue="\(s.title.components(separatedBy:"\n").first ?? s.title) ausgewählt" }
    @objc private func inspectorSection(_ s:NSButton){ statusLabel.stringValue="Inspector: \(s.title)" }
    @objc private func editorTab(_ s:NSButton){ statusLabel.stringValue="Editor: \(s.title)" }
    @objc private func genericAction(_ s:NSButton){ statusLabel.stringValue=s.title }

    @objc private func saveProject(){ let p=NSSavePanel(); p.allowedContentTypes=[.json]; p.nameFieldStringValue=model.projectName+".json"; guard let w=view.window else{return}; p.beginSheetModal(for:w){[weak self]r in guard r==.OK,let u=p.url,let self else{return}; let d:[String:Any]=["project":self.model.projectName,"tracks":self.model.tracks,"regions":self.model.regions,"selectedTrack":self.model.selectedTrack]; if let data=try? JSONSerialization.data(withJSONObject:d,options:.prettyPrinted){try? data.write(to:u);self.statusLabel.stringValue="Gespeichert"} } }
    @objc private func openProject(){ let p=NSOpenPanel(); p.allowedContentTypes=[.json]; guard let w=view.window else{return}; p.beginSheetModal(for:w){[weak self]r in guard r==.OK,let u=p.url,let self,let data=try? Data(contentsOf:u),let d=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{return}; if let t=d["tracks"] as? [String],!t.isEmpty{self.model.tracks=t}; if let rr=d["regions"] as? [String]{self.model.regions=rr}; if let n=d["project"] as? String{self.model.projectName=n;self.projectLabel.stringValue="Projekt: \(n)"}; self.model.selectedTrack=min((d["selectedTrack"] as? Int) ?? 0,self.model.tracks.count-1); self.model.selectedRegion=self.model.selectedTrack; self.arrangement.needsDisplay=true; self.selectionChanged(); self.statusLabel.stringValue="Geladen" } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window:NSWindow?
    func applicationDidFinishLaunching(_ notification:Notification){ let vc=StudioViewController(); let w=NSWindow(contentRect:NSRect(x:0,y:0,width:1540,height:960),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false); w.title="Composition Studio"; w.minSize=NSSize(width:1280,height:780); w.center(); w.contentViewController=vc; w.makeKeyAndOrderFront(nil); window=w; NSApp.activate(ignoringOtherApps:true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}

let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
app.run()
