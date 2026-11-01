-- Regression for Windows REAPER 7.83 "Taktkarte ungueltig bei Takt 1".
-- SPDX-License-Identifier: GPL-3.0-only
-- Run from repo root: lua5.4 tests/test_notator_gpl_rest_adapter.lua
-- No REAPER installation or project writes required.
local function run_case(case)
 local output,dialogs={},{}
 local measures=case.measures
 local function measure_of(qn)
  for i,m in ipairs(measures) do
   if qn>=m[1] and qn<m[2] then return i-1 end
  end
  return #measures-1
 end
 local take={}
 local item={}
 local mock={
  MIDIEditor_GetActive=function() return {} end,
  MIDIEditor_GetTake=function() return take end,
  TakeIsMIDI=function(t) return t==take end,
  GetMediaItemTake_Item=function() return item end,
  GetMediaItemInfo_Value=function(_,key)
   assert(key=="D_POSITION")
   return case.item_position
  end,
  TimeMap2_timeToQN=function(_,time) return time end,
  -- Intentionally return ONLY the index. The old script failed if the
  -- optional QN boundaries were unavailable or mismatched.
  TimeMap_QNToMeasures=function(_,qn) return measure_of(qn) end,
  TimeMap_GetMeasureInfo=function(_,index)
   local m=assert(measures[index+1],"Missing measure "..tostring(index))
   return m[1]*0.5,m[1],m[2],m[3],m[4],120
  end,
  MIDI_CountEvts=function() return true,#case.notes,0,0 end,
  MIDI_GetNote=function(_,idx)
   local n=case.notes[idx+1]
   assert(n)
   return true,false,false,n[1]*960,n[2]*960,n[3] or 0,n[4] or 72,90
  end,
  MIDI_GetProjQNFromPPQPos=function(_,ppq) return ppq/960 end,
  MIDI_GetHash=function() return true,"unchanged-mock-hash" end,
  GetAppVersion=function() return "7.83/Win64" end,
  ShowMessageBox=function(s) dialogs[#dialogs+1]=s end,
  ShowConsoleMsg=function(s) output[#output+1]=s end
 }
 local orig_reaper=reaper
 reaper=mock
 local ok,err=pcall(dofile,"tools/notator_gpl_rest_comparison.lua")
 reaper=orig_reaper
 assert(ok,"Case "..case.name.." exception: "..tostring(err))
 local msg=table.concat(output)
 assert(#dialogs==1,case.name..": expected one status dialog")
 assert(not dialogs[1]:find("Taktgrenzen konnten"),case.name..": mapping failed")
 assert(not dialogs[1]:find("Taktkarte"),case.name..": old failure returned")
 assert(msg:find("MIDI%-Hash unveraendert: true"),case.name..": no MIDI hash assertion")
 assert(msg:find("Anzeige 1/16",1,true),case.name..": missing 1/16 results")
 assert(msg:find("Anzeige 1/32",1,true),case.name..": missing 1/32 results")
 assert(msg:find("Pausen=",1,true),case.name..": rest engine did not run")
 assert(msg:find("FEHLER:",1,true)==nil,case.name..": rest engine error: "..msg)
 assert(msg:find(case.expected_bars,1,true),case.name..": measure span incorrect: "..msg)
 return msg
end

run_case({
 name="4/4 starting at QN 0 with optional outputs omitted",
 measures={{0,4,4,4},{4,8,4,4},{8,12,4,4},{12,16,4,4}},
 item_position=0,
 notes={{0,0.24,0,81},{0.375,0.615,0,79},{4.125,4.365,0,76},{9.0,9.24,0,72}},
 expected_bars="Bereich: Takte 1 bis 4"
})
run_case({
 name="MIDI item in measure 2 with a meter change",
 measures={{0,4,4,4},{4,7,3,4},{7,9.5,5,8},{9.5,12.5,3,4},{12.5,16.5,4,4}},
 item_position=4,
 notes={{4.0,4.24,0,81},{4.5,5.2,0,79},{7.125,7.365,0,77},{9.5,11.0,0,72},{12.75,13.3,0,60}},
 expected_bars="Bereich: Takte 2 bis 5"
})
print("OK: real GPL rest adapter, measure-index API, optional outputs and meter change")
