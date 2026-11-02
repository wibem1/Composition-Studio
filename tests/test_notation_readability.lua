-- Offline regression test for the real Notation Studio.lua; no REAPER or AI needed.
-- Run from repository root: texlua tests/test_notation_readability.lua
local source="Notation Studio.lua"
local state={focused=true,alive=true,visible=true,click=true,toggle=0,actions={},ends=0,frames=0,labels={},action_available=true,manual_click=false,stuck=false}
local reaper={}
function reaper.GetExtState() return "" end
function reaper.MIDIEditor_GetActive() return state.focused and "ed" or nil end
function reaper.MIDIEditor_GetTake(ed) return ed=="ed" and state.alive and "tk" or nil end
function reaper.TakeIsMIDI(tk) return tk=="tk" end
function reaper.GetMediaItemTake_Item(tk) return tk=="tk" and "item" or nil end
function reaper.GetMediaItem_Track(item) return item=="item" and "track" or nil end
function reaper.GetTrackName(track) assert(track=="track");return true,"Violine - G-Schluessel" end
function reaper.GetTrackStateChunk(track) assert(track=="track");return true,"<TRACK\nNAME \"Violine - G-Schluessel\"\nSCORE 0 0 0 0\n>\n" end
function reaper.ValidatePtr2(_,tk,kind) return tk=="tk" and kind=="MediaItem_Take*" and state.alive end
function reaper.SectionFromUniqueID(id) assert(id==32060); return id end
function reaper.kbd_enumerateActions(_,i)
 if i==0 then return 401,"Notation: Set display quantization to 1/16 (default)" end
 if i==1 and state.action_available then return 405,"Notation: Proportional (musical) note spacing" end
 return 0,""
end
function reaper.GetToggleCommandStateEx(_,cmd) assert(cmd==405); return state.toggle end
function reaper.MIDIEditor_OnCommand(ed,cmd)
 assert(ed=="ed" and state.alive,"invalid editor")
 assert(cmd==405,"wrong action: must not invoke quantization or other commands")
 state.actions[#state.actions+1]=cmd
 if not state.stuck and (state.toggle==0 or state.toggle==1) then state.toggle=1-state.toggle end
end
function reaper.MIDIEditor_EnumTakes() return nil end
function reaper.ImGui_CreateContext() return {} end
function reaper.ImGui_ConfigFlags_DockingEnable() return 0 end
function reaper.ImGui_SetNextWindowSize() end
function reaper.ImGui_Cond_FirstUseEver() return 0 end
function reaper.ImGui_Begin(_,_,open) state.frames=state.frames+1; return state.visible,open end
function reaper.ImGui_End() state.ends=state.ends+1 end
function reaper.ImGui_Text(_,s) state.labels[#state.labels+1]=s end
function reaper.ImGui_TextWrapped(_,s) state.labels[#state.labels+1]=s end
function reaper.ImGui_SameLine() end
function reaper.ImGui_Button(_,label)
 if label=="Lesbarkeit verbessern" and state.click then state.click=false; return true end
 if label:find("##spacing",1,true) and state.manual_click then state.manual_click=false; return true end
 return false
end
function reaper.ImGui_OpenPopup() end
function reaper.ImGui_BeginPopup() return false end
function reaper.ImGui_Separator() end
function reaper.ImGui_CollapsingHeader(_,s) return s=="Lesbarkeit" end
function reaper.ImGui_TreeNodeFlags_DefaultOpen() return 0 end
function reaper.ImGui_GetContentRegionAvail() return 440,400 end
function reaper.ImGui_InputTextMultiline(_,_,text) return false,text end
function reaper.defer(fn) state.next_frame=fn end
function reaper.SetTrackStateChunk() error("Must not edit SCORE track chunk") end
function reaper.MIDI_SetNote() error("Must not mutate MIDI") end
function reaper.MIDI_SetAllEvts() error("Must not mutate MIDI") end
function reaper.MIDI_InsertTextSysexEvt() error("Must not mutate metadata") end
_G.reaper=reaper

local function check(value,name)
 assert(value,name)
 print("PASS "..name)
end
local function frame(click)
 state.click=click
 assert(state.next_frame,"No REAPER defer callback")
 state.next_frame()
end
local f,err=loadfile(source)
assert(f,err)
f()
check(#state.actions==1 and state.toggle==1,"only proportional spacing enabled")
frame(true)
check(#state.actions==1,"second click is idempotent")
state.toggle=-1
frame(true)
check(#state.actions==1,"unknown toggle state fails closed")
state.toggle=0
state.focused=false
frame(true)
check(#state.actions==2 and state.toggle==1,"cached live editor works without REAPER focus")
state.alive=false
frame(true)
check(#state.actions==2,"stale cached editor is refused")
state.visible=false
frame(false)
check(state.ends==state.frames,"ImGui Begin/End paired when collapsed")
state.alive=true
state.focused=true
state.visible=true
state.toggle=1
state.manual_click=true
frame(false)
check(#state.actions==3 and state.toggle==0,"explicit manual spacing-off remains possible")
state.action_available=false
frame(true)
check(#state.actions==3,"missing spacing action fails closed")
state.action_available=true
state.stuck=true
frame(true)
check(#state.actions==4 and state.toggle==0,"unconfirmed action does not report success")
check(not table.concat(state.labels,"\n"):find("Track State geschrieben",1,true),"UI makes no false claim of track mutation")
print("OK: 10 REAPER-API mock regression checks; real REAPER GUI not tested")
