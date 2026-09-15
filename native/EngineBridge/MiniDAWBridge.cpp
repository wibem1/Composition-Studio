#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "core/TrackManager.hpp"
#include "core/ClipManager.hpp"

#if defined(__GNUC__) || defined(__clang__)
#define MD_EXPORT __attribute__((visibility("default")))
#else
#define MD_EXPORT
#endif

extern "C" {
MD_EXPORT void md_start_plugin_scan() {
    if (auto* e = magda_get_engine()) e->startPluginScan();
}
MD_EXPORT bool md_plugin_scan_running() {
    if (auto* e = magda_get_engine()) return e->isPluginScanRunning();
    return false;
}
MD_EXPORT int md_create_test_session() {
    auto& tm = magda::TrackManager::getInstance();
    auto& cm = magda::ClipManager::getInstance();
    int track = tm.createTrack("MiniDAW Test");
    if (track < 0) return -1;
    int clip = cm.createMidiClipBeats(track, 0.0, 8.0);
    if (clip < 0) return -2;
    if (auto* c = cm.getClip(clip)) c->name = "Vier Noten";
    cm.addMidiNote(clip, {60, 100, 0.0, 0.8});
    cm.addMidiNote(clip, {64, 100, 1.0, 0.8});
    cm.addMidiNote(clip, {67, 100, 2.0, 0.8});
    cm.addMidiNote(clip, {72, 100, 3.0, 0.8});
    if (auto* e = magda_get_engine()) { e->setTempo(120.0); e->locate(0.0); }
    return track;
}
MD_EXPORT double md_audio_thread_position() {
    if (auto* e = magda_get_engine()) return e->getAudioThreadTransportSeconds();
    return -1.0;
}
MD_EXPORT void md_preview_note(int trackId, int note, bool on) {
    if (auto* e = magda_get_engine()) e->previewNoteOnTrack(std::to_string(trackId), note, on ? 100 : 0, on);
}
}
