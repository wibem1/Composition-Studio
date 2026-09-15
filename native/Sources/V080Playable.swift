import AppKit

private final class V080State {
    static let shared = V080State()
    weak var popup: NSPopUpButton?
    weak var loadButton: NSButton?
    weak var info: NSTextField?
    var plugins: [EnginePlugin] = []
}

extension StudioViewController {
    func installV080PlayableBindings() {
        let state = V080State.shared
        guard state.popup == nil else { refreshV080Plugins(); return }
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.font = .systemFont(ofSize: 12)
        let load = NSButton(title: "Instrument laden", target: self, action: #selector(v080LoadInstrument))
        load.bezelStyle = .rounded
        load.font = .systemFont(ofSize: 12, weight: .semibold)
        let info = NSTextField(labelWithString: "Plugins werden aus der MAGDA-Engine gelesen")
        info.font = .systemFont(ofSize: 11)
        info.textColor = .secondaryLabelColor
        browserCard.addSubview(popup)
        browserCard.addSubview(load)
        browserCard.addSubview(info)
        popup.frame = NSRect(x: 14, y: 112, width: max(180, browserCard.bounds.width - 28), height: 28)
        load.frame = NSRect(x: 14, y: 148, width: 150, height: 28)
        info.frame = NSRect(x: 14, y: 184, width: max(180, browserCard.bounds.width - 28), height: 20)
        popup.autoresizingMask = [.width]
        info.autoresizingMask = [.width]
        state.popup = popup; state.loadButton = load; state.info = info
        refreshV080Plugins()
    }

    func refreshV080Plugins() {
        let state = V080State.shared
        guard let popup = state.popup else { return }
        let all = CompositionStudioEngine.shared.plugins()
        state.plugins = all.filter { $0.isInstrument }
        let old = popup.indexOfSelectedItem
        popup.removeAllItems()
        if state.plugins.isEmpty {
            popup.addItem(withTitle: "Keine Instrument-Plugins gefunden")
            popup.isEnabled = false
            state.loadButton?.isEnabled = false
            state.info?.stringValue = "Keine gescannten VST3/AU-Instrumente verfügbar"
        } else {
            for p in state.plugins { popup.addItem(withTitle: "\(p.name)  [\(p.format)]") }
            popup.isEnabled = true
            state.loadButton?.isEnabled = LiveStudioState.shared.selectedTrackID != nil
            if old >= 0 && old < popup.numberOfItems { popup.selectItem(at: old) }
            state.info?.stringValue = "\(state.plugins.count) Instrumente gefunden · Spur wählen und laden"
        }
    }

    @objc private func v080LoadInstrument() {
        let state = V080State.shared
        guard let track = LiveStudioState.shared.selectedTrackID,
              let popup = state.popup,
              popup.indexOfSelectedItem >= 0,
              popup.indexOfSelectedItem < state.plugins.count else { return }
        let plugin = state.plugins[popup.indexOfSelectedItem]
        let device = CompositionStudioEngine.shared.addPlugin(trackId: track, pluginIndex: plugin.index)
        if device >= 0 {
            statusLabel.stringValue = "\(plugin.name) geladen – Play startet den MIDI-Clip"
            state.info?.stringValue = "Geladen: \(plugin.name) auf aktueller Spur"
        } else {
            statusLabel.stringValue = "Instrument konnte nicht geladen werden"
            state.info?.stringValue = "Laden fehlgeschlagen: \(plugin.name)"
        }
    }
}
