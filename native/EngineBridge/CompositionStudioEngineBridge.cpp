#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "project/ProjectManager.hpp"

#if defined(__GNUC__) || defined(__clang__)
#define CS_EXPORT __attribute__((visibility("default")))
#else
#define CS_EXPORT
#endif

extern "C" {

CS_EXPORT bool cs_engine_initialize() {
    if (!magda_initialize()) return false;
    auto& projects = magda::ProjectManager::getInstance();
    if (!projects.hasOpenProject()) projects.newProject();
    return true;
}

CS_EXPORT void cs_engine_shutdown() {
    magda_shutdown();
}

CS_EXPORT bool cs_engine_is_ready() {
    return magda_get_engine() != nullptr;
}

CS_EXPORT void cs_engine_play() {
    if (auto* e = magda_get_engine()) e->play();
}

CS_EXPORT void cs_engine_stop() {
    if (auto* e = magda_get_engine()) e->stop();
}

CS_EXPORT void cs_engine_pause() {
    if (auto* e = magda_get_engine()) e->pause();
}

CS_EXPORT void cs_engine_record() {
    if (auto* e = magda_get_engine()) e->record();
}

CS_EXPORT bool cs_engine_is_playing() {
    if (auto* e = magda_get_engine()) return e->isPlaying();
    return false;
}

CS_EXPORT bool cs_engine_is_recording() {
    if (auto* e = magda_get_engine()) return e->isRecording();
    return false;
}

CS_EXPORT double cs_engine_position_seconds() {
    if (auto* e = magda_get_engine()) return e->getCurrentPosition();
    return 0.0;
}

CS_EXPORT void cs_engine_locate_seconds(double seconds) {
    if (auto* e = magda_get_engine()) e->locate(seconds < 0.0 ? 0.0 : seconds);
}

CS_EXPORT double cs_engine_tempo() {
    if (auto* e = magda_get_engine()) return e->getTempo();
    return 120.0;
}

CS_EXPORT void cs_engine_set_tempo(double bpm) {
    if (bpm < 20.0) bpm = 20.0;
    if (bpm > 400.0) bpm = 400.0;
    if (auto* e = magda_get_engine()) e->setTempo(bpm);
    magda::ProjectManager::getInstance().setTempo(bpm);
}

CS_EXPORT void cs_engine_set_looping(bool enabled) {
    if (auto* e = magda_get_engine()) e->setLooping(enabled);
}

CS_EXPORT bool cs_engine_is_looping() {
    if (auto* e = magda_get_engine()) return e->isLooping();
    return false;
}

CS_EXPORT void cs_engine_set_metronome(bool enabled) {
    if (auto* e = magda_get_engine()) e->setMetronomeEnabled(enabled);
}

CS_EXPORT bool cs_engine_metronome_enabled() {
    if (auto* e = magda_get_engine()) return e->isMetronomeEnabled();
    return false;
}

CS_EXPORT int cs_engine_plugin_count() {
    if (auto* e = magda_get_engine()) return static_cast<int>(e->getKnownPluginTypes().size());
    return 0;
}

CS_EXPORT bool cs_project_save_as(const char* utf8Path) {
    if (utf8Path == nullptr || *utf8Path == '\0') return false;
    auto& projects = magda::ProjectManager::getInstance();
    if (!projects.hasOpenProject() && !projects.newProject()) return false;
    const juce::File file(juce::String::fromUTF8(utf8Path));
    return projects.saveProjectAs(file);
}

CS_EXPORT bool cs_project_load(const char* utf8Path) {
    if (utf8Path == nullptr || *utf8Path == '\0') return false;
    const juce::File file(juce::String::fromUTF8(utf8Path));
    auto& projects = magda::ProjectManager::getInstance();
    return projects.loadProject(file, [](const magda::ProjectInfo& info) {
        if (auto* e = magda_get_engine()) {
            e->setTempo(info.tempo);
            e->setTimeSignature(info.timeSignatureNumerator, info.timeSignatureDenominator);
        }
    });
}

}
