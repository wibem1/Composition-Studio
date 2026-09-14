#include "magda.hpp"
#include "engine/AudioEngine.hpp"

extern "C" {

bool cs_engine_initialize() {
    return magda_initialize();
}

void cs_engine_shutdown() {
    magda_shutdown();
}

bool cs_engine_is_ready() {
    return magda_get_engine() != nullptr;
}

void cs_engine_play() {
    if (auto* e = magda_get_engine()) e->play();
}

void cs_engine_stop() {
    if (auto* e = magda_get_engine()) e->stop();
}

void cs_engine_pause() {
    if (auto* e = magda_get_engine()) e->pause();
}

void cs_engine_record() {
    if (auto* e = magda_get_engine()) e->record();
}

bool cs_engine_is_playing() {
    if (auto* e = magda_get_engine()) return e->isPlaying();
    return false;
}

bool cs_engine_is_recording() {
    if (auto* e = magda_get_engine()) return e->isRecording();
    return false;
}

double cs_engine_position_seconds() {
    if (auto* e = magda_get_engine()) return e->getCurrentPosition();
    return 0.0;
}

void cs_engine_locate_seconds(double seconds) {
    if (auto* e = magda_get_engine()) e->locate(seconds < 0.0 ? 0.0 : seconds);
}

double cs_engine_tempo() {
    if (auto* e = magda_get_engine()) return e->getTempo();
    return 120.0;
}

void cs_engine_set_tempo(double bpm) {
    if (auto* e = magda_get_engine()) {
        if (bpm < 20.0) bpm = 20.0;
        if (bpm > 400.0) bpm = 400.0;
        e->setTempo(bpm);
    }
}

void cs_engine_set_looping(bool enabled) {
    if (auto* e = magda_get_engine()) e->setLooping(enabled);
}

bool cs_engine_is_looping() {
    if (auto* e = magda_get_engine()) return e->isLooping();
    return false;
}

void cs_engine_set_metronome(bool enabled) {
    if (auto* e = magda_get_engine()) e->setMetronomeEnabled(enabled);
}

bool cs_engine_metronome_enabled() {
    if (auto* e = magda_get_engine()) return e->isMetronomeEnabled();
    return false;
}

int cs_engine_plugin_count() {
    if (auto* e = magda_get_engine()) return e->getKnownPluginTypes().size();
    return 0;
}

}
