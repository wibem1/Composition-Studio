# Experiment: individual notation display length (2026-11-04)

Status: IMPLEMENTED AS ISOLATED TEST SCRIPT; NOT TESTED IN LIVE REAPER; NOT RELEASED.

Baseline: Composition Studio main v1.1.9. This experiment does not alter the application, updater, settings, or original MIDI note events.

File: experiments/notation_display_length_test.lua

Goal: verify whether selected MIDI notes can be shown as eighth notes in the native REAPER notation editor while preserving original MIDI onset/duration. Script uses REAPER notation text events (type 15), NOTE channel pitch and disp_len delta measured in quarter notes, based on ReaTeam's public js_Notation displayed-length example. It retains other metadata in existing notation events. Only selected notes in editable MIDI editor takes are targeted. Undo is provided.

Limits: this is a deterministic feasibility probe, NOT AI, NOT intelligent quantization. It does not test disp_pos, beams, rests, tuplets, notation layout or same-pitch simultaneous notes. Matching note metadata by start PPQ/channel/pitch can be ambiguous with duplicate events. Test only on a project copy with a few non-duplicate selected notes. No runtime REAPER verification has occurred.

Next single step: open a project copy in REAPER 7.83, select two or three notes with non-eighth original lengths, run the script once, inspect score and compare original MIDI positions/durations; then Undo. Only if this passes, test disp_pos and AI integration.

References: https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20displayed%20length%20of%20selected%20notes%20to%20custom%20value.lua

## Next incremental step: read-only diagnostic

Added `experiments/notation_display_diagnostic.lua` on the same test branch. It reports selected note start/end PPQ, channel/pitch and any matching `disp_pos` / `disp_len` metadata without writing MIDI or notation events. The first experiment still needs a live REAPER verification before expanding to write `disp_pos` or introducing AI. Duplicate simultaneous same-pitch notes are explicitly flagged as ambiguous. This diagnostic has not been tested in REAPER; it is not a release.

Recommended minimal real check: in a copy of a REAPER project select 2–3 notes in MIDI editor, run the diagnostic, run the length experiment, run the diagnostic again, visually check eighth-note display and confirm original MIDI duration/positions; then Undo. If the metadata is written but the engraving remains unsuitable, stop and investigate rather than assuming AI will solve it.
