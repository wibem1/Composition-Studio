#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "core/TrackManager.hpp"
#include "core/ClipManager.hpp"
#include <juce_audio_devices/juce_audio_devices.h>
#include <atomic>
#include <cmath>
#include <cstring>
#include <memory>

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

class AudioDeviceCore final : public juce::AudioIODeviceCallback {
public:
    ~AudioDeviceCore() override { stop(); }
    bool start() {
        stop(); callbacks.store(0); peak.store(0.0f); energy.store(0.0); phase = 0.0; remainingSamples.store(0); lastError.clear();
        auto result = deviceManager.initialise(0, 2, nullptr, true);
        if (!result.isEmpty()) { lastError = result; return false; }
        auto* device = deviceManager.getCurrentAudioDevice();
        if (!device) { lastError = "JUCE opened no current audio device"; deviceManager.closeAudioDevice(); return false; }
        sampleRate.store(device->getCurrentSampleRate()); bufferSize.store(device->getCurrentBufferSizeSamples());
        activeOutputs.store(deviceManager.getAudioDeviceSetup().outputChannels.countNumberOfSetBits()); deviceName = device->getName();
        if (sampleRate.load() <= 0.0 || activeOutputs.load() <= 0) { lastError = "Audio device has no active output channel or sample rate"; deviceManager.closeAudioDevice(); return false; }
        deviceManager.addAudioCallback(this); running.store(true); return true;
    }
    void stop() {
        running.store(false);
        deviceManager.removeAudioCallback(this);
        deviceManager.closeAudioDevice();
        remainingSamples.store(0);
    }
    void testTone(double seconds) { if (!running.load()) return; auto sr=sampleRate.load(); remainingSamples.store(static_cast<int64_t>(std::max(0.05,std::min(seconds,3.0))*sr)); }
    void audioDeviceIOCallbackWithContext(const float* const*, int, float* const* outputs, int numOutputs, int numSamples, const juce::AudioIODeviceCallbackContext&) override {
        callbacks.fetch_add(1,std::memory_order_relaxed); const double sr=sampleRate.load(std::memory_order_relaxed); const double step=sr>0.0?juce::MathConstants<double>::twoPi*440.0/sr:0.0;
        float localPeak=0.0f; double localEnergy=0.0; auto remaining=remainingSamples.load(std::memory_order_relaxed);
        for(int ch=0;ch<numOutputs;++ch) if(outputs[ch]) juce::FloatVectorOperations::clear(outputs[ch],numSamples);
        for(int i=0;i<numSamples;++i){ float sample=0.0f; if(remaining>0){ sample=static_cast<float>(std::sin(phase)*0.08); phase+=step; if(phase>=juce::MathConstants<double>::twoPi) phase-=juce::MathConstants<double>::twoPi; --remaining; } localPeak=std::max(localPeak,std::abs(sample)); localEnergy+=static_cast<double>(sample)*sample; for(int ch=0;ch<numOutputs;++ch) if(outputs[ch]) outputs[ch][i]=sample; }
        remainingSamples.store(remaining,std::memory_order_relaxed); peak.store(std::max(peak.load(std::memory_order_relaxed),localPeak),std::memory_order_relaxed); energy.store(energy.load(std::memory_order_relaxed)+localEnergy,std::memory_order_relaxed);
    }
    void audioDeviceAboutToStart(juce::AudioIODevice* d) override { if(d){ sampleRate.store(d->getCurrentSampleRate()); bufferSize.store(d->getCurrentBufferSizeSamples()); } }
    void audioDeviceStopped() override {}
    void audioDeviceError(const juce::String& errorMessage) override { lastError=errorMessage; }
    juce::AudioDeviceManager deviceManager; std::atomic<bool> running{false}; std::atomic<uint64_t> callbacks{0}; std::atomic<double> sampleRate{0.0}; std::atomic<int> bufferSize{0}; std::atomic<int> activeOutputs{0}; std::atomic<float> peak{0.0f}; std::atomic<double> energy{0.0}; std::atomic<int64_t> remainingSamples{0}; juce::String deviceName,lastError; double phase=0.0;
};
std::unique_ptr<AudioDeviceCore> directAudio;
juce::String pluginAudioError;
}

extern "C" {
MD_EXPORT bool md_direct_audio_start(){ if(!directAudio) directAudio=std::make_unique<AudioDeviceCore>(); return directAudio->start(); }
MD_EXPORT void md_direct_audio_stop(){ if(directAudio){ directAudio->stop(); directAudio.reset(); } }
MD_EXPORT void md_direct_audio_test_tone(double seconds){ if(directAudio) directAudio->testTone(seconds); }
MD_EXPORT bool md_direct_audio_running(){ return directAudio&&directAudio->running.load(); }
MD_EXPORT unsigned long long md_direct_audio_callbacks(){ return directAudio?directAudio->callbacks.load():0; }
MD_EXPORT double md_direct_audio_sample_rate(){ return directAudio?directAudio->sampleRate.load():0.0; }
MD_EXPORT int md_direct_audio_buffer_size(){ return directAudio?directAudio->bufferSize.load():0; }
MD_EXPORT int md_direct_audio_active_outputs(){ return directAudio?directAudio->activeOutputs.load():0; }
MD_EXPORT double md_direct_audio_peak(){ return directAudio?directAudio->peak.load():0.0; }
MD_EXPORT double md_direct_audio_energy(){ return directAudio?directAudio->energy.load():0.0; }
MD_EXPORT bool md_direct_audio_device_name(char*out,int cap){ return directAudio&&copyString(directAudio->deviceName,out,cap); }
MD_EXPORT bool md_direct_audio_error(char*out,int cap){ return directAudio&&copyString(directAudio->lastError,out,cap); }

MD_EXPORT bool md_prepare_plugin_audio(){
    pluginAudioError.clear();
    auto* e=magda_get_engine(); if(!e){ pluginAudioError="MAGDA engine missing"; return false; }
    auto* dm=e->getDeviceManager(); if(!dm){ pluginAudioError="MAGDA JUCE device manager missing"; return false; }
    if(!dm->getCurrentAudioDevice()){
        auto result=dm->initialise(0,2,nullptr,true);
        if(!result.isEmpty()){ pluginAudioError=result; return false; }
    }
    auto* device=dm->getCurrentAudioDevice(); if(!device){ pluginAudioError="MAGDA opened no audio output device"; return false; }
    auto setup=dm->getAudioDeviceSetup();
    juce::BigInteger outputs; outputs.setRange(0,device->getOutputChannelNames().size(),true);
    setup.outputChannels=outputs; setup.useDefaultOutputChannels=false;
    auto result=dm->setAudioDeviceSetup(setup,true); if(!result.isEmpty()){ pluginAudioError=result; return false; }
    e->rescanWaveDevices(false,true);
    e->setEnabledWaveChannels(false,outputs);
    if(dm->getAudioDeviceSetup().outputChannels.countNumberOfSetBits()<=0){ pluginAudioError="MAGDA has no enabled JUCE output channels"; return false; }
    return true;
}
MD_EXPORT bool md_plugin_audio_device_name(char*out,int cap){ auto*e=magda_get_engine(); auto*dm=e?e->getDeviceManager():nullptr; auto*d=dm?dm->getCurrentAudioDevice():nullptr; return d&&copyString(d->getName(),out,cap); }
MD_EXPORT int md_plugin_audio_active_outputs(){ auto*e=magda_get_engine(); auto*dm=e?e->getDeviceManager():nullptr; return dm?dm->getAudioDeviceSetup().outputChannels.countNumberOfSetBits():0; }
MD_EXPORT bool md_plugin_audio_error(char*out,int cap){ return copyString(pluginAudioError,out,cap); }

MD_EXPORT void md_start_plugin_scan(){ if(auto*e=magda_get_engine())e->startPluginScan(); }
MD_EXPORT bool md_plugin_scan_running(){ if(auto*e=magda_get_engine())return e->isPluginScanRunning(); return false; }
MD_EXPORT int md_create_test_session(){ auto&tm=magda::TrackManager::getInstance(); auto&cm=magda::ClipManager::getInstance(); int track=tm.createTrack("MiniDAW Test"); if(track<0)return -1; int clip=cm.createMidiClipBeats(track,0.0,8.0); if(clip<0)return -2; if(auto*c=cm.getClip(clip))c->name="Vier Noten"; cm.addMidiNote(clip,{60,100,0.0,0.8}); cm.addMidiNote(clip,{64,100,1.0,0.8}); cm.addMidiNote(clip,{67,100,2.0,0.8}); cm.addMidiNote(clip,{72,100,3.0,0.8}); if(auto*e=magda_get_engine()){e->setTempo(120.0);e->locate(0.0);} return track; }
MD_EXPORT double md_audio_thread_position(){ if(auto*e=magda_get_engine())return e->getAudioThreadTransportSeconds(); return -1.0; }
MD_EXPORT void md_preview_note(int trackId,int note,bool on){ if(auto*e=magda_get_engine())e->previewNoteOnTrack(std::to_string(trackId),note,on?100:0,on); }
MD_EXPORT int md_audio_output_count(){ if(auto*type=currentAudioType())return type->getDeviceNames(false).size(); return 0; }
MD_EXPORT bool md_audio_output_name(int index,char*out,int cap){ auto*type=currentAudioType(); if(!type)return false; auto names=type->getDeviceNames(false); if(index<0||index>=names.size())return false; return copyString(names[index],out,cap); }
MD_EXPORT bool md_current_audio_output(char*out,int cap){ auto*e=magda_get_engine(); auto*dm=e?e->getDeviceManager():nullptr; if(!dm)return false; return copyString(dm->getAudioDeviceSetup().outputDeviceName,out,cap); }
MD_EXPORT bool md_select_audio_output(int index){ auto*e=magda_get_engine(); auto*dm=e?e->getDeviceManager():nullptr; auto*type=currentAudioType(); if(!dm||!type)return false; auto names=type->getDeviceNames(false); if(index<0||index>=names.size())return false; auto setup=dm->getAudioDeviceSetup(); setup.outputDeviceName=names[index]; auto result=dm->setAudioDeviceSetup(setup,true); if(!result.isEmpty())return false; e->rescanWaveDevices(false,true); if(auto*device=dm->getCurrentAudioDevice()){ juce::BigInteger outputs; outputs.setRange(0,device->getOutputChannelNames().size(),true); auto active=dm->getAudioDeviceSetup(); active.outputChannels=outputs; active.useDefaultOutputChannels=false; if(!dm->setAudioDeviceSetup(active,true).isEmpty())return false; e->setEnabledWaveChannels(false,outputs); } return true; }
}