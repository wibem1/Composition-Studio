import AppKit
import UniformTypeIdentifiers

final class StudioModel: NSObject {
    var selectedTrack = "Cello"
    var projectName = "Abendlicht"
}

private extension NSColor {
    static let csBackground = NSColor(calibratedRed: 0.93, green: 0.96, blue: 0.985, alpha: 1)
    static let csPanel = NSColor(calibratedRed: 0.975, green: 0.988, blue: 1.0, alpha: 1)
    static let csLine = NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.91, alpha: 1)
    static let csText = NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.22, alpha: 1)
    static let csBlue = NSColor(calibratedRed: 0.16, green: 0.48, blue: 0.94, alpha: 1)
    static let csGreen = NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.39, alpha: 1)
}

private func drawText(_ text: String, _ rect: NSRect, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .csText, alignment: NSTextAlignment = .left) {
    let p = NSMutableParagraphStyle()
    p.alignment = alignment
    p.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: p
    ]
    (text as NSString).draw(in: rect, withAttributes: attrs)
}

final class StudioCanvas: NSView {
    var selectedTrack = 2 { didSet { needsDisplay = true } }

    private let tracks = ["Piano", "Violine", "Cello", "Holzbläser", "Synth Pads", "Percussion", "Audio"]
    private let trackColors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemYellow, .systemPurple, .systemTeal, .systemGray]

    override var isFlipped: Bool { true }

    private func fill(_ rect: NSRect, _ color: NSColor, radius: CGFloat = 0) {
        color.setFill()
        if radius > 0 { NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill() }
        else { rect.fill() }
    }

    private func stroke(_ rect: NSRect, _ color: NSColor = .csLine, radius: CGFloat = 8, width: CGFloat = 1) {
        color.setStroke()
        let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        p.lineWidth = width
        p.stroke()
    }

    private func panel(_ rect: NSRect, radius: CGFloat = 8) {
        fill(rect, .csPanel, radius: radius)
        stroke(rect, radius: radius)
    }

    private func line(_ a: NSPoint, _ b: NSPoint, color: NSColor, width: CGFloat = 1) {
        color.setStroke()
        let p = NSBezierPath()
        p.move(to: a); p.line(to: b); p.lineWidth = width; p.stroke()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        fill(bounds, .csBackground)

        let W = bounds.width
        let H = bounds.height
        let topH: CGFloat = 44
        let transportH: CGFloat = 56
        let browserW: CGFloat = max(290, W * 0.225)
        let chatW: CGFloat = max(300, W * 0.205)
        let gap: CGFloat = 6
        let midX = chatW + gap
        let rightX = W - browserW
        let centerW = rightX - midX - gap
        let arrangementH = max(460, (H - topH - transportH) * 0.63)
        let inspectorTop = topH + gap + arrangementH + gap
        let inspectorH = H - inspectorTop - transportH - gap

        // top bar
        fill(NSRect(x: 0, y: 0, width: W, height: topH), NSColor(calibratedWhite: 0.985, alpha: 1))
        line(NSPoint(x: 0, y: topH), NSPoint(x: W, y: topH), color: .csLine)
        fill(NSRect(x: 12, y: 9, width: 26, height: 26), NSColor(calibratedRed: 0.86, green: 0.92, blue: 1, alpha: 1), radius: 7)
        drawText("◉", NSRect(x: 18, y: 12, width: 16, height: 18), size: 15, weight: .bold, color: .csBlue)
        drawText("COMPOSITION STUDIO", NSRect(x: 48, y: 8, width: 220, height: 24), size: 17, weight: .bold)
        drawText("by Klangwerke", NSRect(x: 236, y: 12, width: 105, height: 18), size: 11, color: .secondaryLabelColor)
        drawText("Projekt: Abendlicht", NSRect(x: W * 0.29, y: 13, width: 150, height: 18), size: 11)
        fill(NSRect(x: W * 0.39, y: 17, width: 8, height: 8), .systemGreen, radius: 4)
        drawText("Gespeichert", NSRect(x: W * 0.397, y: 13, width: 90, height: 18), size: 11, color: NSColor(calibratedRed: 0.08, green: 0.25, blue: 0.45, alpha: 1))

        // left chat
        let chatRect = NSRect(x: 6, y: topH + gap, width: chatW - 6, height: H - topH - transportH - 2 * gap)
        panel(chatRect)
        let tabsY = chatRect.minY + 10
        drawText("KI-Dialog", NSRect(x: 22, y: tabsY, width: 80, height: 22), size: 12, weight: .semibold, color: .csBlue)
        drawText("Verlauf", NSRect(x: 115, y: tabsY, width: 60, height: 22), size: 12)
        drawText("Ideen", NSRect(x: 195, y: tabsY, width: 55, height: 22), size: 12)
        line(NSPoint(x: 18, y: tabsY + 29), NSPoint(x: 110, y: tabsY + 29), color: .csBlue, width: 2)
        drawText("⚙", NSRect(x: chatRect.maxX - 34, y: tabsY, width: 24, height: 22), size: 14)

        fill(NSRect(x: 20, y: tabsY + 48, width: 40, height: 40), NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.93, alpha: 1), radius: 10)
        drawText("✦", NSRect(x: 31, y: tabsY + 56, width: 22, height: 24), size: 19, weight: .bold, color: .white)
        drawText("Hallo!", NSRect(x: 70, y: tabsY + 49, width: 100, height: 26), size: 17, weight: .bold)
        drawText("Ich bin dein musikalischer Partner.\nWir können gemeinsam komponieren,\nArrangements entwickeln, Spuren\nbearbeiten oder neue Ideen ausprobieren.\nWas möchtest du heute tun?", NSRect(x: 70, y: tabsY + 78, width: chatW - 95, height: 102), size: 12)

        let prompts = [
            "Eine neue Komposition im\nkammermusikalischen Stil erstellen",
            "Nur die Cellostimme überarbeiten",
            "Drei Varianten für den Mittelteil erzeugen",
            "Harmonische Alternativen vorschlagen",
            "Diese Passage analysieren"
        ]
        var py = tabsY + 198
        for (i, p) in prompts.enumerated() {
            let h: CGFloat = i == 0 ? 54 : 38
            fill(NSRect(x: 20, y: py, width: chatW - 42, height: h), NSColor(calibratedWhite: 0.995, alpha: 1), radius: 7)
            stroke(NSRect(x: 20, y: py, width: chatW - 42, height: h), radius: 7)
            drawText(p, NSRect(x: 34, y: py + 9, width: chatW - 70, height: h - 12), size: 11)
            py += h + 8
        }

        // arrangement area
        let arr = NSRect(x: midX, y: topH + gap, width: centerW, height: arrangementH)
        panel(arr)
        let headerH: CGFloat = 56
        let trackHeaderW: CGFloat = 158
        fill(NSRect(x: arr.minX + 1, y: arr.minY + 1, width: trackHeaderW, height: arr.height - 2), NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1), radius: 8)
        line(NSPoint(x: arr.minX + trackHeaderW, y: arr.minY), NSPoint(x: arr.minX + trackHeaderW, y: arr.maxY), color: .csLine)

        // arrangement toolbar + ruler
        drawText("◫  ◧  ↔  ⊕  ⌁", NSRect(x: arr.minX + 13, y: arr.minY + 9, width: 130, height: 22), size: 12, color: .secondaryLabelColor)
        let timelineX = arr.minX + trackHeaderW
        let timelineW = arr.width - trackHeaderW - 10
        let rulerY = arr.minY + 28
        for i in 0...9 {
            let x = timelineX + CGFloat(i) * timelineW / 9
            drawText("\(1 + i * 4)", NSRect(x: x - 8, y: rulerY - 10, width: 25, height: 16), size: 9, color: .secondaryLabelColor, alignment: .center)
            line(NSPoint(x: x, y: arr.minY + headerH), NSPoint(x: x, y: arr.maxY - 10), color: NSColor(calibratedWhite: 0.86, alpha: 1))
        }
        let sections: [(String, NSColor)] = [
            ("A – Einführung", NSColor(calibratedRed: 0.79, green: 0.96, blue: 0.92, alpha: 1)),
            ("B – Entwicklung", NSColor(calibratedRed: 0.81, green: 0.88, blue: 1.0, alpha: 1)),
            ("C – Höhepunkt", NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.82, alpha: 1)),
            ("D – Ausklang", NSColor(calibratedRed: 0.88, green: 0.82, blue: 1.0, alpha: 1))
        ]
        for i in 0..<4 {
            let x = timelineX + CGFloat(i) * timelineW / 4
            fill(NSRect(x: x, y: arr.minY + 28, width: timelineW / 4, height: 28), sections[i].1)
            drawText(sections[i].0, NSRect(x: x, y: arr.minY + 34, width: timelineW / 4, height: 16), size: 10, weight: .medium, alignment: .center)
        }

        let rowH: CGFloat = (arr.height - headerH - 18) / 7
        let regionNames = ["Piano – Thema", "Violine – Melodie", "Cello – Begleitung", "Holzbläser – Flächen", "Pads", "Percussion", "Ambience"]
        for i in 0..<7 {
            let y = arr.minY + headerH + CGFloat(i) * rowH
            if i == selectedTrack { fill(NSRect(x: arr.minX + 4, y: y + 2, width: trackHeaderW - 8, height: rowH - 4), NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.0, alpha: 1), radius: 5) }
            fill(NSRect(x: arr.minX + 8, y: y + 8, width: 15, height: rowH - 16), trackColors[i], radius: 3)
            drawText("\(i + 1)", NSRect(x: arr.minX + 10, y: y + 17, width: 12, height: 18), size: 10, weight: .bold, color: .white, alignment: .center)
            drawText(tracks[i], NSRect(x: arr.minX + 32, y: y + 8, width: 104, height: 20), size: 11, weight: .semibold)
            drawText("M   S    ●", NSRect(x: arr.minX + 32, y: y + 30, width: 90, height: 18), size: 10, color: .secondaryLabelColor)
            line(NSPoint(x: arr.minX + 4, y: y + rowH), NSPoint(x: arr.maxX - 8, y: y + rowH), color: NSColor(calibratedWhite: 0.91, alpha: 1))

            let start = timelineX + 10 + CGFloat((i % 3) * 18)
            let width = timelineW * (i == 3 ? 0.68 : (i == 5 ? 0.60 : 0.82))
            let base = trackColors[i].withAlphaComponent(i == 6 ? 0.18 : 0.16)
            fill(NSRect(x: start, y: y + 8, width: width, height: rowH - 16), base, radius: 4)
            drawText(regionNames[i], NSRect(x: start + 8, y: y + 11, width: width - 16, height: 16), size: 10, weight: .medium)
            if i == 6 {
                var xx = start + 10
                while xx < start + width - 10 {
                    let amp = CGFloat((Int(xx) / 7) % 16) + 3
                    line(NSPoint(x: xx, y: y + rowH / 2 - amp / 2), NSPoint(x: xx, y: y + rowH / 2 + amp / 2), color: .systemGray, width: 1)
                    xx += 3
                }
            } else if i == 5 {
                var xx = start + 12
                while xx < start + width - 12 {
                    line(NSPoint(x: xx, y: y + 25), NSPoint(x: xx, y: y + 40), color: trackColors[i], width: 1.4)
                    xx += 14
                }
            } else {
                var xx = start + 10
                var step = 0
                while xx < start + width - 12 {
                    let yy = y + 31 + CGFloat((step * 7 + i * 4) % 21) - 10
                    line(NSPoint(x: xx, y: yy), NSPoint(x: xx + 16, y: yy), color: trackColors[i], width: 1.5)
                    xx += 20
                    step += 1
                }
            }
        }
        let playheadX = timelineX + timelineW * 0.46
        line(NSPoint(x: playheadX, y: arr.minY + headerH), NSPoint(x: playheadX, y: arr.maxY - 12), color: NSColor(calibratedRed: 0.05, green: 0.17, blue: 0.34, alpha: 1), width: 1.2)
        fill(NSRect(x: playheadX - 4, y: arr.minY + headerH - 4, width: 8, height: 8), NSColor(calibratedRed: 0.05, green: 0.17, blue: 0.34, alpha: 1), radius: 4)

        // browser
        let br = NSRect(x: rightX, y: topH + gap, width: browserW - 6, height: H - topH - transportH - 2 * gap)
        panel(br)
        drawText("Plugins", NSRect(x: br.minX + 16, y: br.minY + 10, width: 70, height: 24), size: 12, weight: .semibold, color: .csBlue)
        drawText("Dateien", NSRect(x: br.minX + 95, y: br.minY + 10, width: 55, height: 24), size: 11)
        drawText("Instrumente", NSRect(x: br.minX + 158, y: br.minY + 10, width: 80, height: 24), size: 11)
        drawText("Effekte", NSRect(x: br.minX + 247, y: br.minY + 10, width: 55, height: 24), size: 11)
        line(NSPoint(x: br.minX + 12, y: br.minY + 39), NSPoint(x: br.minX + 80, y: br.minY + 39), color: .csBlue, width: 2)
        drawText("☆  Favoriten", NSRect(x: br.minX + 20, y: br.minY + 84, width: 120, height: 20), size: 11, weight: .semibold)
        for (j, c) in ["Alle Plugins", "VST3", "VST2", "AU", "Instrumente", "Effekte", "Zuletzt verwendet"].enumerated() {
            drawText("◫  \(c)", NSRect(x: br.minX + 22, y: br.minY + 112 + CGFloat(j) * 25, width: 150, height: 20), size: 11)
        }
        let plugins = [("Pianoteq", "Modartt"), ("Vital", "Spectral Synthesizer"), ("Kontakt 7", "Native Instruments"), ("Valhalla Supermassive", "Valhalla DSP"), ("FabFilter Pro-Q 3", "FabFilter"), ("Scaler 2", "Plugin Boutique"), ("Soothe2", "oeksound"), ("RX 11", "iZotope")]
        var by = br.minY + 300
        for (idx, p) in plugins.enumerated() {
            fill(NSRect(x: br.minX + 20, y: by, width: 42, height: 42), trackColors[idx % trackColors.count].withAlphaComponent(0.82), radius: 5)
            drawText(p.0, NSRect(x: br.minX + 74, y: by + 2, width: br.width - 105, height: 18), size: 11, weight: .semibold)
            drawText(p.1, NSRect(x: br.minX + 74, y: by + 20, width: br.width - 105, height: 17), size: 10, color: .secondaryLabelColor)
            drawText("☆", NSRect(x: br.maxX - 32, y: by + 10, width: 20, height: 20), size: 13, color: .secondaryLabelColor)
            by += 48
        }

        // inspector + piano roll
        let insp = NSRect(x: midX, y: inspectorTop, width: centerW, height: inspectorH)
        panel(insp)
        let sideW: CGFloat = 170
        fill(NSRect(x: insp.minX + 1, y: insp.minY + 1, width: sideW, height: insp.height - 2), NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1), radius: 8)
        fill(NSRect(x: insp.minX + 1, y: insp.minY + 1, width: 5, height: insp.height - 2), .systemGreen, radius: 3)
        drawText("Spur: Cello", NSRect(x: insp.minX + 18, y: insp.minY + 14, width: 130, height: 20), size: 13, weight: .bold)
        let menu = ["Routing", "Instrumente", "Effekte", "MIDI Einstellungen", "Audio Einstellungen", "Notizen"]
        for (i, m) in menu.enumerated() {
            let yy = insp.minY + 52 + CGFloat(i) * 29
            if i == 0 { fill(NSRect(x: insp.minX + 8, y: yy - 4, width: sideW - 16, height: 27), NSColor(calibratedRed: 0.82, green: 0.90, blue: 1.0, alpha: 1), radius: 5) }
            drawText("▣  \(m)", NSRect(x: insp.minX + 18, y: yy, width: sideW - 30, height: 18), size: 10)
        }
        drawText("🎻", NSRect(x: insp.minX + 62, y: insp.minY + 218, width: 45, height: 45), size: 30, alignment: .center)

        let routeY = insp.minY + 15
        let routeX = insp.minX + sideW + 12
        let routeW = insp.width - sideW - 24
        let boxW = routeW / 5 - 8
        let routeTitles = ["MIDI Eingang", "MIDI Verarbeitung", "Instrument / Plugin", "Audio Effekte", "Audio Ausgang"]
        for i in 0..<5 {
            let x = routeX + CGFloat(i) * (boxW + 10)
            drawText(routeTitles[i], NSRect(x: x, y: routeY, width: boxW, height: 18), size: 10, weight: .semibold)
            fill(NSRect(x: x, y: routeY + 26, width: boxW, height: 74), .white, radius: 5)
            stroke(NSRect(x: x, y: routeY + 26, width: boxW, height: 74), radius: 5)
            if i < 4 { drawText("➜", NSRect(x: x + boxW, y: routeY + 50, width: 18, height: 20), size: 17, weight: .bold, color: i % 2 == 0 ? .csGreen : .csBlue) }
        }
        drawText("Alle Eingänge\nKanal: Alle", NSRect(x: routeX + 10, y: routeY + 39, width: boxW - 20, height: 50), size: 10)
        drawText("MIDI FX\nTranspose     Velocity", NSRect(x: routeX + boxW + 22, y: routeY + 39, width: boxW - 20, height: 50), size: 10)
        drawText("🎹  Pianoteq 8\n      Plugin öffnen", NSRect(x: routeX + 2*(boxW + 10) + 10, y: routeY + 39, width: boxW - 20, height: 50), size: 10, weight: .medium)
        drawText("Compressor\nEQ\nReverb", NSRect(x: routeX + 3*(boxW + 10) + 10, y: routeY + 34, width: boxW - 20, height: 62), size: 10)
        drawText("Master\n-6.0 dB", NSRect(x: routeX + 4*(boxW + 10) + 10, y: routeY + 39, width: boxW - 20, height: 50), size: 10)

        let rollY = insp.minY + 125
        drawText("Pianoroll", NSRect(x: routeX + 12, y: rollY, width: 70, height: 21), size: 11, weight: .semibold, color: .csBlue)
        drawText("Velocity     Controller     Notenexpression     Skalen     Akkorde", NSRect(x: routeX + 100, y: rollY, width: routeW - 110, height: 21), size: 10)
        line(NSPoint(x: routeX, y: rollY + 25), NSPoint(x: routeX + routeW, y: rollY + 25), color: .csLine)
        let pianoX = routeX
        let gridY = rollY + 28
        let gridH = max(80, insp.maxY - gridY - 10)
        fill(NSRect(x: pianoX, y: gridY, width: routeW, height: gridH), .white)
        for i in 0...16 {
            let x = pianoX + 52 + CGFloat(i) * (routeW - 52) / 16
            line(NSPoint(x: x, y: gridY), NSPoint(x: x, y: gridY + gridH), color: NSColor(calibratedWhite: 0.89, alpha: 1))
            if i < 16 { drawText("\(i + 1)", NSRect(x: x + 2, y: gridY + 3, width: 20, height: 14), size: 8, color: .secondaryLabelColor) }
        }
        for i in 0...7 {
            let y = gridY + CGFloat(i) * gridH / 7
            line(NSPoint(x: pianoX, y: y), NSPoint(x: pianoX + routeW, y: y), color: NSColor(calibratedWhite: 0.90, alpha: 1))
        }
        drawText("C4\n\n\nC3", NSRect(x: pianoX + 4, y: gridY + 18, width: 42, height: gridH - 22), size: 8, color: .secondaryLabelColor)
        for n in 0..<15 {
            let nx = pianoX + 58 + CGFloat(n) * (routeW - 82) / 15
            let ny = gridY + 25 + CGFloat((n * 3 + 2) % 5) * 13
            fill(NSRect(x: nx, y: ny, width: 46, height: 5), .systemGreen, radius: 2)
        }

        // bottom transport
        let tr = NSRect(x: 6, y: H - transportH, width: W - 12, height: transportH - 6)
        panel(tr)
        drawText("↺     ↶     ↷     ⟳", NSRect(x: tr.minX + 14, y: tr.minY + 17, width: 170, height: 20), size: 14, color: NSColor(calibratedRed: 0.06, green: 0.17, blue: 0.30, alpha: 1))
        drawText("13 . 1 . 1 . 0", NSRect(x: W * 0.30, y: tr.minY + 15, width: 120, height: 24), size: 15, weight: .medium)
        drawText("Tempo\n120.00", NSRect(x: W * 0.58, y: tr.minY + 7, width: 70, height: 38), size: 10)
        drawText("Taktart\n4/4", NSRect(x: W * 0.66, y: tr.minY + 7, width: 60, height: 38), size: 10)
        drawText("♩  Metronom", NSRect(x: W * 0.74, y: tr.minY + 16, width: 110, height: 20), size: 10)
        drawText("▰   ☰", NSRect(x: tr.maxX - 95, y: tr.minY + 16, width: 80, height: 20), size: 14)
    }
}

final class StudioViewController: NSViewController, NSTextFieldDelegate {
    private let model = StudioModel()
    private let canvas = StudioCanvas()
    private let chatInput = NSTextField()
    private let search = NSSearchField()
    private let modelPopup = NSPopUpButton()
    private let playButton = NSButton(title: "▶", target: nil, action: nil)
    private let stopButton = NSButton(title: "■", target: nil, action: nil)
    private let recordButton = NSButton(title: "●", target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "00:00.000")
    private let statusLabel = NSTextField(labelWithString: "Gespeichert")
    private let browserTitle = NSTextField(labelWithString: "Plugins")

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.csBackground.cgColor
        canvas.autoresizingMask = [.width, .height]
        view.addSubview(canvas)
        setupControls()
    }

    private func setupControls() {
        modelPopup.addItems(withTitles: ["Claude 3.5 Sonnet", "Gemini", "OpenAI"])
        modelPopup.controlSize = .small
        view.addSubview(modelPopup)

        chatInput.placeholderString = "Schreibe eine Nachricht..."
        chatInput.delegate = self
        chatInput.bezelStyle = .roundedBezel
        view.addSubview(chatInput)

        search.placeholderString = "Suchen..."
        search.controlSize = .small
        view.addSubview(search)

        for b in [stopButton, playButton, recordButton] {
            b.bezelStyle = .circular
            b.font = .systemFont(ofSize: 16, weight: .semibold)
            view.addSubview(b)
        }
        playButton.contentTintColor = .systemGreen
        recordButton.contentTintColor = .systemRed
        stopButton.target = self; stopButton.action = #selector(stopPressed)
        playButton.target = self; playButton.action = #selector(playPressed)
        recordButton.target = self; recordButton.action = #selector(recordPressed)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        view.addSubview(timeLabel)
        statusLabel.isHidden = true
        browserTitle.isHidden = true
        view.addSubview(statusLabel)
        view.addSubview(browserTitle)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        canvas.frame = view.bounds
        let W = view.bounds.width
        let H = view.bounds.height
        let browserW = max(290, W * 0.225)
        let chatW = max(300, W * 0.205)
        let topH: CGFloat = 44
        let transportH: CGFloat = 56

        modelPopup.frame = NSRect(x: W * 0.49, y: 9, width: 148, height: 26)
        chatInput.frame = NSRect(x: 20, y: H - transportH - 73, width: chatW - 68, height: 34)
        let send = view.subviews.compactMap { $0 as? NSButton }.first(where: { $0.identifier?.rawValue == "send" })
        if send == nil {
            let b = NSButton(title: "➤", target: self, action: #selector(sendChat))
            b.identifier = NSUserInterfaceItemIdentifier("send")
            b.bezelStyle = .rounded
            view.addSubview(b)
        }
        view.subviews.compactMap { $0 as? NSButton }.first(where: { $0.identifier?.rawValue == "send" })?.frame = NSRect(x: chatW - 42, y: H - transportH - 73, width: 30, height: 34)

        search.frame = NSRect(x: W - browserW + 14, y: topH + 48, width: browserW - 34, height: 30)

        let baseX = W * 0.40
        timeLabel.frame = NSRect(x: baseX - 170, y: H - 40, width: 130, height: 24)
        stopButton.frame = NSRect(x: baseX + 55, y: H - 45, width: 34, height: 34)
        playButton.frame = NSRect(x: baseX + 100, y: H - 48, width: 40, height: 40)
        recordButton.frame = NSRect(x: baseX + 150, y: H - 45, width: 34, height: 34)
        statusLabel.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        browserTitle.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
    }

    @objc private func playPressed() { statusLabel.stringValue = "Wiedergabe" }
    @objc private func stopPressed() { statusLabel.stringValue = "Bereit"; timeLabel.stringValue = "00:00.000" }
    @objc private func recordPressed() { statusLabel.stringValue = "Aufnahme" }
    @objc private func sendChat() {
        let text = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput.stringValue = ""
        statusLabel.stringValue = "KI-Auftrag übernommen"
    }
    func controlTextDidEndEditing(_ obj: Notification) { if obj.object as AnyObject === chatInput { sendChat() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = StudioViewController()
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1600, height: 1000), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Composition Studio"
        w.center()
        w.minSize = NSSize(width: 1280, height: 800)
        w.contentViewController = vc
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
