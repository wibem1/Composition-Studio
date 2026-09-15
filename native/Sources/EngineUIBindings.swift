import AppKit
import UniformTypeIdentifiers

private final class StudioResizeHandle: NSView {
    enum Axis { case horizontal, vertical }
    let axis: Axis
    var dragged: ((CGFloat) -> Void)?
    private var lastPoint: NSPoint?

    init(axis: Axis) {
        self.axis = axis
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: axis == .vertical ? .resizeLeftRight : .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        lastPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let lastPoint else { return }
        let now = event.locationInWindow
        let delta = axis == .vertical ? now.x - lastPoint.x : now.y - lastPoint.y
        self.lastPoint = now
        dragged?(delta)
    }
}

private final class StudioLayoutState {
    static let shared = StudioLayoutState()
    var leftWidth: CGFloat = 330
    var rightWidth: CGFloat = 350
    var arrangementFraction: CGFloat = 0.58
    weak var leftHandle: StudioResizeHandle?
    weak var rightHandle: StudioResizeHandle?
    weak var horizontalHandle: StudioResizeHandle?
}

extension StudioViewController {
    func installEngineBindings(engineReady: Bool) {
        let engine = CompositionStudioEngine.shared

        playButton.target = self
        playButton.action = #selector(enginePlayPause)
        stopButton.target = self
        stopButton.action = #selector(engineStop)
        recordButton.target = self
        recordButton.action = #selector(engineRecord)

        installReadableTypography()
        installResizablePanes()

        if let tempoField = transportCard.subviews
            .compactMap({ $0 as? NSTextField })
            .first(where: { $0.identifier?.rawValue == "tempo" }) {
            tempoField.isEditable = true
            tempoField.isSelectable = true
            tempoField.target = self
            tempoField.action = #selector(engineTempoChanged(_:))
        }

        if let metronomeButton = transportCard.subviews
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.title.contains("Metronom") }) {
            metronomeButton.target = self
            metronomeButton.action = #selector(engineMetronome(_:))
        }

        if let openButton = transportCard.subviews
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.identifier?.rawValue == "open" }) {
            openButton.target = self
            openButton.action = #selector(engineOpenProject)
        }

        if let saveButton = transportCard.subviews
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.identifier?.rawValue == "save" }) {
            saveButton.target = self
            saveButton.action = #selector(engineSaveProject)
        }

        browserTitle.stringValue = engineReady ? "Plugins (\(engine.pluginCount))" : "Plugins"
        statusLabel.stringValue = engineReady ? "Audio-Engine bereit" : "Audio-Engine Fehler"
        refreshEngineUI()
    }

    private func installReadableTypography() {
        func enlarge(_ root: NSView) {
            for subview in root.subviews {
                if let field = subview as? NSTextField, let font = field.font {
                    let target = max(font.pointSize + 2, 13)
                    field.font = NSFont.systemFont(ofSize: target, weight: font.fontDescriptor.symbolicTraits.contains(.bold) ? .semibold : .regular)
                } else if let button = subview as? NSButton, let font = button.font {
                    button.font = NSFont.systemFont(ofSize: max(font.pointSize + 2, 13), weight: .medium)
                } else if let popup = subview as? NSPopUpButton {
                    popup.font = .systemFont(ofSize: 13)
                }
                enlarge(subview)
            }
        }
        enlarge(view)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
        inspectorTitle.font = .systemFont(ofSize: 15, weight: .bold)
        browserTitle.font = .systemFont(ofSize: 15, weight: .bold)
        playButton.font = .systemFont(ofSize: 20, weight: .bold)
        stopButton.font = .systemFont(ofSize: 18, weight: .bold)
        recordButton.font = .systemFont(ofSize: 20, weight: .bold)
    }

    private func installResizablePanes() {
        let state = StudioLayoutState.shared
        guard state.leftHandle == nil else { return }

        let left = StudioResizeHandle(axis: .vertical)
        let right = StudioResizeHandle(axis: .vertical)
        let horizontal = StudioResizeHandle(axis: .horizontal)
        view.addSubview(left)
        view.addSubview(right)
        view.addSubview(horizontal)
        state.leftHandle = left
        state.rightHandle = right
        state.horizontalHandle = horizontal

        left.dragged = { [weak self] delta in
            guard let self else { return }
            state.leftWidth = min(520, max(260, state.leftWidth + delta))
            self.applyResizableLayout()
        }
        right.dragged = { [weak self] delta in
            guard let self else { return }
            state.rightWidth = min(520, max(270, state.rightWidth - delta))
            self.applyResizableLayout()
        }
        horizontal.dragged = { [weak self] delta in
            guard let self else { return }
            let usable = max(1, self.arrangementCard.height + self.inspectorCard.height)
            state.arrangementFraction = min(0.78, max(0.38, state.arrangementFraction + delta / usable))
            self.applyResizableLayout()
        }
        applyResizableLayout()
    }

    private func applyResizableLayout() {
        let state = StudioLayoutState.shared
        let W = view.bounds.width
        let H = view.bounds.height
        let margin: CGFloat = 8
        let gap: CGFloat = 7
        let topH: CGFloat = 50
        let transportH: CGFloat = 72
        let contentTop = margin + topH + gap
        let bottomY = H - margin - transportH
        let leftW = min(state.leftWidth, W * 0.32)
        let rightW = min(state.rightWidth, W * 0.32)
        let centerX = margin + leftW + gap
        let centerW = max(520, W - 2 * margin - leftW - rightW - 2 * gap)
        let centerH = max(400, bottomY - contentTop - gap)
        let arrH = max(250, min(centerH - 190, centerH * state.arrangementFraction))

        topBar.frame = NSRect(x: margin, y: margin, width: W - 2 * margin, height: topH)
        chatCard.frame = NSRect(x: margin, y: contentTop, width: leftW, height: centerH)
        arrangementCard.frame = NSRect(x: centerX, y: contentTop, width: centerW, height: arrH)
        inspectorCard.frame = NSRect(x: centerX, y: contentTop + arrH + gap, width: centerW, height: centerH - arrH - gap)
        browserCard.frame = NSRect(x: centerX + centerW + gap, y: contentTop, width: rightW, height: centerH)
        transportCard.frame = NSRect(x: margin, y: bottomY, width: W - 2 * margin, height: transportH)

        state.leftHandle?.frame = NSRect(x: margin + leftW - 3, y: contentTop, width: 10, height: centerH)
        state.rightHandle?.frame = NSRect(x: centerX + centerW - 3, y: contentTop, width: 10, height: centerH)
        state.horizontalHandle?.frame = NSRect(x: centerX, y: contentTop + arrH - 3, width: centerW, height: 10)

        layoutTop()
        layoutChat()
        layoutArrangement()
        layoutBrowser()
        layoutInspector()
        layoutTransport()
        enlargeTransportControls()
    }

    private func enlargeTransportControls() {
        let w = transportCard.bounds.width
        let y: CGFloat = 10
        stopButton.frame = NSRect(x: w * 0.46 - 62, y: y, width: 48, height: 48)
        playButton.frame = NSRect(x: w * 0.46 - 5, y: y - 3, width: 54, height: 54)
        recordButton.frame = NSRect(x: w * 0.46 + 58, y: y - 3, width: 54, height: 54)
        timeLabel.frame = NSRect(x: w * 0.20, y: 20, width: 135, height: 30)
        transportCard.subviews.first { $0.identifier?.rawValue == "open" }?.frame = NSRect(x: w - 196, y: 18, width: 82, height: 34)
        transportCard.subviews.first { $0.identifier?.rawValue == "save" }?.frame = NSRect(x: w - 106, y: 18, width: 92, height: 34)
    }

    func refreshEngineUI() {
        applyResizableLayout()
        let engine = CompositionStudioEngine.shared
        guard engine.isReady else { return }

        playButton.title = engine.isPlaying ? "❚❚" : "▶"
        statusLabel.stringValue = engine.isRecording ? "Aufnahme" : (engine.isPlaying ? "Wiedergabe" : "Bereit")

        let elapsed = max(0, engine.positionSeconds)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let millis = Int((elapsed - floor(elapsed)) * 1000)
        timeLabel.stringValue = String(format: "%02d:%02d.%03d", minutes, seconds, millis)

        if let tempoField = transportCard.subviews
            .compactMap({ $0 as? NSTextField })
            .first(where: { $0.identifier?.rawValue == "tempo" }),
           tempoField.currentEditor() == nil {
            tempoField.stringValue = String(format: "Tempo\n%.2f", engine.tempo)
        }

        if let metronomeButton = transportCard.subviews
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.title.contains("Metronom") }) {
            metronomeButton.state = engine.isMetronomeEnabled ? .on : .off
            metronomeButton.contentTintColor = engine.isMetronomeEnabled ? .csBlue : nil
        }
    }

    @objc private func enginePlayPause() {
        let engine = CompositionStudioEngine.shared
        engine.isPlaying ? engine.pause() : engine.play()
        refreshEngineUI()
    }

    @objc private func engineStop() {
        let engine = CompositionStudioEngine.shared
        engine.stop()
        engine.locate(seconds: 0)
        refreshEngineUI()
    }

    @objc private func engineRecord() {
        CompositionStudioEngine.shared.record()
        refreshEngineUI()
    }

    @objc private func engineTempoChanged(_ sender: NSTextField) {
        let normalized = sender.stringValue
            .replacingOccurrences(of: "Tempo", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) {
            CompositionStudioEngine.shared.setTempo(value)
            statusLabel.stringValue = String(format: "Tempo %.2f BPM", CompositionStudioEngine.shared.tempo)
        } else {
            statusLabel.stringValue = "Ungültiges Tempo"
        }
        refreshEngineUI()
    }

    @objc private func engineMetronome(_ sender: NSButton) {
        let engine = CompositionStudioEngine.shared
        engine.setMetronome(!engine.isMetronomeEnabled)
        refreshEngineUI()
    }

    @objc private func engineSaveProject() {
        let panel = NSSavePanel()
        if let mgd = UTType(filenameExtension: "mgd") { panel.allowedContentTypes = [mgd] }
        panel.nameFieldStringValue = model.projectName + ".mgd"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            if CompositionStudioEngine.shared.saveProject(as: url.path) {
                self.model.projectName = url.deletingPathExtension().lastPathComponent
                self.projectLabel.stringValue = "Projekt: \(self.model.projectName)"
                self.statusLabel.stringValue = "Projekt gespeichert"
            } else {
                self.statusLabel.stringValue = "Speichern fehlgeschlagen"
            }
        }
    }

    @objc private func engineOpenProject() {
        let panel = NSOpenPanel()
        if let mgd = UTType(filenameExtension: "mgd") { panel.allowedContentTypes = [mgd] }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            if CompositionStudioEngine.shared.loadProject(from: url.path) {
                self.model.projectName = url.deletingPathExtension().lastPathComponent
                self.projectLabel.stringValue = "Projekt: \(self.model.projectName)"
                self.statusLabel.stringValue = "Projekt geladen"
                self.refreshEngineUI()
            } else {
                self.statusLabel.stringValue = "Laden fehlgeschlagen"
            }
        }
    }
}
