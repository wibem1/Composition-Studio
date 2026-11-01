-- GPL-3.0 independent smoke tests for unmodified REAPER-Notator v2.55 engraver.
-- Usage (repository root, Lua 5.3+): lua tests/test_notator_gpl_engraver.lua
-- Copyright (C) 2026 Composition-Studio contributors
-- SPDX-License-Identifier: GPL-3.0-only

-- These stand-ins are used ONLY for the pure timing functions. No drawing,
-- MIDI, ReaImGui or octave processing is invoked.
local old_constants=package.loaded["constants"]
local old_octave=package.loaded["services.octave_service"]
package.loaded["constants"]={SMUFL={},COLORS={}}
package.loaded["services.octave_service"]={}
local ok,eng=pcall(dofile,"vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua")
package.loaded["constants"]=old_constants
package.loaded["services.octave_service"]=old_octave
assert(ok,"Engraver cannot be loaded: "..tostring(eng))
assert(type(eng)=="table" and type(eng.quantize_notes_for_display)=="function")

local function approx(a,b)
 return type(a)=="number" and math.abs(a-b)<0.00001
end
local cases={
 {0.240,0.250},
 {0.365,0.375},
 {0.677,0.750},
 {0.135,0.125},
 {0.125,0.125}
}
for _,c in ipairs(cases) do
 local result=eng.get_nominal_rhythmic_duration(c[1])
 assert(approx(result,c[2]),"Nominal duration failed for "..tostring(c[1])..": "..tostring(result))
end

-- A note almost at the bar line stays inside its original 4/4 bar.
assert(approx(eng.get_display_quantized_qn(3.99,0.24,0.125,4,nil),3.875))
-- Two distinct onsets remain two visual notes, even with short playback gaps.
local originals={
 {pitch=81,chan=0,vel=100,start_qn=0.00,end_qn=0.240,dur_qn=0.240},
 {pitch=79,chan=0,vel=100,start_qn=0.375,end_qn=0.615,dur_qn=0.240}
}
local result=eng.quantize_notes_for_display(originals,0.125,4,nil,nil)
assert(type(result)=="table" and #result==2,"Expected two distinct visual notes")
assert(approx(originals[1].end_qn,0.240),"Original MIDI note was changed")
assert(approx(originals[2].start_qn,0.375),"Original MIDI note was changed")

-- Simultaneous notes form a chord; no MIDI note may disappear in this case.
local chord={
 {pitch=60,chan=0,start_qn=1.0,end_qn=1.24,dur_qn=0.24},
 {pitch=64,chan=0,start_qn=1.01,end_qn=1.25,dur_qn=0.24}
}
local scored=eng.quantize_notes_for_display(chord,0.125,4,nil,nil)
assert(type(scored)=="table" and #scored==2,"Simultaneous chord pitches lost")
print("OK: GPL v2.55 Engraver pure timing smoke tests; originals unchanged")
