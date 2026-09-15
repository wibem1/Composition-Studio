#include "magda.hpp"
#include "engine/AudioEngine.hpp"
#include "project/ProjectManager.hpp"
#include "core/TrackManager.hpp"
#include "core/ClipManager.hpp"
#include <juce_audio_basics/juce_audio_basics.h>
#include <cstring>
#include <vector>

#if defined(__GNUC__) || defined(__clang__)
#define CS_V100_EXPORT __attribute__((visibility("default")))
#else
#define CS_V100_EXPORT
#endif

namespace {
void csCopyText(const juce::String& value, char* out, int capacity) {
    if (!out || capacity <= 0) return;
    auto utf8 = value.toUTF8();
    std::strncpy(out, utf8.getAddress(), static_cast<size_t>(capacity - 1));
    out[capacity - 1] = '\0';
}

constexpr int kMidiTPQ = 960;

void addClipNotesToSequence(const magda::ClipInfo& clip, juce::MidiMessageSequence& sequence,
                            double timelineOffsetBeats) {
    for (const auto& note : clip.midiNotes) {
        const auto pitch = juce::jlimit(0, 127, note.noteNumber);
        const auto velocity = static_cast<juce::uint8>(juce::jlimit(1, 127, note.velocity));
        const double startTicks = (timelineOffsetBeats + note.startBeat) * kMidiTPQ;
        const double endTicks = (timelineOffsetBeats + note.startBeat + juce::jmax(0.01, note.lengthBeats)) * kMidiTPQ;
        auto on = juce::MidiMessage::noteOn(1, pitch, velocity);
        auto off = juce::MidiMessage::noteOff(1, pitch);
        on.setTimeStamp(startTicks);
        off.setTimeStamp(endTicks);
        sequence.addEvent(on);
        sequence.addEvent(off);
    }
    sequence.updateMatchedPairs();
}

bool writeMidiFile(const juce::File& file, juce::MidiFile& midi) {
    if (file.existsAsFile() && !file.deleteFile()) return false;
    juce::FileOutputStream stream(file);
    if (!stream.openedOk()) return false;
    return midi.writeTo(stream);
}

int createImportedClipForSequence(const juce::MidiMessageSequence& source, int trackId,
                                  double startBeat, int tpq, const juce::String& clipName) {
    juce::MidiMessageSequence seq(source);
    seq.updateMatchedPairs();
    struct ImportedNote { int pitch; int velocity; double start; double length; };
    std::vector<ImportedNote> notes;
    double maxBeat = 0.0;
    for (int i = 0; i < seq.getNumEvents(); ++i) {
        auto* event = seq.getEventPointer(i);
        if (!event || !event->message.isNoteOn()) continue;
        const double s = event->message.getTimeStamp() / static_cast<double>(tpq);
        double e = s + 0.25;
        if (event->noteOffObject) e = event->noteOffObject->message.getTimeStamp() / static_cast<double>(tpq);
        const double l = juce::jmax(0.01, e - s);
        notes.push_back({event->message.getNoteNumber(), static_cast<int>(event->message.getVelocity()), s, l});
        maxBeat = juce::jmax(maxBeat, e);
    }
    if (notes.empty()) return -1;
    auto& cm = magda::ClipManager::getInstance();
    const int clipId = cm.createMidiClipBeats(trackId, startBeat, juce::jmax(1.0, maxBeat));
    if (clipId < 0) return -1;
    cm.setClipName(clipId, clipName);
    for (const auto& n : notes) cm.addMidiNote(clipId, {n.pitch, n.velocity, n.start, n.length});
    return clipId;
}
}

extern "C" {

CS_V100_EXPORT bool cs_project_new() {
    auto& project = magda::ProjectManager::getInstance();
    return project.newProject();
}

CS_V100_EXPORT float cs_track_volume(int trackId) {
    if (auto* track = magda::TrackManager::getInstance().getTrack(trackId)) return track->volume;
    return 1.0f;
}

CS_V100_EXPORT void cs_track_set_volume(int trackId, float value) {
    magda::TrackManager::getInstance().setTrackVolume(trackId, juce::jlimit(0.0f, 1.0f, value));
}

CS_V100_EXPORT float cs_track_pan(int trackId) {
    if (auto* track = magda::TrackManager::getInstance().getTrack(trackId)) return track->pan;
    return 0.0f;
}

CS_V100_EXPORT void cs_track_set_pan(int trackId, float value) {
    magda::TrackManager::getInstance().setTrackPan(trackId, juce::jlimit(-1.0f, 1.0f, value));
}

CS_V100_EXPORT bool cs_track_audio_output(int trackId, char* out, int capacity) {
    if (auto* track = magda::TrackManager::getInstance().getTrack(trackId)) {
        csCopyText(track->audioOutputDevice.isEmpty() ? juce::String("master") : track->audioOutputDevice, out, capacity);
        return true;
    }
    return false;
}

CS_V100_EXPORT void cs_track_set_audio_output(int trackId, const char* routing) {
    if (!routing) return;
    magda::TrackManager::getInstance().setTrackAudioOutput(trackId, juce::String::fromUTF8(routing));
}

CS_V100_EXPORT bool cs_track_midi_input(int trackId, char* out, int capacity) {
    if (auto* track = magda::TrackManager::getInstance().getTrack(trackId)) {
        csCopyText(track->midiInputDevice, out, capacity);
        return true;
    }
    return false;
}

CS_V100_EXPORT void cs_track_set_midi_input(int trackId, const char* routing) {
    if (!routing) return;
    magda::TrackManager::getInstance().setTrackMidiInput(trackId, juce::String::fromUTF8(routing));
}

CS_V100_EXPORT bool cs_track_chain_summary(int trackId, char* out, int capacity) {
    const auto chain = magda::TrackManager::getInstance().getChainSummary(trackId);
    juce::String summary;
    for (size_t i = 0; i < chain.size(); ++i) {
        if (i > 0) summary << "  →  ";
        summary << juce::String(chain[i]);
    }
    if (summary.isEmpty()) summary = "Keine Inserts";
    csCopyText(summary, out, capacity);
    return true;
}

CS_V100_EXPORT bool cs_clip_name(int clipId, char* out, int capacity) {
    if (auto* clip = magda::ClipManager::getInstance().getClip(clipId)) {
        csCopyText(clip->name, out, capacity);
        return true;
    }
    return false;
}

CS_V100_EXPORT int cs_clip_create_midi(int trackId, double startBeat, double lengthBeats, const char* name) {
    auto& cm = magda::ClipManager::getInstance();
    const int clipId = cm.createMidiClipBeats(trackId, juce::jmax(0.0, startBeat), juce::jmax(0.25, lengthBeats));
    if (clipId >= 0 && name && *name) cm.setClipName(clipId, juce::String::fromUTF8(name));
    return clipId;
}

CS_V100_EXPORT void cs_clip_delete(int clipId) {
    magda::ClipManager::getInstance().deleteClip(clipId);
}

CS_V100_EXPORT int cs_clip_duplicate(int clipId) {
    return magda::ClipManager::getInstance().duplicateClip(clipId);
}

CS_V100_EXPORT int cs_clip_duplicate_at(int clipId, double startBeat, int trackId) {
    return magda::ClipManager::getInstance().duplicateClipAtBeats(clipId, juce::jmax(0.0, startBeat), trackId);
}

CS_V100_EXPORT void cs_clip_move(int clipId, double startBeat, int trackId) {
    auto& cm = magda::ClipManager::getInstance();
    if (trackId >= 0) cm.moveClipToTrack(clipId, trackId);
    cm.moveClipBeats(clipId, juce::jmax(0.0, startBeat));
}

CS_V100_EXPORT void cs_clip_resize(int clipId, double lengthBeats) {
    magda::ClipManager::getInstance().resizeClipBeats(clipId, juce::jmax(0.25, lengthBeats));
}

CS_V100_EXPORT void cs_clip_clear_midi(int clipId) {
    magda::ClipManager::getInstance().clearMidiNotes(clipId);
}

CS_V100_EXPORT bool cs_clip_add_note(int clipId, int pitch, int velocity, double startBeat, double lengthBeats) {
    return magda::ClipManager::getInstance().addMidiNote(
        clipId,
        {juce::jlimit(0, 127, pitch), juce::jlimit(1, 127, velocity), juce::jmax(0.0, startBeat), juce::jmax(0.01, lengthBeats)});
}

CS_V100_EXPORT bool cs_clip_update_note(int clipId, int index, int pitch, int velocity,
                                        double startBeat, double lengthBeats) {
    auto& cm = magda::ClipManager::getInstance();
    auto* clip = cm.getClip(clipId);
    if (!clip || index < 0 || index >= static_cast<int>(clip->midiNotes.size())) return false;
    auto note = clip->midiNotes[static_cast<size_t>(index)];
    note.noteNumber = juce::jlimit(0, 127, pitch);
    note.velocity = juce::jlimit(1, 127, velocity);
    note.startBeat = juce::jmax(0.0, startBeat);
    note.lengthBeats = juce::jmax(0.01, lengthBeats);
    clip->midiNotes[static_cast<size_t>(index)] = note;
    cm.forceNotifyClipPropertyChanged(clipId);
    return true;
}

CS_V100_EXPORT void cs_clip_delete_note(int clipId, int index) {
    magda::ClipManager::getInstance().removeMidiNote(clipId, index);
}

CS_V100_EXPORT void cs_track_preview_note(int trackId, int pitch, int velocity, bool noteOn) {
    magda::TrackManager::getInstance().previewNote(trackId, juce::jlimit(0, 127, pitch),
                                                   juce::jlimit(0, 127, velocity), noteOn);
}

CS_V100_EXPORT bool cs_midi_export_clip(int clipId, const char* path) {
    if (!path || !*path) return false;
    auto* clip = magda::ClipManager::getInstance().getClip(clipId);
    if (!clip || !clip->isMidi()) return false;
    juce::MidiFile midi;
    midi.setTicksPerQuarterNote(kMidiTPQ);
    juce::MidiMessageSequence sequence;
    addClipNotesToSequence(*clip, sequence, 0.0);
    midi.addTrack(sequence);
    return writeMidiFile(juce::File(juce::String::fromUTF8(path)), midi);
}

CS_V100_EXPORT bool cs_midi_export_project(const char* path) {
    if (!path || !*path) return false;
    auto& tm = magda::TrackManager::getInstance();
    auto& cm = magda::ClipManager::getInstance();
    juce::MidiFile midi;
    midi.setTicksPerQuarterNote(kMidiTPQ);
    bool hasTrack = false;
    for (const auto& track : tm.getTracks()) {
        juce::MidiMessageSequence sequence;
        for (const auto clipId : cm.getClipsOnTrack(track.id, magda::ClipView::Arrangement)) {
            if (auto* clip = cm.getClip(clipId); clip && clip->isMidi())
                addClipNotesToSequence(*clip, sequence, clip->placement.startBeat);
        }
        if (sequence.getNumEvents() > 0) {
            midi.addTrack(sequence);
            hasTrack = true;
        }
    }
    if (!hasTrack) return false;
    return writeMidiFile(juce::File(juce::String::fromUTF8(path)), midi);
}

CS_V100_EXPORT int cs_midi_import_multitrack(const char* path, double startBeat) {
    if (!path || !*path) return -1;
    const juce::File file(juce::String::fromUTF8(path));
    juce::FileInputStream stream(file);
    if (!stream.openedOk()) return -1;
    juce::MidiFile midi;
    if (!midi.readFrom(stream)) return -1;
    const int tpq = midi.getTimeFormat();
    if (tpq <= 0) return -1;
    auto& tm = magda::TrackManager::getInstance();
    int firstClip = -1;
    int createdIndex = 0;
    for (int i = 0; i < midi.getNumTracks(); ++i) {
        const auto* source = midi.getTrack(i);
        if (!source) continue;
        bool hasNotes = false;
        for (int e = 0; e < source->getNumEvents(); ++e) {
            if (auto* event = source->getEventPointer(e); event && event->message.isNoteOn()) {
                hasNotes = true;
                break;
            }
        }
        if (!hasNotes) continue;
        ++createdIndex;
        const juce::String trackName = midi.getNumTracks() > 1
            ? file.getFileNameWithoutExtension() + " " + juce::String(createdIndex)
            : file.getFileNameWithoutExtension();
        const int trackId = tm.createTrack(trackName);
        if (trackId < 0) continue;
        const int clipId = createImportedClipForSequence(*source, trackId, juce::jmax(0.0, startBeat), tpq, trackName);
        if (clipId >= 0 && firstClip < 0) firstClip = clipId;
    }
    return firstClip;
}

} // extern "C"
