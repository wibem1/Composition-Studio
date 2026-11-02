-- Offline regression tests for the actual one-shot REAPER script.
-- Only tests REAPER API calls, not the real renderer's visual acceptance.
local source="REAPER Notation - 4 Takte und Instrumentenschluessel.lua"

local function fixture(pitches)
  local out={}
  for i,p in ipairs(pitches) do
    out[i]={p=p,a=(i-1)*480,b=(i-1)*480+450,muted=false}
  end
  return out
end

local state={
  chunks={
    a="<TRACK\nNAME \"A\"\nSCORE 0 1 0 0\n>\n",
    b="<TRACK\nNAME \"B\"\nSCORE 0 1 0 0\n>\n",
    c="<TRACK\nNAME \"C\"\nSCORE 0 1 0 0\n>\n",
  },
  names={a="Cello",b="Untitled",c="Violine"}, -- Deliberately misleading.
  notes={
    a=fixture({72,74,76,77,79,81,76,74}),
    b=fixture({57,59,60,62,63,65,62,60}),
    c=fixture({43,45,47,48,50,52,50,48}),
  },
  actions=0,spacing_calls=0,spacing=0,spacing_present=true,spacing_responds=true,
  writes=0,undos=0,refreshes=0,console={},editCursor=0,
  time={7,9},loop={10,12},
}
local reaper={}
_G.reaper=reaper
function reaper.MIDIEditor_GetActive() return 100 end
function reaper.MIDIEditor_EnumTakes(_,i,editable)
 assert(editable==false)
 return ({"a","b","c"})[i+1]
end
function reaper.MIDIEditor_GetTake() return "a" end
function reaper.TakeIsMIDI(take) return state.notes[take]~=nil end
function reaper.ValidatePtr2() return true end
function reaper.GetMediaItemTake_Item(take) return take end
function reaper.GetMediaItem_Track(item) return item end
function reaper.GetTrackName() error("TRACK NAMES MUST NOT BE READ FOR CLEF INFERENCE") end
function reaper.MIDI_CountEvts(take)
 return true,#state.notes[take],0,0
end
function reaper.MIDI_GetNote(take,index)
 local n=state.notes[take][index+1]
 if not n then return false end
 return true,false,n.muted,n.a,n.b,0,n.p,88
end
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
 assert(section==32060 and id==411)
 return state.spacing
end
function reaper.MIDIEditor_OnCommand(editor,id)
 assert(editor==100)
 if id==410 then
  state.actions=state.actions+1
  assert(state.loop[1]==0 and state.loop[2]==16,"must zoom four bars")
 elseif id==411 then
  state.spacing_calls=state.spacing_calls+1
  if state.spacing_responds then state.spacing=1-state.spacing end
 else error("unexpected action; quantization must never run") end
 return true
end
function reaper.ShowConsoleMsg(s) state.console[#state.console+1]=s end
function reaper.MIDI_SetNote() error("MIDI event changed!") end
function reaper.MIDI_SetAllEvts() error("MIDI event changed!") end
function reaper.MIDI_InsertTextSysexEvt() error("MIDI metadata changed!") end
function reaper.ImGui_CreateContext() error("No UI needed") end
function reaper.ShowMessageBox() error("No prompts allowed") end

local checks=0
local function check(cond,label)
 assert(cond,label)
 checks=checks+1
 print("PASS "..label)
end
local function run()
 local script,err=loadfile(source)
 assert(script,err)
 script()
end
local function has(track,clef)
 return state.chunks[track]:find("SCORE 0 "..clef.." 0 0",1,true)~=nil
end
run()
check(has("a",1),"high-note track with misleading 'Cello' name gets treble")
check(has("b",3),"middle-register untitled track gets alto")
check(has("c",2),"low-note track named 'Violine' gets bass")
check(state.actions==1,"one native zoom to four bars")
check(state.spacing_calls==1 and state.spacing==1,"proportional spacing enabled once")
check(state.time[1]==7 and state.time[2]==9 and state.loop[1]==10 and state.loop[2]==12,"loop and time selections restored")
check(state.writes==2 and state.undos==1,"only two tracks changed; single undo block")
check(state.refreshes==3,"notation refresh attempted on visible takes")

run()
check(state.writes==2 and state.actions==2,"repeating shortcut keeps clefs without rewrites")
check(state.spacing_calls==1 and state.spacing==1,"repeating shortcut does not toggle spacing off")

-- Insufficient or ambiguous material cannot justify a forced clef switch.
state.notes.c=fixture({72,74,76})
state.chunks.c="<TRACK\nSCORE 0 1 0 0\n>\n"
local writes=state.writes
run()
check(state.writes==writes and has("c",1),"three-note fragment retains existing clef")

state.notes.c=fixture({60,60,60,60,60,60})
state.chunks.c="<TRACK\nSCORE 0 2 0 0\n>\n"
writes=state.writes
run()
check(state.writes==writes and has("c",2),"ambiguous C4 range retains previous clef")

-- A wide MELODY alone is not sufficient evidence for a grand staff.
state.notes.a=fixture({48,50,52,72,74,76,48,50,74,76})
state.chunks.a="<TRACK\nSCORE 0 1 0 0\n>\n"
run()
check(not state.chunks.a:find("SCORE 0 0 0 0",1,true),"wide melody does not create grand staff")

-- Concurrent lower and upper voices imply independent grand staff.
local piano={
 {p=48,a=0,b=900},{p=72,a=0,b=450},
 {p=50,a=1000,b=1900},{p=74,a=1000,b=1450},
 {p=52,a=2000,b=2900},{p=76,a=2000,b=2450},
 {p=48,a=3000,b=3900},{p=72,a=3000,b=3450},
}
state.notes.a=piano
state.chunks.a="<TRACK\nSCORE 0 1 0 0\n>\n"
run()
check(has("a",1),"simultaneous high/low voices retain established staff; grand is not encoded")

state.spacing=-1
local before=state.spacing_calls
run()
check(state.spacing_calls==before and state.spacing==-1,"unknown spacing status does not toggle")
state.spacing_present=false
run()
check(state.spacing_calls==before,"missing proportional-spacing action does not block zoom")
check(state.actions>=8,"zoom continues independently of clef/spacing inference")

state.notes.c=fixture({41,44,47,48,50,52})
state.chunks.c="<TRACK\nSCORE 0 1 0 0 77\n>\n"
writes=state.writes
run()
check(state.writes==writes and state.chunks.c:find("SCORE 0 1 0 0 77",1,true)~=nil,
      "unknown SCORE chunk layout never overwritten")

print("OK: "..checks.." real-script mock checks; REAPER GUI and SCORE field semantics still require an actual test")
