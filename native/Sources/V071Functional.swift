import AppKit
import UniformTypeIdentifiers

private final class V071FunctionalState {
    static let shared = V071FunctionalState()
    weak var bar: NSStackView?
    weak var nameField: NSTextField?
    weak var mute: NSButton?
    weak var solo: NSButton?
    weak var arm: NSButton?
    var shownTrackID: Int?
}

extension StudioViewController {
    func installV071FunctionalBindings() {
        let state = V071FunctionalState.shared
        guard state.bar == nil else { refreshV071FunctionalUI(); return }

        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.alignment = .centerY
        bar.spacing = 7
        bar.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        bar.layer?.borderColor = NSColor.separatorColor.cgColor
        bar.layer?.borderWidth = 1
        bar.layer?.cornerRadius = 7
        bar.autoresizingMask = [.maxXMargin, .minYMargin]

        func button(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            b.font = .systemFont(ofSize: 12, weight: .medium)
            return b
        }

        let add = button("+ Spur", #selector(v071AddTrack))
        let remove = button("− Spur", #selector(v071DeleteTrack))
        let importMIDI = button("MIDI importieren", #selector(v071ImportMIDI))
        let open = button("Projekt öffnen", #selector(v071OpenProject))
        let save = button("Projekt speichern", #selector(v071SaveProject))
        let name = NSTextField(string: "")
        name.placeholderString = "Spurname"
        name.font = .systemFont(ofSize: 12)
        name.target = self
        name.action = #selector(v071RenameTrack(_:))
        name.widthAnchor.constraint(equalToConstant: 145).isActive = true
        let mute = button("M", #selector(v071ToggleMute))
        let solo = button("S", #selector(v071ToggleSolo))
        let arm = button("R", #selector(v071ToggleArm))
        for b in [mute, solo, arm] { b.setButtonType(.toggle); b.widthAnchor.constraint(equalToConstant: 34).isActive = true }

        [add, remove, importMIDI, open, save, name, mute, solo, arm].forEach { bar.addArrangedSubview($0) }
        arrangementCard.addSubview(bar, positioned: .above, relativeTo: nil)
        bar.frame = NSRect(x: 180, y: max(4, arrangementCard.bounds.height - 40), width: 730, height: 34)

        state.bar = bar
        state.nameField = name
        state.mute = mute
        state.solo = solo
        state.arm = arm
        refreshV071FunctionalUI()
    }

    func refreshV071FunctionalUI() {
        let state = V071FunctionalState.shared
        guard let bar = state.bar else { return }
        bar.frame.origin.y = max(4, arrangementCard.bounds.height - bar.frame.height - 4)
        let tracks = CompositionStudioEngine.shared.tracks()
        let id = LiveStudioState.shared.selectedTrackID
        let track = tracks.first(where: { $0.id == id })
        state.shownTrackID = track?.id
        state.nameField?.stringValue = track?.name ?? ""
        state.nameField?.isEnabled = track != nil
        state.mute?.isEnabled = track != nil
        state.solo?.isEnabled = track != nil
        state.arm?.isEnabled = track != nil
        state.mute?.state = track?.muted == true ? .on : .off
        state.solo?.state = track?.soloed == true ? .on : .off
        state.arm?.state = track?.recordArmed == true ? .on : .off
    }

    @objc private func v071AddTrack() {
        let e = CompositionStudioEngine.shared
        let id = e.createTrack(name: "MIDI Spur \(e.tracks().count + 1)")
        if id >= 0 { LiveStudioState.shared.selectedTrackID = id; statusLabel.stringValue = "Spur angelegt" }
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071DeleteTrack() {
        guard let id = LiveStudioState.shared.selectedTrackID else { return }
        CompositionStudioEngine.shared.deleteTrack(id: id)
        LiveStudioState.shared.selectedTrackID = nil
        LiveStudioState.shared.selectedClipID = nil
        statusLabel.stringValue = "Spur gelöscht"
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071RenameTrack(_ sender: NSTextField) {
        guard let id = LiveStudioState.shared.selectedTrackID else { return }
        let n = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        CompositionStudioEngine.shared.setTrackName(id: id, name: n)
        statusLabel.stringValue = "Spur umbenannt"
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071ToggleMute() {
        guard let id = LiveStudioState.shared.selectedTrackID,
              let t = CompositionStudioEngine.shared.tracks().first(where: { $0.id == id }) else { return }
        CompositionStudioEngine.shared.setMuted(id: id, !t.muted)
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071ToggleSolo() {
        guard let id = LiveStudioState.shared.selectedTrackID,
              let t = CompositionStudioEngine.shared.tracks().first(where: { $0.id == id }) else { return }
        CompositionStudioEngine.shared.setSoloed(id: id, !t.soloed)
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071ToggleArm() {
        guard let id = LiveStudioState.shared.selectedTrackID,
              let t = CompositionStudioEngine.shared.tracks().first(where: { $0.id == id }) else { return }
        CompositionStudioEngine.shared.setRecordArmed(id: id, !t.recordArmed)
        syncLiveDAW(); refreshV071FunctionalUI()
    }

    @objc private func v071ImportMIDI() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.midi]
        p.allowsMultipleSelection = false
        guard let w = view.window else { return }
        p.beginSheetModal(for: w) { [weak self] result in
            guard result == .OK, let url = p.url, let self else { return }
            let target = LiveStudioState.shared.selectedTrackID ?? -1
            let clip = CompositionStudioEngine.shared.importMIDI(path: url.path, trackId: target, startBeat: 0)
            if clip >= 0 {
                let c = CompositionStudioEngine.shared.clips().first(where: { $0.id == clip })
                LiveStudioState.shared.selectedClipID = clip
                LiveStudioState.shared.selectedTrackID = c?.trackId
                self.statusLabel.stringValue = "MIDI importiert"
            } else { self.statusLabel.stringValue = "MIDI-Import fehlgeschlagen" }
            self.syncLiveDAW(); self.refreshV071FunctionalUI()
        }
    }

    @objc private func v071OpenProject() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        guard let w = view.window else { return }
        p.beginSheetModal(for: w) { [weak self] result in
            guard result == .OK, let url = p.url, let self else { return }
            if CompositionStudioEngine.shared.loadProject(from: url.path) {
                LiveStudioState.shared.selectedTrackID = nil
                LiveStudioState.shared.selectedClipID = nil
                self.statusLabel.stringValue = "Projekt geöffnet"
                self.syncLiveDAW(); self.refreshV071FunctionalUI()
            } else { self.statusLabel.stringValue = "Projekt konnte nicht geöffnet werden" }
        }
    }

    @objc private func v071SaveProject() {
        let p = NSSavePanel()
        p.nameFieldStringValue = "Composition Studio Project.magda"
        guard let w = view.window else { return }
        p.beginSheetModal(for: w) { [weak self] result in
            guard result == .OK, let url = p.url, let self else { return }
            self.statusLabel.stringValue = CompositionStudioEngine.shared.saveProject(as: url.path) ? "Projekt gespeichert" : "Speichern fehlgeschlagen"
        }
    }
}
