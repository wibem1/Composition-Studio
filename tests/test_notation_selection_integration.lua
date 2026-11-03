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
mock.MIDIEditor_GetTake=function() return "a" end
local focusSource=assert(src:match("(local last_notation_editor=nil.-)\n%-%- REAPER notation and piano roll"))
focusSource=focusSource:gsub("local function focused_or_last_notation_editor","function focused_or_last_notation_editor",1)
assert(load(focusSource,"focused_or_last_notation_editor","t",env))()
assert(load(a,"notation_selection_items","t",env))()
local rows,n=env.notation_selection_items(true)
assert(#rows==2 and n==4,"four nonmuted selected notes across two editable tracks")
assert(#rows[1].notes==2 and #rows[2].notes==2,"selected notes only, no unselected included")
assert(rows[1].notes[1].pitch==60 and rows[1].notes[2].pitch==64,"selected pitch order")
assert(rows[1].selection_source[1].index==0 and rows[1].selection_source[2].index==2,"stable note identities")
local readonly,rc=env.notation_selection_items(false)
assert(rc==4 and #readonly[1].notes==0,"count-only API does not collect all notes")
-- Verify REAPER's native selected-note enumeration, not a scan of every note.
local scanned=0
local previousGet=mock.MIDI_GetNote
mock.MIDI_GetNote=function(...) scanned=scanned+1;return previousGet(...) end
mock.MIDI_EnumSelNotes=function(t,index)
 for i=index+1,#notes[t]-1 do if notes[t][i+1].sel then return i end end
 return -1
end
local chosen,chosenCount=env.notation_selection_items(true)
assert(chosenCount==4 and #chosen==2,"native selected-note enumeration matches fallback")
assert(scanned==5,"only selected events read; muted selected event is ignored")
mock.MIDI_GetNote=previousGet
mock.MIDIEditor_GetActive=function() return nil end
assert(select(2,env.notation_selection_items(true))==4,
 "note selection remains accessible after keyboard focus moves from notation editor to Studio")
mock.MIDIEditor_GetTake=function() return nil end
assert(select(2,env.notation_selection_items(true))==0,
 "closed or invalidated cached MIDI editor is not reused")

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
assert(src:find("Keine editierbaren Einzelnoten",1,true) or src:find("keine editierbaren Einzelnoten",1,true),"must block selected-note requests with empty note selection")

-- Exercise the actual new AI note-patch function, not a rewritten test copy.
local patchCode,penv=extract("local function apply_notation_patch","-- Approval-only transposition")
local pnotes={
 a={{sel=true,p=60,v=90,s=0,e=480},{sel=false,p=61,v=90,s=480,e=960},{sel=true,p=64,v=90,s=960,e=1440}},
 b={{sel=true,p=48,v=90,s=0,e=480},{sel=true,p=49,v=90,s=480,e=960},{sel=true,mut=true,p=50,v=90,s=960,e=1440}},
}
local patchWrites,patchUndos,patchSorts=0,0,0
penv.reaper={
 TakeIsMIDI=function(t) return pnotes[t]~=nil end,
 MIDI_CountEvts=function(t) return true,#pnotes[t] end,
 MIDI_GetNote=function(t,i)
  local n=pnotes[t][i+1]
  if not n then return false end
  return true,n.sel,n.mut or false,n.s,n.e,0,n.p,n.v
 end,
 MIDI_SetNote=function(t,i,selected,muted,s,e,ch,p,v)
  local n=pnotes[t][i+1]
  assert(n.sel==selected and n.s==s and n.e==e and ch==0 and not muted)
  n.p=p;n.v=v;patchWrites=patchWrites+1;return true
 end,
 MIDI_Sort=function() patchSorts=patchSorts+1 end,
 Undo_BeginBlock2=function() patchUndos=patchUndos+1 end,
 Undo_EndBlock2=function() end,
 Undo_DoUndo2=function() error("rollback only on exceptional failure") end,
 UpdateArrange=function() end,
 MIDI_SetAllEvts=function() error("must never replace entire MIDI stream") end,
 MIDI_DeleteNote=function() error("must never delete notes") end,
 MIDI_InsertNote=function() error("must never insert notes") end,
 MIDI_SetCC=function() error("must never edit CC") end,
}
penv.workflow_adapter={bindings=function() return {{guid="itemA",take="a"},{guid="itemB",take="b"}} end}
assert(load(patchCode,"apply_notation_patch","t",penv))()
local originalPatchRefs={
 {guid="itemA",notes={
  {index=0,start_ppq=0,end_ppq=480,channel=0,pitch=60,velocity=90},
  {index=2,start_ppq=960,end_ppq=1440,channel=0,pitch=64,velocity=90}}},
 {guid="itemB",notes={
  {index=0,start_ppq=0,end_ppq=480,channel=0,pitch=48,velocity=90},
  {index=1,start_ppq=480,end_ppq=960,channel=0,pitch=49,velocity=90}}},
}
local payload="CSNOTE|itemA|0|63|82\nCSNOTE|itemA|2|67|91\nCSNOTE|itemB|0|50|86\nCSNOTE|itemB|1|51|96"
local patchRecord={payload=payload,notation_selection=originalPatchRefs}
local function rejected(payloadText,ref,reason)
 local before=patchWrites
 local ok,err=penv.apply_notation_patch({payload=payloadText,notation_selection=ref or originalPatchRefs})
 assert(not ok and type(err)=="string",reason or "malformed patch should be rejected")
 assert(patchWrites==before,"rejection must not partially modify any note")
end
rejected("CSNOTE|itemA|0|63|82",nil, "incomplete patch rejected")
rejected(payload.."\nCSNOTE|itemA|0|63|82",nil,"duplicate rejected")
rejected(payload.."\nCSNOTE|unknown|1|63|82",nil,"foreign note rejected")
rejected(payload:gsub("CSNOTE|itemB|0|50|86","CSNOTE|itemB|0|128|86"),nil,"pitch bounds rejected")
rejected(payload:gsub("CSNOTE|itemB|0|50|86","CSNOTE|itemB|0|50|0"),nil,"velocity bounds rejected")
rejected(payload:gsub("CSNOTE|itemB|0|50|86","hello"),nil,"extra text rejected")
-- Existing same-channel note collision: a changed note must not be made to
-- overlap another MIDI note of equal pitch on that same take.
pnotes.a[2].s=200;pnotes.a[2].e=700
rejected(payload:gsub("CSNOTE|itemA|0|63|82","CSNOTE|itemA|0|61|82"),nil,"collision rejected")
pnotes.a[2].s=480;pnotes.a[2].e=960
assert(penv.apply_notation_patch(patchRecord)==true,"valid two-take note patch must apply")
assert(patchWrites==4 and patchUndos==1 and patchSorts==2,"one Undo group and sort each modified take")
assert(pnotes.a[1].p==63 and pnotes.a[1].v==82 and pnotes.a[2].p==61 and pnotes.a[2].v==90 and pnotes.a[3].p==67,
 "marked notes changed, unmarked note untouched")
assert(pnotes.b[1].p==50 and pnotes.b[2].p==51 and pnotes.b[3].p==50,
 "other take selected notes changed, muted note untouched")
rejected(payload,nil,"stale source note check blocks second application")
assert(src:find('stage=="notation_patch" or stage=="engine_json"',1,true),
 "AI patch responses enter the existing workflow proposal handler")
assert(src:find('launch("notation_patch",context,key,',1,true),
 "explicit note improvement enters dedicated AI protocol")
assert(src:find("Die direkte Überarbeitung markierter Noten unterstützt bisher",1,true),
 "unsupported rhythmic requests explicitly rejected")
assert(src:find('r.stage=="notation_patch"',1,true),
 "explicit approval path handles AI notation patch")
print("OK: AI note patch production-function mock checks, strict count/IDs, stale source, collisions, untouched notes and CC")

print("OK: selected-notation source functions tested, multi-take read, targeted Undo edit, stale guard, note isolation")
