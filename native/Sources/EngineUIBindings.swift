extension StudioViewController {
    func installEngineBindings(engineReady: Bool) {
        let engine = CompositionStudioEngine.shared

        playButton.target = self
        playButton.action = #selector(enginePlayPause)
        stopButton.target = self
        stopButton.action = #selector(engineStop)
        recordButton.target = self
        recordButton.action = #selector(engineRecord)

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

        if let pluginLabel = browserCard.subviews
            .compactMap({ $0 as? NSTextField })
            .first(where: { $0 === browserTitle }) {
            pluginLabel.stringValue = engineReady ? "Plugins (\(engine.pluginCount))" : "Plugins"
        }

        statusLabel.stringValue = engineReady ? "Audio-Engine bereit" : "Audio-Engine Fehler"
        refreshEngineUI()
    }

    func refreshEngineUI() {
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
        if engine.isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
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
        let engine = CompositionStudioEngine.shared
        let normalized = sender.stringValue
            .replacingOccurrences(of: "Tempo", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) {
            engine.setTempo(value)
            statusLabel.stringValue = String(format: "Tempo %.2f BPM", engine.tempo)
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
        if let mgd = UTType(filenameExtension: "mgd") {
            panel.allowedContentTypes = [mgd]
        }
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
        if let mgd = UTType(filenameExtension: "mgd") {
            panel.allowedContentTypes = [mgd]
        }
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
