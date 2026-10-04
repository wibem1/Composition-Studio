-- @description Notation Studio
-- @version 0.1.0
-- @author Klangwerke
-- @about Native REAPER notation tools and AI palette.

local EXT_SECTION="CompositionStudio"
local VERSION="0.1.0"
local MAIN_PATH=reaper.GetResourcePath().."/Scripts/Composition Studio/Composition Studio.lua"

if type(reaper.ImGui_CreateContext)~="function" then
 reaper.ShowMessageBox("Notation Studio benötigt ReaImGui.","Notation Studio",0)
 return
end

local ctx=reaper.ImGui_CreateContext("Notation Studio",reaper.ImGui_ConfigFlags_DockingEnable())
local open=true
local status=""
local ai_input=""
local ai_answer=""
local last_result_seq=""

local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end

local function midi_action_by_name(name)
 if type(reaper.kbd_enumerateActions)=="function" and type(reaper.kbd_getTextFromCmd)=="function" then
  local i=0
  while true do
   local cmd=reaper.kbd_enumerateActions(32060,i)
   if not cmd or cmd==0 then break end
   if reaper.kbd_getTextFromCmd(cmd,32060)==name then return cmd end
   i=i+1
  end
 end
 local fallback={["View: Zoom to content"]=40466}
 return fallback[name]
end

local function active_editor()
 return type(reaper.MIDIEditor_GetActive)=="function" and reaper.MIDIEditor_GetActive() or nil
end

local function run_action(name,times)
 local ed=active_editor()
 if not ed then status="Kein aktiver MIDI-Editor."; return false end
 local cmd=midi_action_by_name(name)
 if not cmd then status="REAPER-Aktion nicht gefunden: "..name; return false end
 for _=1,math.max(1,math.floor(times or 1)) do reaper.MIDIEditor_OnCommand(ed,cmd) end
 status=name
 return true
end

local function set_toggle(name,enable)
 local ed=active_editor()
 if not ed then status="Kein aktiver MIDI-Editor."; return false end
 local cmd=midi_action_by_name(name)
 if not cmd then status="REAPER-Aktion nicht gefunden: "..name; return false end
 local st=type(reaper.GetToggleCommandStateEx)=="function" and reaper.GetToggleCommandStateEx(32060,cmd) or -1
 if st==-1 or (st==1)~=enable then reaper.MIDIEditor_OnCommand(ed,cmd) end
 return true
end

local function spacing_state()
 local cmd=midi_action_by_name("Notation: Proportional (musical) note spacing")
 if not cmd then return nil,nil end
 local st=type(reaper.GetToggleCommandStateEx)=="function" and reaper.GetToggleCommandStateEx(32060,cmd) or -1
 return st==1,cmd
end

local function set_musical_spacing(enable)
 local ed=active_editor()
 if not ed then status="Kein aktiver MIDI-Editor."; return false end
 local on,cmd=spacing_state()
 if not cmd then status="Musikalische Notenabstände wurden nicht gefunden."; return false end
 if on~=enable then reaper.MIDIEditor_OnCommand(ed,cmd) end
 status=enable and "Musikalische proportionale Abstände eingeschaltet." or "Absolute Rasterabstände eingeschaltet."
 return true
end

local function cleanup_notation()
 local ed=active_editor()
 if not ed then status="Kein aktiver MIDI-Editor."; return end
 local missing={}
 local function act(name)
  local cmd=midi_action_by_name(name)
  if cmd then reaper.MIDIEditor_OnCommand(ed,cmd) else missing[#missing+1]=name end
 end
 set_musical_spacing(true)
 act("Notation: Set display quantization to 1/16 (default)")
 act("Notation: Set minimum display quantization note length to 1/64 (default)")
 set_toggle("Notation: Automatically detect triplets",true)
 set_toggle("Notation: Automatically voice overlapping notes",true)
 act("View: Zoom to content")
 if #missing==0 then
  status="Lesbarkeit verbessert."
 else
  status="Teilweise ausgeführt. Nicht gefunden: "..table.concat(missing,", ")
 end
end

local function selected_takes()
 local out={}
 local ed=active_editor()
 if not ed then return out end
 if type(reaper.MIDIEditor_EnumTakes)=="function" then
  local i=0
  while true do
   local tk=reaper.MIDIEditor_EnumTakes(ed,i,true)
   if not tk then break end
   if reaper.ValidatePtr2(0,tk,"MediaItem_Take*") and reaper.TakeIsMIDI(tk) then out[#out+1]=tk end
   i=i+1
  end
 else
  local tk=reaper.MIDIEditor_GetTake(ed)
  if tk and reaper.TakeIsMIDI(tk) then out[1]=tk end
 end
 return out
end

local function selection_context()
 local out={"NOTATION_SELECTION"}
 local count=0
 for _,tk in ipairs(selected_takes()) do
  local item=reaper.GetMediaItemTake_Item(tk)
  local tr=item and reaper.GetMediaItem_Track(item)
  local _,tn=tr and reaper.GetTrackName(tr) or false,""
  local i=-1
  while true do
   i=reaper.MIDI_EnumSelNotes(tk,i)
   if i==-1 then break end
   local ok,_,mut,sp,ep,ch,p,v=reaper.MIDI_GetNote(tk,i)
   if ok and not mut then
    count=count+1
    local st=reaper.MIDI_GetProjTimeFromPPQPos(tk,sp)
    local et=reaper.MIDI_GetProjTimeFromPPQPos(tk,ep)
    local sq=reaper.TimeMap2_timeToQN(0,st)
    local eq=reaper.TimeMap2_timeToQN(0,et)
    out[#out+1]=string.format("SELNOTE %d track=%s startQN=%.6f durationQN=%.6f pitch=%d velocity=%d channel=%d",count,tn or "",sq,eq-sq,p,v,ch)
   end
  end
 end
 return table.concat(out,"\n"),count
end

local function ensure_main_running()
 if reaper.GetExtState(EXT_SECTION,"WindowOpen")=="1" then return true end
 local f=io.open(MAIN_PATH,"rb")
 if not f then status="Composition Studio wurde nicht gefunden."; return false end
 f:close()
 pcall(dofile,MAIN_PATH)
 return true
end

local function send_ai(request)
 local context,count=selection_context()
 if count==0 then status="Bitte zuerst Note(n) im nativen Notationseditor markieren."; return end
 if not ensure_main_running() then return end
 reaper.SetExtState(EXT_SECTION,"NotationAIRequest",request,false)
 reaper.SetExtState(EXT_SECTION,"NotationAIContext",context,false)
 local seq=tostring(os.time())..":"..tostring(math.random(100000,999999))
 reaper.SetExtState(EXT_SECTION,"NotationAIRequestSeq",seq,false)
 status="KI-Auftrag an Composition Studio übergeben …"
end

local function poll_ai_result()
 local seq=reaper.GetExtState(EXT_SECTION,"NotationAIResultSeq")
 if seq=="" or seq==last_result_seq then return end
 last_result_seq=seq
 ai_answer=reaper.GetExtState(EXT_SECTION,"NotationAIResult")
 status="KI-Antwort erhalten."
end

local function draw()
 reaper.ImGui_SetNextWindowSize(ctx,450,600,reaper.ImGui_Cond_FirstUseEver())
 local visible
 visible,open=reaper.ImGui_Begin(ctx,"Notation Studio v"..VERSION.."###NotationStudio",open)
 if visible then
  local _,nsel=selection_context()
  reaper.ImGui_Text(ctx,"Native REAPER-Notation · "..tostring(nsel).." Note(n) markiert")
  reaper.ImGui_Separator(ctx)

  if reaper.ImGui_CollapsingHeader(ctx,"Lesbarkeit",reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
   if reaper.ImGui_Button(ctx,"Lesbarkeit verbessern",-1,36) then cleanup_notation() end
   local on=select(1,spacing_state())
   if reaper.ImGui_Button(ctx,(on and "Musikalische Abstände ✓" or "Musikalische Abstände").."##spacing",-1,30) then set_musical_spacing(not on) end
   local w=select(1,reaper.ImGui_GetContentRegionAvail(ctx)); local g=6; local h=math.max(100,(w-g)/2)
   if reaper.ImGui_Button(ctx,"Breiter +",h,30) then run_action("View: Zoom in horizontally",1) end
   reaper.ImGui_SameLine(ctx,0,g)
   if reaper.ImGui_Button(ctx,"Schmaler –",h,30) then run_action("View: Zoom out horizontally",1) end
   if reaper.ImGui_Button(ctx,"Auswahl einpassen",h,30) then run_action("View: Zoom to selected notes/CC",1) end
   reaper.ImGui_SameLine(ctx,0,g)
   if reaper.ImGui_Button(ctx,"Inhalt einpassen",h,30) then run_action("View: Zoom to content",1) end
  end

  if reaper.ImGui_CollapsingHeader(ctx,"Darstellung / Quantisierung") then
   if reaper.ImGui_Button(ctx,"Anzeige 1/8",-1,28) then run_action("Notation: Set display quantization to 1/8",1) end
   if reaper.ImGui_Button(ctx,"Anzeige 1/16",-1,28) then run_action("Notation: Set display quantization to 1/16 (default)",1) end
   if reaper.ImGui_Button(ctx,"Anzeige 1/32",-1,28) then run_action("Notation: Set display quantization to 1/32",1) end
  end

  if reaper.ImGui_CollapsingHeader(ctx,"KI",reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
   if reaper.ImGui_Button(ctx,"Auswahl analysieren",-1,30) then
    send_ai("Analysiere ausschließlich die im Notationseditor markierten Noten: Melodik, Rhythmus, Harmonik, Phrasierung, Lesbarkeit und auffällige Probleme. Verändere nichts.")
   end
   if reaper.ImGui_Button(ctx,"Artikulation / Dynamik beurteilen",-1,30) then
    send_ai("Beurteile ausschließlich für die markierten Noten Artikulation, Dynamik und Phrasierung. Schlage konkrete Verbesserungen vor, ohne etwas zu verändern.")
   end
   local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##notation_ai_input",ai_input,-1,72)
   if changed then ai_input=v end
   if reaper.ImGui_Button(ctx,"KI-Auftrag zur Auswahl",-1,32) then
    local r=trim(ai_input)
    if r~="" then send_ai(r) end
   end
   if ai_answer~="" then
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextWrapped(ctx,ai_answer)
   end
  end

  if reaper.ImGui_CollapsingHeader(ctx,"Stimmen / Notation") then
   reaper.ImGui_TextWrapped(ctx,"Weitere native Notationsbefehle werden hier gebündelt.")
  end
  if reaper.ImGui_CollapsingHeader(ctx,"Artikulation") then
   reaper.ImGui_TextWrapped(ctx,"Legato, Staccato, Tenuto, Akzent, Marcato und Tremolo.")
  end
  if reaper.ImGui_CollapsingHeader(ctx,"Dynamik") then
   reaper.ImGui_TextWrapped(ctx,"pp bis ff sowie Crescendo und Diminuendo.")
  end
  if reaper.ImGui_CollapsingHeader(ctx,"Spielweise / SWAM") then
   reaper.ImGui_TextWrapped(ctx,"pizz., arco, sul pont., sul tasto, Flageolett und SWAM-Steuerung.")
  end

  if status~="" then
   reaper.ImGui_Separator(ctx)
   reaper.ImGui_TextWrapped(ctx,status)
  end
  reaper.ImGui_End(ctx)
 end
end

local function loop()
 poll_ai_result()
 if not open then return end
 draw()
 reaper.defer(loop)
end

loop()
