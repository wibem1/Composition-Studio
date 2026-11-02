-- Offline integration mock for the real one-shot ReaScript.
-- Run from repository root: lua5.4 tests/test_reaper_notation_four_bars.lua
local source="REAPER Notation - 4 Takte und Instrumentenschluessel.lua"
local originals={
  vi="<TRACK\nNAME \"Violine - G-Schluessel\"\nSCORE 0 1 0 0\n>\n",
  va="<TRACK\nNAME \"Bratsche - Alt-C-Schluessel\"\nSCORE 0 1 0 0\n>\n",
  vc="<TRACK\nNAME \"Violoncello - F-Schluessel\"\nSCORE 0 1 0 0\n>\n",
}
local state={
  chunks={vi=originals.vi,va=originals.va,vc=originals.vc},
  names={vi="Violine - G-Schluessel",va="Bratsche - Alt-C-Schluessel",vc="Violoncello - F-Schluessel"},
  actions=0,spacing_calls=0,spacing=0,spacing_present=true,spacing_responds=true,writes=0,undos=0,refreshes=0,console={},editCursor=0,
  time={7,9},loop={10,12},
}
local reaper={}
_G.reaper=reaper
function reaper.MIDIEditor_GetActive() return 100 end
function reaper.MIDIEditor_EnumTakes(_,i,editable)
 assert(editable==false,"Only visible (including non-editable) takes may be enumerated")
 return ({"vi","va","vc"})[i+1]
end
function reaper.MIDIEditor_GetTake() return "vi" end
function reaper.TakeIsMIDI(take) return state.chunks[take]~=nil end
function reaper.ValidatePtr2() return true end
function reaper.GetMediaItemTake_Item(take) return take end
function reaper.GetMediaItem_Track(item) return item end
function reaper.GetTrackName(track) return true,state.names[track] end
function reaper.GetTrackStateChunk(track) return true,state.chunks[track] end
function reaper.SetTrackStateChunk(track,chunk)
 state.writes=state.writes+1;state.chunks[track]=chunk;return true
end
function reaper.Undo_BeginBlock2() end
function reaper.Undo_EndBlock2() state.undos=state.undos+1 end
function reaper.UpdateArrange() end
function reaper.MIDI_RefreshEditors() state.refreshes=state.refreshes+1 end
function reaper.GetCursorPosition() return state.editCursor end
function reaper.TimeMap2_timeToQN(_,time) return time end
function reaper.TimeMap_QNToMeasures(_,qn)
 local m=math.floor(qn/4)
 return m,m*4,(m+1)*4
end
function reaper.TimeMap2_QNToTime(_,qn) return qn end
function reaper.GetSet_LoopTimeRange2(_,isSet,isLoop,startTime,endTime)
 local s=isLoop and state.loop or state.time
 if isSet then s[1],s[2]=startTime,endTime end
 return s[1],s[2]
end
function reaper.SectionFromUniqueID(id) assert(id==32060);return id end
function reaper.kbd_enumerateActions(_,idx)
 if idx==0 then return 410,"View: Zoom to project loop selection" end
 if idx==1 and state.spacing_present then
  return 411,"Notation: Proportional (musical) note spacing"
 end
 return 0,""
end
function reaper.GetToggleCommandStateEx(section,id)
 assert(section==32060 and id==411,"unexpected toggle-state query")
 return state.spacing
end
function reaper.MIDIEditor_OnCommand(editor,id)
 assert(editor==100,"wrong MIDI editor")
 if id==410 then
  state.actions=state.actions+1
  assert(state.loop[1]==0 and state.loop[2]==16,"four measures must span QN 0..16")
 elseif id==411 then
  state.spacing_calls=state.spacing_calls+1
  if state.spacing_responds then state.spacing=1-state.spacing end
 else
  error("unexpected REAPER action, possibly quantization")
 end
 return true
end
function reaper.ShowConsoleMsg(s) state.console[#state.console+1]=s end
function reaper.MIDI_SetNote() error("MIDI should never change") end
function reaper.MIDI_SetAllEvts() error("MIDI should never change") end
function reaper.MIDI_InsertTextSysexEvt() error("MIDI should never change") end
function reaper.ImGui_CreateContext() error("no UI allowed") end
function reaper.ShowMessageBox() error("no prompts allowed") end

local function check(cond,message) assert(cond,message);print("PASS "..message) end
local function run() local chunk,err=loadfile(source);assert(chunk,err);chunk() end

run()
check(state.chunks.vi:find("SCORE 0 2 0 0",1,true)~=nil,"violin mapped to corrected SCORE 0 2 0 0")
check(state.chunks.va:find("SCORE 0 4 0 0",1,true)~=nil,"viola mapped to alto code 4")
check(state.chunks.vc:find("SCORE 0 3 0 0",1,true)~=nil,"cello mapped to bass code 3")
check(state.actions==1,"one zoom action is sent")
check(state.spacing_calls==1 and state.spacing==1,"proportional spacing enabled when off")
check(state.time[1]==7 and state.time[2]==9 and state.loop[1]==10 and state.loop[2]==12,"time and loop selections restored")
check(state.writes==3 and state.undos==1,"all visible tracks updated in one undo block")
check(state.refreshes==3,"notation refreshed for all visible takes")
run()
check(state.writes==3 and state.actions==2,"repeated shortcut is idempotent for SCORE lines")
check(state.spacing_calls==1 and state.spacing==1,"repeated shortcut does not turn proportional spacing off")
state.names.vc="Unbekannt"
state.chunks.vc=originals.vc
run()
check(state.chunks.vc==originals.vc,"unknown instrument remains untouched")
check(state.time[1]==7 and state.loop[1]==10,"existing selections not overwritten on repeated runs")
state.spacing=-1
run()
check(state.spacing_calls==1 and state.spacing==-1,"unknown toggle state is left unchanged")
check(state.actions==4,"four-bar zoom still runs when toggle state is unknown")
state.spacing=0
state.spacing_responds=false
run()
check(state.spacing_calls==2 and state.spacing==0,"failed activation is reported without guessing")
state.spacing_present=false
run()
check(state.spacing_calls==2 and state.actions==6,"missing spacing action does not block four-bar zoom")
print("OK: 15 offline integration checks, not a real REAPER notation-renderer validation.")
