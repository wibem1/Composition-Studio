import AppKit

final class StudioModel: NSObject {
    var isPlaying = false
    var elapsed: TimeInterval = 0
    var timer: Timer?
    var selectedTrack = "Cello"
    var projectName = "Abendlicht"
    var tracks = ["Piano", "Violine", "Cello", "Holzbläser", "Synth Pads", "Percussion", "Audio"]
}

final class StudioViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let model = StudioModel()
    private let bg = NSColor(calibratedRed: 0.93, green: 0.96, blue: 0.985, alpha: 1)
    private let panel = NSColor(calibratedRed: 0.975, green: 0.988, blue: 1.0, alpha: 1)
    private let line = NSColor(calibratedRed: 0.79, green: 0.84, blue: 0.89, alpha: 1)
    private let blue = NSColor(calibratedRed: 0.18, green: 0.49, blue: 0.91, alpha: 1)
    private let green = NSColor(calibratedRed: 0.08, green: 0.69, blue: 0.42, alpha: 1)

    private let trackTable = NSTableView()
    private let inspectorTitle = NSTextField(labelWithString: "Cello")
    private let timeLabel = NSTextField(labelWithString: "00:00.000")
    private let playButton = NSButton(title: "▶", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Gespeichert")
    private let chatLog = NSTextView()
    private let chatInput = NSTextField()
    private let browserTitle = NSTextField(labelWithString: "Plugins")
    private let arrangementInfo = NSTextField(labelWithString: "A – Einführung     B – Entwicklung     C – Höhepunkt     D – Ausklang")

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = bg.cgColor
        buildInterface()
    }

    private func buildInterface() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 7
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        let top = makeTopBar()
        top.heightAnchor.constraint(equalToConstant: 46).isActive = true
        root.addArrangedSubview(top)

        let body = NSStackView()
        body.orientation = .horizontal
        body.spacing = 7
        root.addArrangedSubview(body)

        let left = makeChatPanel()
        left.widthAnchor.constraint(equalToConstant: 300).isActive = true
        body.addArrangedSubview(left)

        let center = NSStackView()
        center.orientation = .vertical
        center.spacing = 7
        body.addArrangedSubview(center)
        center.addArrangedSubview(makeArrangementPanel())
        let inspector = makeInspectorPanel()
        inspector.heightAnchor.constraint(equalToConstant: 280).isActive = true
        center.addArrangedSubview(inspector)

        let right = makeBrowserPanel()
        right.widthAnchor.constraint(equalToConstant: 330).isActive = true
        body.addArrangedSubview(right)

        let transport = makeTransportBar()
        transport.heightAnchor.constraint(equalToConstant: 46).isActive = true
        root.addArrangedSubview(transport)
    }

    private func makePanel() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = panel.cgColor
        v.layer?.cornerRadius = 8
        v.layer?.borderWidth = 1
        v.layer?.borderColor = line.cgColor
        return v
    }

    private func makeTopBar() -> NSView {
        let box = makePanel()
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        let brand = NSTextField(labelWithString: "COMPOSITION STUDIO")
        brand.font = .systemFont(ofSize: 18, weight: .bold)
        stack.addArrangedSubview(brand)
        let by = NSTextField(labelWithString: "by Klangwerke")
        by.textColor = .secondaryLabelColor
        stack.addArrangedSubview(by)
        stack.addArrangedSubview(spacer())
        let project = button("Projekt: Abendlicht", #selector(renameProject))
        stack.addArrangedSubview(project)
        let dot = NSTextField(labelWithString: "●")
        dot.textColor = green
        stack.addArrangedSubview(dot)
        stack.addArrangedSubview(statusLabel)
        let ai = NSPopUpButton()
        ai.addItems(withTitles: ["Claude", "Gemini", "OpenAI"])
        ai.widthAnchor.constraint(equalToConstant: 115).isActive = true
        stack.addArrangedSubview(ai)
        stack.addArrangedSubview(button("KI", #selector(showAI)))
        stack.addArrangedSubview(button("Browser", #selector(showBrowser)))
        stack.addArrangedSubview(button("Darstellung", #selector(toggleAppearance)))
        return box
    }

    private func makeChatPanel() -> NSView {
        let box = makePanel()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])
        let tabs = NSSegmentedControl(labels: ["KI-Dialog", "Verlauf", "Ideen"], trackingMode: .selectOne, target: self, action: #selector(chatTabChanged(_:)))
        tabs.selectedSegment = 0
        stack.addArrangedSubview(tabs)
        chatLog.isEditable = false
        chatLog.font = .systemFont(ofSize: 13)
        chatLog.string = "Hallo!\n\nIch bin dein musikalischer Partner. Hier entsteht der spätere KI-Dialog der Composition-Studio-App."
        let scroll = NSScrollView()
        scroll.documentView = chatLog
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        stack.addArrangedSubview(scroll)
        let suggestions = ["Neue Komposition", "Variation", "Passage analysieren", "Instrumentierung ändern"]
        for title in suggestions { stack.addArrangedSubview(button(title, #selector(suggestion(_:)))) }
        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.spacing = 6
        chatInput.placeholderString = "Schreibe eine Nachricht..."
        chatInput.delegate = self
        inputRow.addArrangedSubview(chatInput)
        inputRow.addArrangedSubview(button("➤", #selector(sendChat)))
        stack.addArrangedSubview(inputRow)
        return box
    }

    private func makeArrangementPanel() -> NSView {
        let box = makePanel()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])
        arrangementInfo.font = .systemFont(ofSize: 12, weight: .semibold)
        arrangementInfo.textColor = blue
        stack.addArrangedSubview(arrangementInfo)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.title = "Spuren / Arrangement"
        trackTable.addTableColumn(column)
        trackTable.headerView = nil
        trackTable.dataSource = self
        trackTable.delegate = self
        trackTable.rowHeight = 42
        trackTable.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView()
        scroll.documentView = trackTable
        scroll.hasVerticalScroller = true
        stack.addArrangedSubview(scroll)
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.addArrangedSubview(button("＋ Spur", #selector(addTrack)))
        actions.addArrangedSubview(button("－ Spur", #selector(removeTrack)))
        actions.addArrangedSubview(button("Region duplizieren", #selector(duplicateRegion)))
        actions.addArrangedSubview(spacer())
        stack.addArrangedSubview(actions)
        return box
    }

    private func makeBrowserPanel() -> NSView {
        let box = makePanel()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])
        let tabs = NSSegmentedControl(labels: ["Plugins", "Dateien", "Instrumente", "Effekte"], trackingMode: .selectOne, target: self, action: #selector(browserChanged(_:)))
        tabs.selectedSegment = 0
        stack.addArrangedSubview(tabs)
        browserTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(browserTitle)
        let search = NSSearchField()
        search.placeholderString = "durchsuchen..."
        stack.addArrangedSubview(search)
        for p in ["Pianoteq 9", "Kontakt", "Retrologue", "Padshop", "HALion Sonic", "Valhalla Room", "FabFilter Pro-Q"] {
            let b = button(p, #selector(browserItem(_:)))
            b.alignment = .left
            stack.addArrangedSubview(b)
        }
        stack.addArrangedSubview(spacer())
        return box
    }

    private func makeInspectorPanel() -> NSView {
        let box = makePanel()
        let outer = NSStackView()
        outer.orientation = .horizontal
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            outer.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            outer.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            outer.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])
        let side = NSStackView()
        side.orientation = .vertical
        side.spacing = 7
        inspectorTitle.font = .systemFont(ofSize: 15, weight: .bold)
        side.addArrangedSubview(inspectorTitle)
        for s in ["Routing", "Instrumente", "Effekte", "MIDI Einstellungen", "Audio Einstellungen", "Notizen"] { side.addArrangedSubview(button(s, #selector(inspectorSection(_:)))) }
        side.addArrangedSubview(spacer())
        side.widthAnchor.constraint(equalToConstant: 175).isActive = true
        outer.addArrangedSubview(side)
        let detail = NSStackView()
        detail.orientation = .vertical
        detail.spacing = 8
        detail.addArrangedSubview(NSTextField(labelWithString: "Routing"))
        let chain = NSTextField(labelWithString: "MIDI Eingang  →  MIDI Verarbeitung  →  Instrument / Plugin  →  Audio Effekte  →  Audio Ausgang")
        chain.font = .systemFont(ofSize: 13)
        detail.addArrangedSubview(chain)
        let piano = NSTextField(labelWithString: "Pianoroll     Velocity     Controller     Notenexpression     Skalen     Akkorde")
        piano.textColor = blue
        detail.addArrangedSubview(piano)
        let roll = NSView()
        roll.wantsLayer = true
        roll.layer?.backgroundColor = NSColor.white.cgColor
        roll.layer?.borderWidth = 1
        roll.layer?.borderColor = line.cgColor
        detail.addArrangedSubview(roll)
        outer.addArrangedSubview(detail)
        return box
    }

    private func makeTransportBar() -> NSView {
        let box = makePanel()
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        stack.addArrangedSubview(NSTextField(labelWithString: "120 BPM"))
        stack.addArrangedSubview(NSTextField(labelWithString: "4/4"))
        stack.addArrangedSubview(spacer())
        stack.addArrangedSubview(button("■", #selector(stop)))
        playButton.target = self
        playButton.action = #selector(togglePlay)
        playButton.bezelStyle = .rounded
        stack.addArrangedSubview(playButton)
        let rec = button("●", #selector(record))
        rec.contentTintColor = .systemRed
        stack.addArrangedSubview(rec)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        stack.addArrangedSubview(timeLabel)
        stack.addArrangedSubview(spacer())
        stack.addArrangedSubview(button("Öffnen", #selector(openProject)))
        stack.addArrangedSubview(button("Speichern", #selector(saveProject)))
        return box
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    private func spacer() -> NSView {
        let v = NSView()
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return v
    }

    func numberOfRows(in tableView: NSTableView) -> Int { model.tracks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: model.tracks[row] + "    ▰  Region")
        label.font = .systemFont(ofSize: 13, weight: row == 2 ? .semibold : .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = trackTable.selectedRow
        guard row >= 0 && row < model.tracks.count else { return }
        model.selectedTrack = model.tracks[row]
        inspectorTitle.stringValue = model.selectedTrack
    }

    @objc private func togglePlay() {
        model.isPlaying.toggle()
        playButton.title = model.isPlaying ? "❚❚" : "▶"
        if model.isPlaying {
            model.timer?.invalidate()
            model.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.model.elapsed += 0.05
                self.updateTime()
            }
        } else { model.timer?.invalidate() }
    }

    @objc private func stop() {
        model.isPlaying = false
        model.timer?.invalidate()
        model.elapsed = 0
        playButton.title = "▶"
        updateTime()
    }

    private func updateTime() {
        let m = Int(model.elapsed) / 60
        let s = Int(model.elapsed) % 60
        let ms = Int((model.elapsed - floor(model.elapsed)) * 1000)
        timeLabel.stringValue = String(format: "%02d:%02d.%03d", m, s, ms)
    }

    @objc private func record() { statusLabel.stringValue = "Aufnahme bereit" }
    @objc private func addTrack() { model.tracks.append("Neue Spur \(model.tracks.count + 1)"); trackTable.reloadData(); statusLabel.stringValue = "Geändert" }
    @objc private func removeTrack() { let r = trackTable.selectedRow; if r >= 0 { model.tracks.remove(at: r); trackTable.reloadData(); statusLabel.stringValue = "Geändert" } }
    @objc private func duplicateRegion() { statusLabel.stringValue = "Region dupliziert" }
    @objc private func showAI() { chatInput.window?.makeFirstResponder(chatInput) }
    @objc private func showBrowser() { browserTitle.stringValue = "Plugins" }
    @objc private func toggleAppearance() { statusLabel.stringValue = "Darstellung aktiv" }
    @objc private func renameProject() { model.projectName = model.projectName == "Abendlicht" ? "Neues Projekt" : "Abendlicht"; statusLabel.stringValue = "Geändert" }
    @objc private func inspectorSection(_ sender: NSButton) { statusLabel.stringValue = sender.title }
    @objc private func browserItem(_ sender: NSButton) { statusLabel.stringValue = sender.title + " gewählt" }
    @objc private func suggestion(_ sender: NSButton) { chatInput.stringValue = sender.title; chatInput.window?.makeFirstResponder(chatInput) }

    @objc private func browserChanged(_ sender: NSSegmentedControl) { browserTitle.stringValue = sender.label(forSegment: sender.selectedSegment) ?? "Browser" }
    @objc private func chatTabChanged(_ sender: NSSegmentedControl) { chatLog.string = sender.selectedSegment == 0 ? "KI-Dialog" : (sender.selectedSegment == 1 ? "Verlauf\n\nNoch keine Einträge." : "Ideen\n\nNoch keine gespeicherten Ideen.") }

    @objc private func sendChat() {
        let text = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatLog.string += "\n\nDu: \(text)\nComposition Studio: KI-Anbindung folgt im nächsten Funktionsschritt."
        chatInput.stringValue = ""
    }

    func controlTextDidEndEditing(_ obj: Notification) { sendChat() }

    @objc private func saveProject() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = model.projectName + ".json"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            let dict: [String: Any] = ["project": self.model.projectName, "tracks": self.model.tracks, "selectedTrack": self.model.selectedTrack]
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) { try? data.write(to: url); self.statusLabel.stringValue = "Gespeichert" }
        }
    }

    @objc private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard result == .OK, let url = panel.url, let self, let data = try? Data(contentsOf: url), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let tracks = dict["tracks"] as? [String] { self.model.tracks = tracks; self.trackTable.reloadData() }
            if let name = dict["project"] as? String { self.model.projectName = name }
            self.statusLabel.stringValue = "Geladen"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = StudioViewController()
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1480, height: 920), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Composition Studio"
        w.center()
        w.minSize = NSSize(width: 1180, height: 720)
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
