#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "core/TrackManager.hpp"
#include "core/ClipManager.hpp"
#include <juce_audio_devices/juce_audio_devices.h>
#include <cstring>

#if defined(__GNUC__) || defined(__clang__)
#define MD_EXPORT __attribute__((visibility("default")))
#else
#define MD_EXPORT
#endif

namespace {
juce::AudioIODeviceType* currentAudioType() {
    auto* e = magda_get_engine();
    if (!e) return nullptr;
    auto* dm = e->getDeviceManager();
    if (!dm) return nullptr;
    auto* type = dm->getCurrentDeviceTypeObject();
    if (type) type->scanForDevices();
    return type;
}

bool copyString(const juce::String& s, char* out, int cap) {
    if (!out || cap <= 0) return false;
    auto utf8 = s.toRawUTF8();
    std::strncpy(out, utf8, static_cast<size_t>(cap - 1));
    out[cap - 1] = '\0';
    return true;
}
}

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
MD_EXPORT int md_audio_output_count() {
    if (auto* type = currentAudioType()) return type->getDeviceNames(false).size();
    return 0;
}
MD_EXPORT bool md_audio_output_name(int index, char* out, int cap) {
    auto* type = currentAudioType();
    if (!type) return false;
    auto names = type->getDeviceNames(false);
    if (index < 0 || index >= names.size()) return false;
    return copyString(names[index], out, cap);
}
MD_EXPORT bool md_current_audio_output(char* out, int cap) {
    auto* e = magda_get_engine();
    auto* dm = e ? e->getDeviceManager() : nullptr;
    if (!dm) return false;
    auto setup = dm->getAudioDeviceSetup();
    return copyString(setup.outputDeviceName, out, cap);
}
MD_EXPORT bool md_select_audio_output(int index) {
    auto* e = magda_get_engine();
    auto* dm = e ? e->getDeviceManager() : nullptr;
    auto* type = currentAudioType();
    if (!dm || !type) return false;
    auto names = type->getDeviceNames(false);
    if (index < 0 || index >= names.size()) return false;

    auto setup = dm->getAudioDeviceSetup();
    setup.outputDeviceName = names[index];
    auto result = dm->setAudioDeviceSetup(setup, true);
    if (!result.isEmpty()) {
        setup.inputDeviceName = names[index];
        result = dm->setAudioDeviceSetup(setup, true);
    }
    if (!result.isEmpty()) return false;

    if (auto* device = dm->getCurrentAudioDevice()) {
        juce::BigInteger outputs;
        outputs.setRange(0, device->getOutputChannelNames().size(), true);
        auto active = dm->getAudioDeviceSetup();
        active.outputChannels = outputs;
        if (!dm->setAudioDeviceSetup(active, true).isEmpty()) return false;
        e->setEnabledWaveChannels(false, outputs);
    }
    return true;
}
}
