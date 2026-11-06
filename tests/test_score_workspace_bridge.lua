-- Tests for actual Composition Studio score-workspace production functions.
local f=assert(io.open("Composition Studio.lua","rb"));local source=f:read("*a");f:close()
local function compile(start,finish,env)
 local a=assert(source:find(start,1,true),start.." missing")
 local b=assert(source:find(finish,a+1,true),finish.." missing")
 local body=source:sub(a,b-1):gsub("^local function ","function ",1)
 setmetatable(env,{__index=_G})
 local chunk,err=load(body,"production:"..start,"t",env)
 assert(chunk,err);chunk()
end
local takes={tk1="it1",tk2="it2"}
local tr={it1="tr1",it2="tr2"}
local notes={
 tk1={{s=0,e=480,p=60,mut=false},{s=480,e=960,p=62,mut=false}},
 tk2={{s=0,e=480,p=48,mut=false},{s=480,e=960,p=50,mut=true}},
}
local active=101
local noteReads=0
local api={
 MIDIEditor_GetActive=function() return active end,
 MIDIEditor_GetTake=function() return "tk1" end,
 MIDIEditor_EnumTakes=function(ed,i,editable)
  assert(ed==101,"correct editor")
  assert(editable==false,"visible score must enumerate all visible, not only editable, takes")
  return ({"tk1","tk2"})[i+1]
 end,
 ValidatePtr2=function() return true end,
 TakeIsMIDI=function(tk) return notes[tk]~=nil end,
 GetMediaItemTake_Item=function(tk) return takes[tk] end,
 GetMediaItem_Track=function(it) return tr[it] end,
 GetTrackName=function(t) return true,t end,
 GetSetMediaItemTakeInfo_String=function() return true,"Score" end,
 GetMediaItemInfo_Value=function(_,key) return key=="D_POSITION" and 0 or 8 end,
 TimeMap2_timeToQN=function(_,t) return t end,
 MIDI_CountEvts=function(tk) return true,#notes[tk] end,
 MIDI_GetNote=function(tk,i)
  noteReads=noteReads+1
  local n=notes[tk][i+1];if not n then return false end
  return true,false,n.mut,n.s,n.e,0,n.p,90
 end,
 MIDI_GetProjTimeFromPPQPos=function(_,ppq) return ppq/480 end,
 GetMediaTrackInfo_Value=function() return 1 end,
 MIDI_SetNote=function() error("score context must be read-only") end,
 SetMediaItemSelected=function() error("score context must preserve selection") end,
}
local env={reaper=api,focused_or_last_notation_editor=function() return active end,
 item_guid=function(it) return it end,track_guid=function(track) return track end}
compile("local function notation_visible_items","local function selected_items",env)
local items,why=env.notation_visible_items(true)
assert(why==nil and #items==2,"all visible items across different tracks")
assert(#items[1].notes==2 and #items[2].notes==1,"read whole visible score but skip muted notes")
assert(items[1].score_context and items[2].score_context,"score context must be marked read-only")
assert(items[1].notes[1].pitch==60 and items[2].notes[1].pitch==48,"actual score data")
local rows=env.notation_visible_items(false)
assert(#rows==2 and #rows[1].notes==0,"without notes only scope metadata is collected")
compile("local function editor_reference_excerpt","local function score_request_intent",env)
local selection={{notes={{start_qn=0,duration_qn=2,pitch=60}}}}
local reference=env.editor_reference_excerpt(selection)
assert(reference:find("REFERENZSTIMMEN NUR ZUR HARMONISCHEN",1,true),"read-only context disclaimer")
assert(reference:find("REFERENZSPUR tr1",1,true) and reference:find("REFERENZSPUR tr2",1,true),
 "reference includes both visible MIDI tracks, including harmony from noneditable context")
assert(reference:find("REF ",1,true),"reference contains actual note data")
assert(env.editor_reference_excerpt({})=="","no selected notes must not trigger reference acquisition")
local originalCount=api.MIDI_CountEvts
api.MIDI_CountEvts=function(tk)
 if tk=="tk1" then return true,2501 end
 return originalCount(tk)
end
local tooLarge,reason=env.notation_visible_items(true)
assert(tooLarge==nil and reason:find("2500"),"must reject over-budget score rather than truncating")
api.MIDI_CountEvts=originalCount
env.focused_or_last_notation_editor=function() return nil end
assert(env.notation_visible_items(true)==nil,"closed score editor cannot become global selection")

local opened=101
local edits=0
local commands={}
local labels={
 {100,"View: Mode: musical notation"},
 {200,"Script: REAPER Notation - 4 Takte und Instrumentenschluessel.lua"},
 {300,"View: Mode: piano roll"},
}
local action= {
 CountSelectedMediaItems=function() return 1 end,
 GetSelectedMediaItem=function() return "it1" end,
 GetActiveTake=function() return "tk1" end,
 TakeIsMIDI=api.TakeIsMIDI,
 Main_OnCommand=function(id) assert(id==40153);opened=101 end,
 kbd_enumerateActions=function(_,i)
  local row=labels[i+1];if row then return table.unpack(row) end
  return 0,""
 end,
 SectionFromUniqueID=function(sec) assert(sec==32060);return "section" end,
 MIDIEditor_OnCommand=function(ed,id) assert(ed==101);edits=edits+1;commands[#commands+1]=id;return true end,
 MIDI_SetNote=function() error("display action must not write MIDI") end,
 SetMediaItemSelected=function() error("display action must not select items") end,
}
local avenv={reaper=action,focused_or_last_notation_editor=function() return opened end}
compile("local function open_score_workspace","local function begin_process",avenv)
local ok,msg=avenv.open_score_workspace()
assert(ok and edits==2 and commands[1]==100 and commands[2]==200,"notation mode then original shortcut")
assert(msg:find("vorbereitet"),"positive status")
edits=0;commands={}
ok,msg=avenv.open_score_workspace("pianoroll")
assert(ok and edits==1 and commands[1]==300,"Piano Roll uses its native view switch and never launches notation shortcut")
assert(msg:find("Piano%-Roll"),"Piano-Roll confirmation")
opened=nil;edits=0;commands={}
action.CountSelectedMediaItems=function() return 0 end
assert(avenv.open_score_workspace()==false,"must not open MIDI editor without any MIDI item selection")
action.CountSelectedMediaItems=function() return 1 end
opened=nil
ok=avenv.open_score_workspace()
assert(ok and opened==101,"open MIDI editor from selected arrangement items")
labels={{100,"View: Mode: musical notation"}}
opened=101
ok,msg=avenv.open_score_workspace()
assert(not ok and msg:find("Vier%-Takte"),"missing companion action reported, never silently claimed")
assert(source:find('if explicitScore then',1,true),"explicit shared MIDI editor request mode in central command router")
assert(source:find('lower:find("piano-roll",1,true)',1,true),
 "Piano-Roll mentioned in explicit editor context")
assert(source:find('local reference=hasSelection and editor_reference_excerpt(snapshot) or ""',1,true),
 "selected-note AI route gets separate read-only harmonic reference")
assert(source:find('local reference=editor_reference_excerpt(items)',1,true),
 "selected-note patch prompt receives surrounding reference voices")
assert(source:find('open_score_workspace("pianoroll")',1,true),
 "Studio supports explicit Piano-Roll view requests")
assert(source:find('local explicitScore=score_request_intent(lower) and not mentionsSelectedNotes',1,true),
 "individual selected notes must never be replaced with full-score context")
assert(source:find('local items=scoreItems or selected_items(false)',1,true),
 "explicit score context takes precedence over arrangement selection")
assert(source:find('r.score_scope or #(r.notation_selection or {})>0',1,true),
 "score modifications must reject original-track replacement")
assert(source:find('if notationCount==0 and mentionsSelectedNotes then',1,true),
 "Piano-Roll selected-note request with no selection must fail closed")
assert(source:find('if it.score_context then',1,true) and
 source:find('Sofortaktionen auf komplette Items sind im Piano-Roll-/Partiturkontext gesperrt',1,true),
 "whole-item immediate ACTION must be blocked for full-editor references")
assert(source:find('score_context_tracks(scoreItems)',1,true),
 "score-only analysis and composition inherit visible track bindings")
assert(source:find('if score_request_intent(request:lower()) then',1,true),
 "explicit score continuation has a dedicated source-scope switch")
assert(source:find('context=visible; tracks=score_context_tracks(context)',1,true),
 "score continuation derives track bindings from notation editor, not arrangement")
print("OK: actual production score-context and notation bridge functions pass multi-track, no-mutation, limit and fallback tests")

-- Saved analysis -> revision must preserve its scope, including after reload.
local base={
 {guid="it1",take="tk1",track="tr1",track_guid="tr1",track_name="Melody",notes={{pitch=60},{pitch=62}},start_qn=0,end_qn=8},
 {guid="hidden",take="tk3",track="tr1",track_guid="tr1",notes={{pitch=99}},start_qn=8,end_qn=16},
 {guid="it2",take="tk2",track="tr2",track_guid="tr2",notes={{pitch=48}},start_qn=0,end_qn=8},
}
local launched
local rev={reaper=api,busy=false,input="",trim=function(x)return x end,
 track_context_items=function() local rows={};for _,it in ipairs(base) do local row={};for k,v in pairs(it) do row[k]=v end;rows[#rows+1]=row end;return rows end,
 get_key=function()return "offline-test" end,
 workflow_core={prompt=function()return "revise" end},
 composition_prompt=function(_,rows)
  return rows[1].score_context and "READ ONLY SCORE" or rows[1].selection_source and "SELECTED NOTES ONLY" or "UNSCOPED"
 end,
 launch=function(stage,prompt,key,data)launched={stage=stage,prompt=prompt,data=data}end,
 workflow_adapter={normalize_guard=function(v)return v end,guard=function()return "guard" end,bindings=function()return {},{{track="tr1",guid="tr1",name="Melody"}}end},
}
compile("function workflow_adapter.review","workflow_adapter_guard=",rev)
local saved={stage="analysis",source_guard="guard",raw_response="analysis",bindings={"it1"},score_scope=true}
rev.workflow_adapter.analysis=saved
rev.workflow_adapter.review("Revise")
assert(launched and #launched.data.full==1 and launched.data.full[1].guid=="it1")
assert(launched.data.full[1].score_context and launched.prompt:find("READ ONLY SCORE",1,true),"score read-only survives analysis follow-up")
local ref={index=1,start_ppq=480,end_ppq=960,pitch=62,velocity=90,channel=0}
saved.score_scope=false;saved.notation_selection={{guid="it1",notes={ref}}};saved.reference_context="READ ONLY HARMONY"
launched=nil;rev.busy=false
rev.workflow_adapter.review("Revise")
local only=assert(launched).data.full[1]
assert(#launched.data.full==1 and #only.notes==1 and only.notes[1].pitch==62 and only.notes[1].start_qn==1)
assert(only.selection_source[1]==ref and launched.prompt:find("READ ONLY HARMONY",1,true),"selected-note identity and reference retained")
assert(launched.data.reference_context==saved.reference_context)
saved.source_guard="changed";launched=nil;rev.busy=false
rev.workflow_adapter.review("Revise")
assert(not launched,"stale saved analysis never launches")

-- Exercise the actual apply boundary with malicious whole-item AI output.
local reported
local blocked={busy=false,diag_set=function()end,workflow_core={check=function()end},
 workflow_adapter={pending={stage="composition",state="ready",score_scope=true,payload="CS|target|it1|bad"},
 normalize_guard=function(v)return v end,guard_difference=function()return "difference"end,guard=function()return "guard"end,save=function()end},add=function(_,text)reported=text end}
compile("function workflow_adapter.apply","function workflow_adapter.review",blocked)
blocked.workflow_adapter.apply()
assert(reported and reported:find("überschreiben",1,true),"score context cannot overwrite original item")
blocked.workflow_adapter.pending.score_scope=false
blocked.workflow_adapter.pending.notation_selection={{guid="it1",notes={ref}}}
blocked.workflow_adapter.pending.payload="CS|track|tr1|bad";reported=nil
blocked.workflow_adapter.apply()
assert(reported and reported:find("bestehende Spuren",1,true),"selected-note revision cannot write to reference tracks")

local stopped
local continuation={add=function(_,message)stopped=message end,busy=true}
compile("local function begin_continuation","local function notation_patch_prompt",continuation)
continuation.begin_continuation("Verlängere die markierten Noten im Piano-Roll um 4 Takte",4,0)
assert(stopped and not continuation.busy,"selected-note continuation never expands to complete items")
print("OK: saved analysis scope, harmonic reference, stale guard, malicious apply and continuation isolation")
