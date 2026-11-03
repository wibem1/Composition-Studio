-- Real production-function regression tests with an isolated REAPER mock.
-- No API keys, MIDI files, user projects or GUI required.
local f=assert(io.open("Composition Studio.lua","rb"))
local src=f:read("*a");f:close()

local function extract(startMarker,endMarker,newName)
 local begin=assert(src:find(startMarker,1,true),"function start missing: "..startMarker)
 local ending=assert(src:find(endMarker,begin+1,true),"function end missing: "..endMarker)
 local code=src:sub(begin,ending-1)
 code=code:gsub("^local function ","function ",1)
 local env={}
 setmetatable(env,{__index=_G})
 return code,env
end
local a,env=extract("local function notation_selection_items","local function selected_items")
local notes={
 a={{sel=true,p=60,s=0,e=480},{sel=false,p=61,s=480,e=960},{sel=true,p=64,s=960,e=1440}},
 b={{sel=true,p=48,s=0,e=480},{sel=true,p=49,s=480,e=960},{sel=true,mut=true,p=50,s=960,e=1440}},
}
local targets={a="itemA",b="itemB"}
local tracks={itemA="trackA",itemB="trackB"}
local mock={}
function mock.MIDIEditor_GetActive() return 99 end
function mock.MIDIEditor_EnumTakes(_,i,editable)
 assert(editable==true,"must enumerate ONLY editable takes")
 return ({"a","b"})[i+1]
end
function mock.TakeIsMIDI(t) return notes[t]~=nil end
function mock.ValidatePtr2() return true end
function mock.GetMediaItemTake_Item(t) return targets[t] end
function mock.GetMediaItem_Track(item) return tracks[item] end
function mock.MIDI_CountEvts(t) return true,#notes[t] end
function mock.MIDI_GetNote(t,i)
 local n=notes[t][i+1]
 if not n then return false end
 return true,n.sel,n.mut or false,n.s,n.e,0,n.p,90
end
function mock.MIDI_GetProjTimeFromPPQPos(_,p) return p/480 end
function mock.TimeMap2_timeToQN(_,t) return t end
function mock.GetTrackName(t) return true,t end
function mock.GetSetMediaItemTakeInfo_String() return true,"test item" end
function mock.GetMediaItemInfo_Value(_,key) return key=="D_POSITION" and 0 or 16 end
env.reaper=mock
env.item_guid=function(item) return item end
env.track_guid=function(track) return track end
assert(load(a,"notation_selection_items","t",env))()
local rows,n=env.notation_selection_items(true)
assert(#rows==2 and n==4,"four nonmuted selected notes across two editable tracks")
assert(#rows[1].notes==2 and #rows[2].notes==2,"selected notes only, no unselected included")
assert(rows[1].notes[1].pitch==60 and rows[1].notes[2].pitch==64,"selected pitch order")
assert(rows[1].selection_source[1].index==0 and rows[1].selection_source[2].index==2,"stable note identities")
local readonly,rc=env.notation_selection_items(false)
assert(rc==4 and #readonly[1].notes==0,"count-only API does not collect all notes")
mock.MIDIEditor_GetActive=function() return nil end
assert(select(2,env.notation_selection_items(true))==0,"no active editor is harmless")

local b,nenv=extract("local function apply_notation_transpose","function workflow_adapter.apply")
local writes,undos,sorts=0,0,0
nenv.reaper={
 TakeIsMIDI=mock.TakeIsMIDI,
 MIDI_CountEvts=mock.MIDI_CountEvts,
 MIDI_GetNote=mock.MIDI_GetNote,
 MIDI_SetNote=function(t,i,selected,muted,s,e,ch,p,v)
  local n=notes[t][i+1];writes=writes+1
  assert(n.sel==selected and n.s==s and n.e==e and ch==0 and v==90)
  n.p=p
  return true
 end,
 MIDI_Sort=function() sorts=sorts+1 end,
 Undo_BeginBlock2=function() undos=undos+1 end,
 Undo_EndBlock2=function() end,
 Undo_DoUndo2=function() error("unexpected rollback") end,
 UpdateArrange=function() end,
}
nenv.workflow_adapter={bindings=function()
 return {{guid="itemA",take="a"},{guid="itemB",take="b"}}
end}
assert(load(b,"apply_notation_transpose","t",nenv))()
local saved={
 {guid="itemA",notes={{index=0,start_ppq=0,end_ppq=480,channel=0,pitch=60,velocity=90},
                     {index=2,start_ppq=960,end_ppq=1440,channel=0,pitch=64,velocity=90}}},
 {guid="itemB",notes={{index=0,start_ppq=0,end_ppq=480,channel=0,pitch=48,velocity=90},
                     {index=1,start_ppq=480,end_ppq=960,channel=0,pitch=49,velocity=90}}},
}
local record={payload="TRANSPOSE_NOTATION|2",notation_selection=saved}
assert(nenv.apply_notation_transpose(record)==true,"approved selected-note operation")
assert(notes.a[1].p==62 and notes.a[2].p==61 and notes.a[3].p==66,"unselected note unaffected")
assert(notes.b[1].p==50 and notes.b[2].p==51 and notes.b[3].p==50,"other track selected and muted protected")
assert(writes==4 and undos==1 and sorts==2,"one Undo block and one MIDI sort per take")
local before=writes
local ok,reason=nenv.apply_notation_transpose(record)
assert(not ok and reason:find("verändert"),"stale selection fails closed")
assert(writes==before,"stale selection cannot modify any note")
local invalid={payload="TRANSPOSE_NOTATION|24",notation_selection={{guid="itemA",notes={{index=1,start_ppq=480,end_ppq=960,channel=0,pitch=61,velocity=90}}}}}
assert(nenv.apply_notation_transpose(invalid)==true,"valid range transposition")
local out={payload="TRANSPOSE_NOTATION|24",notation_selection={{guid="itemA",notes={{index=1,start_ppq=480,end_ppq=960,channel=0,pitch=85,velocity=90}}}}}
before=writes
assert(nenv.apply_notation_transpose(out)==true,"max MIDI pitch case still in range")
assert(writes==before+1)
local bad={payload="TRANSPOSE_NOTATION|24",notation_selection={{guid="itemA",notes={{index=1,start_ppq=480,end_ppq=960,channel=0,pitch=109,velocity=90}}}}}
before=writes
local result=nenv.apply_notation_transpose(bad)
assert(not result and writes==before,"invalid pitch prevalidated before Undo")

assert(src:find('r.stage=="composition" and #(r.notation_selection or {})>0',1,true),"variant guard exists")
assert(src:find('workflow_guard=hasSelection and workflow_adapter.guard() or nil',1,true),"guard captured at request time")
assert(src:find("Sofortaktionen auf ganze MIDI-Items",1,true),"no immediate whole item action from note selection")
print("OK: selected-notation source functions tested, multi-take read, targeted Undo edit, stale guard, note isolation")
