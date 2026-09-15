#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "project/ProjectManager.hpp"
#include "core/TrackManager.hpp"
#include "core/ClipManager.hpp"
#include <juce_audio_basics/juce_audio_basics.h>
#include <cstring>

#if defined(__GNUC__) || defined(__clang__)
#define CS_EXPORT __attribute__((visibility("default")))
#else
#define CS_EXPORT
#endif

namespace {
void copyUtf8(const juce::String& s, char* out, int capacity) {
    if (!out || capacity <= 0) return;
    auto utf8 = s.toUTF8();
    std::strncpy(out, utf8.getAddress(), static_cast<size_t>(capacity - 1));
    out[capacity - 1] = '\0';
}
}

extern "C" {
CS_EXPORT bool cs_engine_initialize() { if (!magda_initialize()) return false; auto& p=magda::ProjectManager::getInstance(); if(!p.hasOpenProject()) p.newProject(); return true; }
CS_EXPORT void cs_engine_shutdown() { magda_shutdown(); }
CS_EXPORT bool cs_engine_is_ready() { return magda_get_engine()!=nullptr; }
CS_EXPORT void cs_engine_play(){ if(auto*e=magda_get_engine())e->play(); }
CS_EXPORT void cs_engine_stop(){ if(auto*e=magda_get_engine())e->stop(); }
CS_EXPORT void cs_engine_pause(){ if(auto*e=magda_get_engine())e->pause(); }
CS_EXPORT void cs_engine_record(){ if(auto*e=magda_get_engine())e->record(); }
CS_EXPORT bool cs_engine_is_playing(){ if(auto*e=magda_get_engine())return e->isPlaying(); return false; }
CS_EXPORT bool cs_engine_is_recording(){ if(auto*e=magda_get_engine())return e->isRecording(); return false; }
CS_EXPORT double cs_engine_position_seconds(){ if(auto*e=magda_get_engine())return e->getCurrentPosition(); return 0; }
CS_EXPORT void cs_engine_locate_seconds(double s){ if(auto*e=magda_get_engine())e->locate(s<0?0:s); }
CS_EXPORT double cs_engine_tempo(){ if(auto*e=magda_get_engine())return e->getTempo(); return 120; }
CS_EXPORT void cs_engine_set_tempo(double bpm){ bpm=juce::jlimit(20.0,400.0,bpm); if(auto*e=magda_get_engine())e->setTempo(bpm); magda::ProjectManager::getInstance().setTempo(bpm); }
CS_EXPORT void cs_engine_set_looping(bool b){ if(auto*e=magda_get_engine())e->setLooping(b); }
CS_EXPORT bool cs_engine_is_looping(){ if(auto*e=magda_get_engine())return e->isLooping(); return false; }
CS_EXPORT void cs_engine_set_metronome(bool b){ if(auto*e=magda_get_engine())e->setMetronomeEnabled(b); }
CS_EXPORT bool cs_engine_metronome_enabled(){ if(auto*e=magda_get_engine())return e->isMetronomeEnabled(); return false; }
CS_EXPORT int cs_engine_plugin_count(){ if(auto*e=magda_get_engine())return (int)e->getKnownPluginTypes().size(); return 0; }

CS_EXPORT int cs_track_count(){ return magda::TrackManager::getInstance().getNumTracks(); }
CS_EXPORT int cs_track_id_at(int index){ const auto& t=magda::TrackManager::getInstance().getTracks(); return index>=0&&index<(int)t.size()?t[(size_t)index].id:-1; }
CS_EXPORT bool cs_track_name_at(int index,char*out,int cap){ const auto&t=magda::TrackManager::getInstance().getTracks(); if(index<0||index>=(int)t.size())return false; copyUtf8(t[(size_t)index].name,out,cap); return true; }
CS_EXPORT int cs_track_create(const char*name){ return magda::TrackManager::getInstance().createTrack(name?juce::String::fromUTF8(name):juce::String("MIDI")); }
CS_EXPORT void cs_track_delete(int id){ magda::TrackManager::getInstance().deleteTrack(id); }
CS_EXPORT void cs_track_set_name(int id,const char*name){ if(name)magda::TrackManager::getInstance().setTrackName(id,juce::String::fromUTF8(name)); }
CS_EXPORT void cs_track_set_muted(int id,bool b){ magda::TrackManager::getInstance().setTrackMuted(id,b); }
CS_EXPORT void cs_track_set_soloed(int id,bool b){ magda::TrackManager::getInstance().setTrackSoloed(id,b); }
CS_EXPORT void cs_track_set_record_armed(int id,bool b){ magda::TrackManager::getInstance().setTrackRecordArmed(id,b); }

CS_EXPORT int cs_clip_count(){ return (int)magda::ClipManager::getInstance().getArrangementClips().size(); }
CS_EXPORT int cs_clip_id_at(int index){ auto c=magda::ClipManager::getInstance().getArrangementClips(); return index>=0&&index<(int)c.size()?c[(size_t)index].id:-1; }
CS_EXPORT int cs_clip_track_id(int id){ auto*c=magda::ClipManager::getInstance().getClip(id); return c?c->trackId:-1; }
CS_EXPORT double cs_clip_start_beat(int id){ auto*c=magda::ClipManager::getInstance().getClip(id); return c?c->placement.startBeat:0; }
CS_EXPORT double cs_clip_length_beats(int id){ auto*c=magda::ClipManager::getInstance().getClip(id); return c?c->placement.lengthBeats:0; }
CS_EXPORT int cs_clip_note_count(int id){ auto*c=magda::ClipManager::getInstance().getClip(id); return c?(int)c->midiNotes.size():0; }
CS_EXPORT bool cs_clip_note_at(int id,int index,int*note,int*vel,double*start,double*length){ auto*c=magda::ClipManager::getInstance().getClip(id); if(!c||index<0||index>=(int)c->midiNotes.size())return false; const auto&n=c->midiNotes[(size_t)index]; if(note)*note=n.noteNumber; if(vel)*vel=n.velocity; if(start)*start=n.startBeat; if(length)*length=n.lengthBeats; return true; }
CS_EXPORT int cs_midi_import(const char*path,int trackId,double startBeat){
    if(!path)return -1; juce::FileInputStream stream(juce::File(juce::String::fromUTF8(path))); if(!stream.openedOk())return -1;
    juce::MidiFile mf; if(!mf.readFrom(stream))return -1; const int tpq=mf.getTimeFormat(); if(tpq<=0)return -1;
    double maxBeat=0; struct N{int p,v;double s,l;}; std::vector<N> notes;
    for(int ti=0;ti<mf.getNumTracks();++ti){ auto*seq=mf.getTrack(ti); if(!seq)continue; seq->updateMatchedPairs(); for(int i=0;i<seq->getNumEvents();++i){ auto*ev=seq->getEventPointer(i); if(!ev||!ev->message.isNoteOn())continue; double s=ev->message.getTimeStamp()/tpq; double e=s+0.25; if(ev->noteOffObject)e=ev->noteOffObject->message.getTimeStamp()/tpq; double l=juce::jmax(0.01,e-s); notes.push_back({ev->message.getNoteNumber(),(int)ev->message.getVelocity(),s,l}); maxBeat=juce::jmax(maxBeat,e); }}
    if(trackId<0)trackId=magda::TrackManager::getInstance().createTrack(juce::File(juce::String::fromUTF8(path)).getFileNameWithoutExtension()); if(trackId<0)return -1;
    auto&cm=magda::ClipManager::getInstance(); int clipId=cm.createMidiClipBeats(trackId,startBeat,juce::jmax(1.0,maxBeat)); if(clipId<0)return -1; if(auto*c=cm.getClip(clipId))c->name=juce::File(juce::String::fromUTF8(path)).getFileNameWithoutExtension();
    for(const auto&n:notes)cm.addMidiNote(clipId,{n.p,n.v,n.s,n.l}); return clipId;
}

CS_EXPORT bool cs_project_save_as(const char*path){ if(!path||!*path)return false; auto&p=magda::ProjectManager::getInstance(); if(!p.hasOpenProject()&&!p.newProject())return false; return p.saveProjectAs(juce::File(juce::String::fromUTF8(path))); }
CS_EXPORT bool cs_project_load(const char*path){ if(!path||!*path)return false; auto&p=magda::ProjectManager::getInstance(); return p.loadProject(juce::File(juce::String::fromUTF8(path)),[](const magda::ProjectInfo&i){if(auto*e=magda_get_engine()){e->setTempo(i.tempo);e->setTimeSignature(i.timeSignatureNumerator,i.timeSignatureDenominator);}}); }
}
