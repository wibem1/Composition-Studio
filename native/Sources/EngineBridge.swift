import Foundation

@_silgen_name("cs_engine_initialize") private func cs_engine_initialize() -> Bool
@_silgen_name("cs_engine_shutdown") private func cs_engine_shutdown()
@_silgen_name("cs_engine_is_ready") private func cs_engine_is_ready() -> Bool
@_silgen_name("cs_engine_play") private func cs_engine_play()
@_silgen_name("cs_engine_stop") private func cs_engine_stop()
@_silgen_name("cs_engine_pause") private func cs_engine_pause()
@_silgen_name("cs_engine_record") private func cs_engine_record()
@_silgen_name("cs_engine_is_playing") private func cs_engine_is_playing() -> Bool
@_silgen_name("cs_engine_is_recording") private func cs_engine_is_recording() -> Bool
@_silgen_name("cs_engine_position_seconds") private func cs_engine_position_seconds() -> Double
@_silgen_name("cs_engine_locate_seconds") private func cs_engine_locate_seconds(_ seconds: Double)
@_silgen_name("cs_engine_tempo") private func cs_engine_tempo() -> Double
@_silgen_name("cs_engine_set_tempo") private func cs_engine_set_tempo(_ bpm: Double)
@_silgen_name("cs_engine_set_looping") private func cs_engine_set_looping(_ enabled: Bool)
@_silgen_name("cs_engine_is_looping") private func cs_engine_is_looping() -> Bool
@_silgen_name("cs_engine_set_metronome") private func cs_engine_set_metronome(_ enabled: Bool)
@_silgen_name("cs_engine_metronome_enabled") private func cs_engine_metronome_enabled() -> Bool
@_silgen_name("cs_engine_plugin_count") private func cs_engine_plugin_count() -> Int32
@_silgen_name("cs_project_save_as") private func cs_project_save_as(_ path: UnsafePointer<CChar>) -> Bool
@_silgen_name("cs_project_load") private func cs_project_load(_ path: UnsafePointer<CChar>) -> Bool

final class CompositionStudioEngine {
    static let shared = CompositionStudioEngine()
    private(set) var initialized = false

    private init() {}

    @discardableResult
    func initialize() -> Bool {
        if initialized { return true }
        initialized = cs_engine_initialize()
        return initialized
    }

    func shutdown() {
        guard initialized else { return }
        cs_engine_shutdown()
        initialized = false
    }

    var isReady: Bool { initialized && cs_engine_is_ready() }
    var isPlaying: Bool { isReady && cs_engine_is_playing() }
    var isRecording: Bool { isReady && cs_engine_is_recording() }
    var positionSeconds: Double { isReady ? cs_engine_position_seconds() : 0 }
    var tempo: Double { isReady ? cs_engine_tempo() : 120 }
    var isLooping: Bool { isReady && cs_engine_is_looping() }
    var isMetronomeEnabled: Bool { isReady && cs_engine_metronome_enabled() }
    var pluginCount: Int { isReady ? Int(cs_engine_plugin_count()) : 0 }

    func play() { if isReady { cs_engine_play() } }
    func stop() { if isReady { cs_engine_stop() } }
    func pause() { if isReady { cs_engine_pause() } }
    func record() { if isReady { cs_engine_record() } }
    func locate(seconds: Double) { if isReady { cs_engine_locate_seconds(seconds) } }
    func setTempo(_ bpm: Double) { if isReady { cs_engine_set_tempo(bpm) } }
    func setLooping(_ enabled: Bool) { if isReady { cs_engine_set_looping(enabled) } }
    func setMetronome(_ enabled: Bool) { if isReady { cs_engine_set_metronome(enabled) } }

    @discardableResult
    func saveProject(as path: String) -> Bool {
        guard isReady else { return false }
        return path.withCString { cs_project_save_as($0) }
    }

    @discardableResult
    func loadProject(from path: String) -> Bool {
        guard isReady else { return false }
        return path.withCString { cs_project_load($0) }
    }
}
