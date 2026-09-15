import Foundation

@_silgen_name("cs_project_new") private func cs_project_new() -> Bool
@_silgen_name("cs_track_volume") private func cs_track_volume(_ track:Int32) -> Float
@_silgen_name("cs_track_set_volume") private func cs_track_set_volume(_ track:Int32,_ value:Float)
@_silgen_name("cs_track_pan") private func cs_track_pan(_ track:Int32) -> Float
@_silgen_name("cs_track_set_pan") private func cs_track_set_pan(_ track:Int32,_ value:Float)
@_silgen_name("cs_track_audio_output") private func cs_track_audio_output(_ track:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32) -> Bool
@_silgen_name("cs_track_set_audio_output") private func cs_track_set_audio_output(_ track:Int32,_ value:UnsafePointer<CChar>)
@_silgen_name("cs_track_midi_input") private func cs_track_midi_input(_ track:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32) -> Bool
@_silgen_name("cs_track_set_midi_input") private func cs_track_set_midi_input(_ track:Int32,_ value:UnsafePointer<CChar>)
@_silgen_name("cs_track_chain_summary") private func cs_track_chain_summary(_ track:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32) -> Bool
@_silgen_name("cs_clip_name") private func cs_clip_name(_ clip:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32) -> Bool
@_silgen_name("cs_clip_create_midi") private func cs_clip_create_midi(_ track:Int32,_ start:Double,_ length:Double,_ name:UnsafePointer<CChar>) -> Int32
@_silgen_name("cs_clip_delete") private func cs_clip_delete(_ clip:Int32)
@_silgen_name("cs_clip_duplicate") private func cs_clip_duplicate(_ clip:Int32) -> Int32
@_silgen_name("cs_clip_duplicate_at") private func cs_clip_duplicate_at(_ clip:Int32,_ start:Double,_ track:Int32) -> Int32
@_silgen_name("cs_clip_move") private func cs_clip_move(_ clip:Int32,_ start:Double,_ track:Int32)
@_silgen_name("cs_clip_resize") private func cs_clip_resize(_ clip:Int32,_ length:Double)
@_silgen_name("cs_clip_clear_midi") private func cs_clip_clear_midi(_ clip:Int32)
@_silgen_name("cs_clip_add_note") private func cs_clip_add_note(_ clip:Int32,_ pitch:Int32,_ velocity:Int32,_ start:Double,_ length:Double) -> Bool
@_silgen_name("cs_clip_update_note") private func cs_clip_update_note(_ clip:Int32,_ index:Int32,_ pitch:Int32,_ velocity:Int32,_ start:Double,_ length:Double) -> Bool
@_silgen_name("cs_clip_delete_note") private func cs_clip_delete_note(_ clip:Int32,_ index:Int32)
@_silgen_name("cs_track_preview_note") private func cs_track_preview_note(_ track:Int32,_ pitch:Int32,_ velocity:Int32,_ on:Bool)
@_silgen_name("cs_midi_export_clip") private func cs_midi_export_clip(_ clip:Int32,_ path:UnsafePointer<CChar>) -> Bool
@_silgen_name("cs_midi_export_project") private func cs_midi_export_project(_ path:UnsafePointer<CChar>) -> Bool
@_silgen_name("cs_midi_import_multitrack") private func cs_midi_import_multitrack(_ path:UnsafePointer<CChar>,_ start:Double) -> Int32

extension CompositionStudioEngine {
    @discardableResult func newProject() -> Bool {
        guard isReady else { return false }
        return cs_project_new()
    }

    func trackVolume(_ id:Int) -> Float { isReady ? cs_track_volume(Int32(id)) : 1 }
    func setTrackVolume(_ id:Int,_ value:Float) { if isReady { cs_track_set_volume(Int32(id), value) } }
    func trackPan(_ id:Int) -> Float { isReady ? cs_track_pan(Int32(id)) : 0 }
    func setTrackPan(_ id:Int,_ value:Float) { if isReady { cs_track_set_pan(Int32(id), value) } }

    func trackAudioOutput(_ id:Int) -> String {
        guard isReady else { return "master" }
        var b=[CChar](repeating:0,count:512)
        return cs_track_audio_output(Int32(id),&b,512) ? String(cString:b) : "master"
    }
    func setTrackAudioOutput(_ id:Int,_ value:String) {
        guard isReady else { return }
        value.withCString { cs_track_set_audio_output(Int32(id),$0) }
    }

    func trackMidiInput(_ id:Int) -> String {
        guard isReady else { return "" }
        var b=[CChar](repeating:0,count:512)
        return cs_track_midi_input(Int32(id),&b,512) ? String(cString:b) : ""
    }
    func setTrackMidiInput(_ id:Int,_ value:String) {
        guard isReady else { return }
        value.withCString { cs_track_set_midi_input(Int32(id),$0) }
    }

    func trackChainSummary(_ id:Int) -> String {
        guard isReady else { return "Keine Inserts" }
        var b=[CChar](repeating:0,count:2048)
        return cs_track_chain_summary(Int32(id),&b,2048) ? String(cString:b) : "Keine Inserts"
    }

    func clipName(_ id:Int) -> String {
        guard isReady else { return "MIDI Clip" }
        var b=[CChar](repeating:0,count:512)
        let ok=cs_clip_name(Int32(id),&b,512)
        let s=ok ? String(cString:b) : ""
        return s.isEmpty ? "MIDI Clip" : s
    }

    @discardableResult func createMidiClip(trackId:Int,startBeat:Double,lengthBeats:Double,name:String="MIDI Clip") -> Int {
        guard isReady else { return -1 }
        return name.withCString { Int(cs_clip_create_midi(Int32(trackId),startBeat,lengthBeats,$0)) }
    }
    func deleteClip(_ id:Int) { if isReady { cs_clip_delete(Int32(id)) } }
    @discardableResult func duplicateClip(_ id:Int) -> Int { isReady ? Int(cs_clip_duplicate(Int32(id))) : -1 }
    @discardableResult func duplicateClip(_ id:Int,at start:Double,trackId:Int) -> Int { isReady ? Int(cs_clip_duplicate_at(Int32(id),start,Int32(trackId))) : -1 }
    func moveClip(_ id:Int,startBeat:Double,trackId:Int) { if isReady { cs_clip_move(Int32(id),startBeat,Int32(trackId)) } }
    func resizeClip(_ id:Int,lengthBeats:Double) { if isReady { cs_clip_resize(Int32(id),lengthBeats) } }
    func clearMidiNotes(_ id:Int) { if isReady { cs_clip_clear_midi(Int32(id)) } }
    @discardableResult func addMidiNote(clipId:Int,pitch:Int,velocity:Int,startBeat:Double,lengthBeats:Double) -> Bool {
        isReady && cs_clip_add_note(Int32(clipId),Int32(pitch),Int32(velocity),startBeat,lengthBeats)
    }
    @discardableResult func updateMidiNote(clipId:Int,index:Int,pitch:Int,velocity:Int,startBeat:Double,lengthBeats:Double) -> Bool {
        isReady && cs_clip_update_note(Int32(clipId),Int32(index),Int32(pitch),Int32(velocity),startBeat,lengthBeats)
    }
    func deleteMidiNote(clipId:Int,index:Int) { if isReady { cs_clip_delete_note(Int32(clipId),Int32(index)) } }
    func previewNote(trackId:Int,pitch:Int,velocity:Int=100,on:Bool) { if isReady { cs_track_preview_note(Int32(trackId),Int32(pitch),Int32(velocity),on) } }

    @discardableResult func exportClipMIDI(_ id:Int,to path:String) -> Bool {
        guard isReady else { return false }
        return path.withCString { cs_midi_export_clip(Int32(id),$0) }
    }
    @discardableResult func exportProjectMIDI(to path:String) -> Bool {
        guard isReady else { return false }
        return path.withCString { cs_midi_export_project($0) }
    }
    @discardableResult func importMIDIMultitrack(path:String,startBeat:Double=0) -> Int {
        guard isReady else { return -1 }
        return path.withCString { Int(cs_midi_import_multitrack($0,startBeat)) }
    }
}
