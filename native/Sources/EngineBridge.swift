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
@_silgen_name("cs_track_count") private func cs_track_count() -> Int32
@_silgen_name("cs_track_id_at") private func cs_track_id_at(_ index:Int32) -> Int32
@_silgen_name("cs_track_name_at") private func cs_track_name_at(_ index:Int32,_ out:UnsafeMutablePointer<CChar>,_ cap:Int32) -> Bool
@_silgen_name("cs_track_create") private func cs_track_create(_ name:UnsafePointer<CChar>) -> Int32
@_silgen_name("cs_track_delete") private func cs_track_delete(_ id:Int32)
@_silgen_name("cs_track_set_name") private func cs_track_set_name(_ id:Int32,_ name:UnsafePointer<CChar>)
@_silgen_name("cs_track_set_muted") private func cs_track_set_muted(_ id:Int32,_ value:Bool)
@_silgen_name("cs_track_set_soloed") private func cs_track_set_soloed(_ id:Int32,_ value:Bool)
@_silgen_name("cs_track_set_record_armed") private func cs_track_set_record_armed(_ id:Int32,_ value:Bool)
@_silgen_name("cs_clip_count") private func cs_clip_count() -> Int32
@_silgen_name("cs_clip_id_at") private func cs_clip_id_at(_ index:Int32) -> Int32
@_silgen_name("cs_clip_track_id") private func cs_clip_track_id(_ id:Int32) -> Int32
@_silgen_name("cs_clip_start_beat") private func cs_clip_start_beat(_ id:Int32) -> Double
@_silgen_name("cs_clip_length_beats") private func cs_clip_length_beats(_ id:Int32) -> Double
@_silgen_name("cs_clip_note_count") private func cs_clip_note_count(_ id:Int32) -> Int32
@_silgen_name("cs_clip_note_at") private func cs_clip_note_at(_ id:Int32,_ index:Int32,_ note:UnsafeMutablePointer<Int32>,_ vel:UnsafeMutablePointer<Int32>,_ start:UnsafeMutablePointer<Double>,_ length:UnsafeMutablePointer<Double>) -> Bool
@_silgen_name("cs_midi_import") private func cs_midi_import(_ path:UnsafePointer<CChar>,_ track:Int32,_ start:Double) -> Int32

struct EngineTrack { let id:Int; let name:String }
struct EngineMidiNote { let note:Int; let velocity:Int; let startBeat:Double; let lengthBeats:Double }
struct EngineClip { let id:Int; let trackId:Int; let startBeat:Double; let lengthBeats:Double; let notes:[EngineMidiNote] }

final class CompositionStudioEngine {
    static let shared=CompositionStudioEngine(); private(set) var initialized=false; private init(){}
    @discardableResult func initialize()->Bool { if initialized{return true}; initialized=cs_engine_initialize(); return initialized }
    func shutdown(){ guard initialized else{return}; cs_engine_shutdown(); initialized=false }
    var isReady:Bool{initialized && cs_engine_is_ready()}; var isPlaying:Bool{isReady && cs_engine_is_playing()}; var isRecording:Bool{isReady && cs_engine_is_recording()}
    var positionSeconds:Double{isReady ? cs_engine_position_seconds():0}; var tempo:Double{isReady ? cs_engine_tempo():120}; var isLooping:Bool{isReady && cs_engine_is_looping()}; var isMetronomeEnabled:Bool{isReady && cs_engine_metronome_enabled()}; var pluginCount:Int{isReady ? Int(cs_engine_plugin_count()):0}
    func play(){if isReady{cs_engine_play()}}; func stop(){if isReady{cs_engine_stop()}}; func pause(){if isReady{cs_engine_pause()}}; func record(){if isReady{cs_engine_record()}}; func locate(seconds:Double){if isReady{cs_engine_locate_seconds(seconds)}}; func setTempo(_ bpm:Double){if isReady{cs_engine_set_tempo(bpm)}}; func setLooping(_ b:Bool){if isReady{cs_engine_set_looping(b)}}; func setMetronome(_ b:Bool){if isReady{cs_engine_set_metronome(b)}}
    func tracks()->[EngineTrack]{ guard isReady else{return []}; return (0..<Int(cs_track_count())).compactMap{ i in var b=[CChar](repeating:0,count:256); guard cs_track_name_at(Int32(i),&b,256) else{return nil}; return EngineTrack(id:Int(cs_track_id_at(Int32(i))),name:String(cString:b)) } }
    @discardableResult func createTrack(name:String)->Int { guard isReady else{return -1}; return name.withCString{Int(cs_track_create($0))} }
    func deleteTrack(id:Int){if isReady{cs_track_delete(Int32(id))}}; func setTrackName(id:Int,name:String){if isReady{name.withCString{cs_track_set_name(Int32(id),$0)}}}; func setMuted(id:Int,_ b:Bool){if isReady{cs_track_set_muted(Int32(id),b)}}; func setSoloed(id:Int,_ b:Bool){if isReady{cs_track_set_soloed(Int32(id),b)}}; func setRecordArmed(id:Int,_ b:Bool){if isReady{cs_track_set_record_armed(Int32(id),b)}}
    func clips()->[EngineClip]{ guard isReady else{return []}; return (0..<Int(cs_clip_count())).map{ i in let id=Int(cs_clip_id_at(Int32(i))); let nc=Int(cs_clip_note_count(Int32(id))); let notes=(0..<nc).compactMap{j->EngineMidiNote? in var n:Int32=0,v:Int32=0; var s=0.0,l=0.0; guard cs_clip_note_at(Int32(id),Int32(j),&n,&v,&s,&l) else{return nil}; return EngineMidiNote(note:Int(n),velocity:Int(v),startBeat:s,lengthBeats:l)}; return EngineClip(id:id,trackId:Int(cs_clip_track_id(Int32(id))),startBeat:cs_clip_start_beat(Int32(id)),lengthBeats:cs_clip_length_beats(Int32(id)),notes:notes) } }
    @discardableResult func importMIDI(path:String,trackId:Int = -1,startBeat:Double = 0)->Int { guard isReady else{return -1}; return path.withCString{Int(cs_midi_import($0,Int32(trackId),startBeat))} }
    @discardableResult func saveProject(as path:String)->Bool{guard isReady else{return false};return path.withCString{cs_project_save_as($0)}}
    @discardableResult func loadProject(from path:String)->Bool{guard isReady else{return false};return path.withCString{cs_project_load($0)}}
}
