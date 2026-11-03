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
  itemLength=32,vertical_present=true,content_present=true,vertical=50,
  verticalResets=0,verticalIns=0,commands={},
  selected={},visibleTakes={"a","b","c"},multiOpenCalls=0,projectModeCalls=0,selectedModeCalls=0,
  time={7,9},loop={10,12},
}
local reaper={}
_G.reaper=reaper
function reaper.MIDIEditor_GetActive() if state.noEditor then return nil end;return 100 end
function reaper.MIDIEditor_EnumTakes(_,i,editable)
 assert(editable==false)
 return state.visibleTakes[i+1]
end
function reaper.MIDIEditor_GetTake() return state.visibleTakes[1] end
function reaper.CountSelectedMediaItems() return #state.selected end
function reaper.GetSelectedMediaItem(_,i) return state.selected[i+1] end
function reaper.GetActiveTake(item) return item end
function reaper.Main_OnCommand(cmd,flag)
 assert(cmd==40153 and flag==0,"must open selected items in built-in editor")
 state.noEditor=false
 state.multiOpenCalls=state.multiOpenCalls+1
 state.visibleTakes={table.unpack(state.selected)}
end
function reaper.TakeIsMIDI(take) return state.notes[take]~=nil end
function reaper.ValidatePtr2() return true end
function reaper.GetMediaItemTake_Item(take) return take end
function reaper.GetMediaItem_Track(item) return item end
function reaper.GetMediaItemInfo_Value(item,key)
 assert(state.notes[item]~=nil)
 if key=="D_POSITION" then return 0 end
 if key=="D_LENGTH" then return state.itemLength end
 error("unrecognized item property "..tostring(key))
end
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
 local actions={{40726,state.german and "Ansicht: Auf Projekt-Loop zoomen" or "View: Zoom to project loop selection"},{40954,"Mode: Notation"}}
 if state.spacing_present then
  actions[#actions+1]={41131,"Notation: Proportional (musical) note spacing"}
 end
 if state.content_present then
  actions[#actions+1]={40466,state.german and "Ansicht: Auf Inhalt zoomen" or "View: Zoom to content"}
 end
 if state.vertical_present then
  actions[#actions+1]={40111,state.german and "Ansicht: Vertikal einzoomen" or "View: Zoom in vertically"}
 end
 if not actions[idx+1] then return 0,"" end
 return table.unpack(actions[idx+1])
end
function reaper.GetToggleCommandStateEx(section,id)
 assert(section==32060 and id==41131)
 if state.needNotationState then return -1 end
 return state.spacing
end
function reaper.MIDIEditor_OnCommand(editor,id)
 assert(editor==100)
 state.commands[#state.commands+1]=id
 if id==40954 then
  state.notationCalls=(state.notationCalls or 0)+1
  state.needNotationState=false
 elseif id==40726 then
  state.actions=state.actions+1
  assert(state.loop[1]==0 and state.loop[2]==16,"must zoom four bars")
 elseif id==41131 then
  state.spacing_calls=state.spacing_calls+1
  if state.spacing_responds then state.spacing=1-state.spacing end
 elseif id==40466 then
  state.verticalResets=state.verticalResets+1
  state.vertical=0
 elseif id==40111 then
  state.verticalIns=state.verticalIns+1
  state.vertical=state.vertical+1
 elseif id==40896 then
  state.projectModeCalls=state.projectModeCalls+1
 elseif id==40898 then
  state.selectedModeCalls=state.selectedModeCalls+1
 else error("unexpected action; quantization must never run") end
 return true
end
function reaper.ShowConsoleMsg(_) error("one-shot shortcut must never open REAPER console") end
function reaper.MIDI_SetNote() error("MIDI event changed!") end
function reaper.MIDI_SetAllEvts() error("MIDI event changed!") end
function reaper.MIDI_InsertTextSysexEvt() error("MIDI metadata changed!") end
function reaper.ImGui_CreateContext() error("No UI needed") end
function reaper.ShowMessageBox(message) state.failure=message end

local checks=0
local function check(cond,label)
 assert(cond,label)
 checks=checks+1
 print("PASS "..label)
end
local function run()
 local script,err=loadfile(source)
 assert(script,err)
 state.failure=nil
 script()
 if not state.expectFailure then assert(not state.failure,state.failure) end
end
local function has(track,clef)
 return state.chunks[track]:find("SCORE 0 "..clef.." 0 0",1,true)~=nil
end
run()
check(has("a",1),"high-note track with misleading 'Cello' name gets treble")
check(has("b",3),"middle-register untitled track gets alto")
check(has("c",2),"low-note track named 'Violine' gets bass")
check(state.actions==1,"one native zoom to four bars")
check(state.vertical==4 and state.verticalResets==1 and state.verticalIns==4,
 "eight bars over three tracks gets four vertical zoom steps from reset baseline")
check(state.commands[#state.commands]==40726,"horizontal four-bar zoom always runs AFTER vertical reset")
check(#state.console==0,"ordinary shortcut execution has no console messages")

check(state.spacing_calls==1 and state.spacing==1,"proportional spacing enabled once")
check(state.time[1]==7 and state.time[2]==9 and state.loop[1]==10 and state.loop[2]==12,"loop and time selections restored")
check(state.writes==2 and state.undos==1,"only two tracks changed; single undo block")
check(state.refreshes==3,"notation refresh attempted on visible takes")

run()
check(state.writes==2 and state.actions==2,"repeating shortcut keeps clefs without rewrites")
check(state.spacing_calls==1 and state.spacing==1,"repeating shortcut does not toggle spacing off")
check(state.vertical==4 and state.verticalResets==2,"repeated shortcut restores same vertical zoom, no cumulative growth")

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

-- The older Notation Studio inserted missing SCORE after a VU line.
state.notes.c=fixture({44,47,48,49,50,52})
state.chunks.c="<TRACK\nNAME \"Untitled\"\nVU 2\n>\n"
state.spacing=1
state.spacing_present=true
run()
check(has("c",2),"missing SCORE line receives bass with original v0.1.24 insertion method")
check(state.chunks.c:find("VU 2\nSCORE 0 2 0 0",1,true)~=nil,
      "new SCORE line inserted directly after VU, like Notation Studio v0.1.24")

-- Longer composition: choose smaller vertical scale. Always reset first.
state.itemLength=128 -- 32 measures -> 8 four-bar systems
run()
check(state.vertical==2,"longer piece uses a more conservative vertical scale")
check(state.commands[#state.commands]==40726,"longer piece still ends on four-bar horizontal zoom")
-- No reset action: do not blindly enlarge vertically.
state.content_present=false
local resetsBefore,insBefore=state.verticalResets,state.verticalIns
run()
check(state.verticalResets==resetsBefore and state.verticalIns==insBefore,
 "missing native reset leaves vertical scale unchanged")
check(state.commands[#state.commands]==40726,"missing vertical reset never blocks horizontal zoom")
-- Missing zoom-in action: similarly skip instead of distorting view.
state.content_present=true
state.vertical_present=false
resetsBefore,insBefore=state.verticalResets,state.verticalIns
run()
check(state.verticalResets==resetsBefore and state.verticalIns==insBefore,
 "missing vertical zoom-in action does not reset the editor")
-- Selected items not yet present in the MIDI editor must be opened together.
state.visibleTakes={"a"}
state.selected={"a","b","c"}
local selections=table.concat(state.selected,",")
run()
check(table.concat(state.visibleTakes,",")=="a,b,c","missing selected MIDI items are opened in a common editor")
check(state.multiOpenCalls==1 and state.projectModeCalls==1 and state.selectedModeCalls==1,
 "native per-project editor mode and open-all-selected behavior used")
check(table.concat(state.selected,",")==selections,"arrangement item selection remains unchanged")
check(state.commands[#state.commands]==40726,"four-bar zoom follows opening selected items")
local opens=state.multiOpenCalls
run()
check(state.multiOpenCalls==opens,"when all selected items are visible, do not reopen editor")
-- No MIDI selection: keep existing visible takes and never reopen the editor.
state.selected={}
state.visibleTakes={"a","b"}
run()
check(state.multiOpenCalls==opens and #state.visibleTakes==2,"no selected items leaves current multi-item editor intact")

print("OK: "..checks.." real-script mock checks; REAPER GUI multi-item display and vertical reset remain unverified")


state.german=true;state.vertical_present=true;state.content_present=true;state.spacing=0;state.needNotationState=true
local zoomBefore=state.actions;local verticalBefore=state.verticalIns
run()
check(state.actions==zoomBefore+1 and state.verticalIns>verticalBefore,"German action names work via verified native IDs")
check(state.spacing==1 and state.notationCalls>0,"notation mode is activated before requesting toggle status")
state.noEditor=true;state.selected={"a","b"}
local opensBefore=state.multiOpenCalls
run()
check(not state.noEditor and state.multiOpenCalls==opensBefore+1,"Main-section start without focused editor opens explicitly selected MIDI items")
state.noEditor=true;state.selected={};state.expectFailure=true
local commandsBefore=#state.commands;local writesBefore=state.writes
run()
check(state.failure and state.failure:find("Kein fokussierter MIDI-Editor",1,true),"missing editor and selection produces one actionable error")
check(#state.commands==commandsBefore and state.writes==writesBefore,"failed prerequisite never changes view or clefs")
print("OK: "..checks.." production-script checks, including user's German/focus failure; real GUI retest pending")
