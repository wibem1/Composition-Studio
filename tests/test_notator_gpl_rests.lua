-- GPL-3.0 (Composition Studio test; upstream engine © 2026 A-intheCode)
-- Run in repo root: lua tests/test_notator_gpl_rests.lua
-- SPDX-License-Identifier: GPL-3.0-only
-- This test only exercises the original read-only Engraver rest logic.

local old_constants=package.loaded["constants"]
local old_octave=package.loaded["services.octave_service"]
package.loaded["constants"]={SMUFL={},COLORS={}}
package.loaded["services.octave_service"]={}
local ok,eng=pcall(dofile,"vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua")
package.loaded["constants"]=old_constants
package.loaded["services.octave_service"]=old_octave
assert(ok,"Could not load original Engraver: "..tostring(eng))
assert(type(eng.generate_voice_rests)=="function")

local function note(s,e,p,channel)
 return {start_qn=s,end_qn=e,dur_qn=e-s,pitch=p or 72,chan=channel or 0}
end

local function rest_stats(notes,quantize)
 local original={}
 for i,n in ipairs(notes) do
  original[i]={start_qn=n.start_qn,end_qn=n.end_qn,dur_qn=n.dur_qn,chan=n.chan,pitch=n.pitch}
 end
 local rests=eng.generate_voice_rests(notes,1,4,quantize,0,0,nil)
 assert(type(rests)=="table","Rest engine must return a table")
 local amount,full=0,0
 for _,r in ipairs(rests) do
  assert(type(r.start_qn)=="number","Missing rest start")
  assert(type(r.dur_qn)=="number" and r.dur_qn>0,"Non-positive rest")
  assert(r.start_qn>=-0.0001 and r.start_qn+r.dur_qn<=4.0001,
    "Rest must stay inside the measure")
  amount=amount+r.dur_qn
  if r.is_full_measure then full=full+1 end
 end
 assert(#rests<100,"Rest generation runaway")
 for i,n in ipairs(notes) do
  assert(n.start_qn==original[i].start_qn and n.end_qn==original[i].end_qn
    and n.pitch==original[i].pitch and n.chan==original[i].chan,
    "Rest calculation changed original MIDI event")
 end
 return #rests,amount,full
end

-- Filled monophonic measure should never gain pauses.
local full={note(0,1,72),note(1,2,74),note(2,3,76),note(3,4,77)}
local full_n=rest_stats(full,nil)
assert(full_n==0,"A fully played measure must not contain rests")

-- Empty measure should produce a rest; note length must remain intact.
local empty_n,empty_len=rest_stats({},nil)
assert(empty_n>=1 and empty_len>0,"Empty measure must contain a rest")

-- Genuine one-beat gap after three quarter notes.
local part_n,part_len=rest_stats({note(0,1),note(1,2),note(2,3)},nil)
assert(part_n>=1 and part_len>0,"Trailing one-beat gap must not disappear")

-- Two-voice sequences and overlaps must be handled without replacing original MIDI.
local sequential={note(0,2,60,0),note(2,4,67,1)}
local poly={note(0,4,60,0),note(1,3,72,1)}
local seq_n,seq_len=rest_stats(sequential,0.25)
local poly_n,poly_len=rest_stats(poly,0.25)
assert(seq_n>=0 and seq_len>=0 and poly_n>=0 and poly_len>=0)

-- Humanized performance: compare two grids without asserting a preferred notated result.
local human={
 note(0.000,0.240,81),
 note(0.375,0.615,79),
 note(0.750,0.990,77),
 note(1.125,1.365,76)
}
local n16,len16=rest_stats(human,0.25)
local n32,len32=rest_stats(human,0.125)
print(string.format("OK: Engraver rest invariants; humanized example rests: 1/16=%d (%.3f QN), 1/32=%d (%.3f QN)",n16,len16,n32,len32))
