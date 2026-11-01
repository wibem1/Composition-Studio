-- SPDX-License-Identifier: GPL-3.0-only
-- Diagnostic proof of a known limitation in unmodified GPL v2.55 Engraver.
-- It is a characterization test, not proof of correct notation.
local prev_c=package.loaded["constants"]
local prev_o=package.loaded["services.octave_service"]
package.loaded["constants"]={SMUFL={},COLORS={}}
package.loaded["services.octave_service"]={}
local ok,engraver=pcall(dofile,"vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua")
package.loaded["constants"]=prev_c
package.loaded["services.octave_service"]=prev_o
assert(ok,tostring(engraver))
local function note(s,e,pitch)
 return {start_qn=s,end_qn=e,dur_qn=e-s,pitch=pitch,chan=0}
end
-- One 3/4 measure: two overlapping notes 0-1.5 and 0.5-2.0;
-- a third note 2.5-3.0. There is a real 0.5 QN silence 2.0-2.5,
-- even though the SUM of note durations is 3.5 QN > 3.
local notes={
 note(0,1.5,60),
 note(0.5,2.0,64),
 note(2.5,3.0,67),
}
local sum=0
for _,n in ipairs(notes) do sum=sum+n.dur_qn end
assert(math.abs(sum-3.5)<1e-8)
local intervals={}
for _,n in ipairs(notes) do intervals[#intervals+1]={s=n.start_qn,e=n.end_qn} end
table.sort(intervals,function(a,b) return a.s<b.s end)
local gaps,covered,last={},0,0
for _,n in ipairs(intervals) do
 if n.s>last then gaps[#gaps+1]={s=last,e=n.s} end
 if n.e>last then
  covered=covered+math.max(0,n.e-math.max(n.s,last))
  last=n.e
 end
end
if last<3 then gaps[#gaps+1]={s=last,e=3} end
assert(#gaps==1 and math.abs(gaps[1].s-2)<1e-8
  and math.abs(gaps[1].e-2.5)<1e-8,
  "Expected a genuine 0.5 QN time gap")
assert(math.abs(covered-2.5)<1e-8)
local original=engraver.generate_voice_rests(notes,1,3,nil,0,0,nil)
assert(type(original)=="table")
assert(#original==0,
 "Upstream behavior changed; revisit this documented limitation")
print("KNOWN LIMITATION CONFIRMED: source GPL v2.55 reports 0 rests despite genuine 0.5 QN gap in overlapping same-channel notes")
