-- @description Notation Studio
-- @version 0.1.4
-- @author Klangwerke
-- @about Native REAPER notation tools and AI palette.

local EXT_SECTION="CompositionStudio"
local VERSION="0.1.4"
local PROVIDER_KEY,MODEL_KEY="AIProvider","AIModel"
local SCRIPT_PATH=(debug.getinfo(1,"S").source or ""):gsub("^@","")
local UPDATE_URL="https://raw.githubusercontent.com/wibem1/Composition-Studio/main/Notation%20Studio.lua"
local KEY_NAMES={openai="OpenAIAPIKey",anthropic="AnthropicAPIKey",google="GoogleAPIKey"}
local MODELS={
 openai={{"GPT-5.6 Sol","gpt-5.6-sol"},{"GPT-5.6 Terra","gpt-5.6-terra"},{"GPT-5.6 Luna","gpt-5.6-luna"}},
 anthropic={{"Claude Fable 5","claude-fable-5"},{"Claude Sonnet 5","claude-sonnet-5"},{"Claude Opus 5","claude-opus-5"}},
 google={{"Gemini 3.8 Flash","gemini-3.8-flash"},{"Gemini 3.1 Pro","gemini-3.1-pro-preview"},{"Gemini 2.5 Pro","gemini-2.5-pro"}}
}
local provider=reaper.GetExtState(EXT_SECTION,PROVIDER_KEY)
if provider=="" or not MODELS[provider] then provider="openai" end
local model=reaper.GetExtState(EXT_SECTION,MODEL_KEY)
if model=="" then model=MODELS[provider][1][2] end

if type(reaper.ImGui_CreateContext)~="function" then
 reaper.ShowMessageBox("Notation Studio benötigt ReaImGui.","Notation Studio",0)
 return
end

local midi_editor=reaper.MIDIEditor_GetActive()
local ctx=reaper.ImGui_CreateContext("Notation Studio",reaper.ImGui_ConfigFlags_DockingEnable())
local ui_font=nil
if type(reaper.ImGui_CreateFont)=="function" then
 local ok,f=pcall(reaper.ImGui_CreateFont,"sans-serif",20)
 if ok then ui_font=f end
end
if ui_font and type(reaper.ImGui_Attach)=="function" then pcall(reaper.ImGui_Attach,ctx,ui_font) end
local open=true
local status=""
local ai_input=""
local ai_answer=""
local ai_job=nil
local ai_busy=false

local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(v) return "'"..tostring(v):gsub("'","'\\''").."'" end
local function json_escape(v) return tostring(v or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end; local x=f:read("*a"); f:close(); return x end
local function write_file(p,x) local f=io.open(p,"wb"); if not f then return false end; f:write(x); f:close(); return true end
local function version_is_newer(remote,localv)
 local a,b,c=tostring(remote or ""):match("^(%d+)%.(%d+)%.(%d+)$")
 local x,y,z=tostring(localv or ""):match("^(%d+)%.(%d+)%.(%d+)$")
 if not (a and x) then return false end
 a,b,c,x,y,z=tonumber(a),tonumber(b),tonumber(c),tonumber(x),tonumber(y),tonumber(z)
 if a~=x then return a>x end
 if b~=y then return b>y end
 return c>z
end
local function install_update()
 if ai_busy then status="Update erst möglich, wenn die KI fertig ist."; return end
 status="Update wird geladen …"
 local tmp=os.tmpname()..".lua"
 local cmd="/usr/bin/curl -sS -L --max-time 60 -H 'Cache-Control: no-cache' -o "..shell_quote(tmp).." "..shell_quote(UPDATE_URL.."?nocache="..tostring(os.time()))
 local rc=os.execute(cmd)
 local fresh=read_file(tmp); os.remove(tmp)
 if not fresh or #fresh<500 then status="Update fehlgeschlagen."; return end
 local rv=fresh:match("%-%- @version%s+([%w%.%-]+)")
 if not rv or not fresh:find("%-%- @description Notation Studio") then status="Update abgebrochen: ungültige Datei."; return end
 if rv==VERSION then status="Bereits aktuell: "..VERSION; return end
 if not version_is_newer(rv,VERSION) then status="Kein neueres Update verfügbar. Lokal: "..VERSION..", GitHub: "..rv; return end
 local compiled,err=load(fresh,"@Notation Studio update","t")
 if not compiled then status="Update abgebrochen: Lua-Syntaxfehler: "..tostring(err); return end
 local previous=read_file(SCRIPT_PATH)
 if not previous or not write_file(SCRIPT_PATH..".backup",previous) or not write_file(SCRIPT_PATH,fresh) then status="Update konnte nicht sicher installiert werden."; return end
 status="Update auf "..rv.." installiert. Neustart …"
 open=false
 reaper.defer(function() pcall(dofile,SCRIPT_PATH) end)
end
local function read_json_string(raw,q)
 local out,i={},q+1
 while i<=#raw do
  local c=raw:sub(i,i)
  if c=='"' then return table.concat(out) end
  if c=="\\" then
   i=i+1; local e=raw:sub(i,i)
   if e=="n" then out[#out+1]="\n"
   elseif e=="r" then out[#out+1]="\r"
   elseif e=="t" then out[#out+1]="\t"
   elseif e=='"' then out[#out+1]='"'
   elseif e=="\\" then out[#out+1]="\\"
   else out[#out+1]=e end
  else out[#out+1]=c end
  i=i+1
 end
 return table.concat(out)
end
local function response_text(raw)
 local a,b=(raw or ""):find('"type"%s*:%s*"output_text"'); if not a then return nil end
 local c,d=raw:find('"text"%s*:',b+1); if not c then return nil end
 local q=raw:find('"',d+1,true); return q and read_json_string(raw,q) or nil
end
local function first_text_field(raw)
 local a,b=(raw or ""):find('"text"%s*:'); if not a then return nil end
 local q=raw:find('"',b+1,true); return q and read_json_string(raw,q) or nil
end
local function provider_name() return provider=="openai" and "OpenAI" or provider=="anthropic" and "Anthropic" or "Google" end
local function model_label()
 for _,m in ipairs(MODELS[provider] or {}) do if m[2]==model then return m[1] end end
 return model
end
local function get_key()
 local k=trim(reaper.GetExtState(EXT_SECTION,KEY_NAMES[provider]))
 if k~="" then return k end
 local ok,v=reaper.GetUserInputs("Notation Studio – KI-Zugang",1,provider_name().." API-Key:,extrawidth=320","")
 if not ok then return nil end
 k=trim(v)
 if k~="" then reaper.SetExtState(EXT_SECTION,KEY_NAMES[provider],k,true); return k end
end

local function midi_section()
 if type(reaper.SectionFromUniqueID)~="function" then return nil end
 return reaper.SectionFromUniqueID(32060)
end

local function midi_action_by_name(name)
 local section=midi_section()
 if section and type(reaper.kbd_enumerateActions)=="function" then
  local i=0
  while true do
   local cmd,txt=reaper.kbd_enumerateActions(section,i)
   if not cmd or cmd==0 then break end
   if txt==name then return cmd end
   i=i+1
  end
 end
 local fallback={
  ["View: Zoom to content"]=40466
 }
 return fallback[name]
end

local function active_editor()
 local cur=type(reaper.MIDIEditor_GetActive)=="function" and reaper.MIDIEditor_GetActive() or nil
 if cur then midi_editor=cur end
 return midi_editor
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
 if not ed then status="Kein MIDI-Editor gefunden. Notation Studio bitte aus dem geöffneten Notationseditor starten."; return end
 local missing={}
 local applied={}
 local function act(name)
  local cmd=midi_action_by_name(name)
  if cmd then
   local ok=reaper.MIDIEditor_OnCommand(ed,cmd)
   if ok==false then missing[#missing+1]=name.." (nicht ausführbar)" else applied[#applied+1]=name end
  else
   missing[#missing+1]=name
  end
 end

 -- REAPER 7.81: exact MIDI-editor notation actions.
 local spacing_cmd=midi_action_by_name("Notation: Proportional (musical) note spacing")
 if spacing_cmd then
  local state=reaper.GetToggleCommandStateEx(32060,spacing_cmd)
  if state~=1 then reaper.MIDIEditor_OnCommand(ed,spacing_cmd) end
  applied[#applied+1]="Proportional spacing"
 else
  missing[#missing+1]="Notation: Proportional (musical) note spacing"
 end

 act("Notation: Set display quantization to 1/16 (default)")
 act("Notation: Set minimum display quantization note length to 1/16")
 local trip=midi_action_by_name("Notation: Automatically detect triplets")
 if trip then
  if reaper.GetToggleCommandStateEx(32060,trip)~=1 then reaper.MIDIEditor_OnCommand(ed,trip) end
  applied[#applied+1]="Triplet detection"
 else missing[#missing+1]="Notation: Automatically detect triplets" end

 local voice=midi_action_by_name("Notation: Automatically voice overlapping notes")
 if voice then
  if reaper.GetToggleCommandStateEx(32060,voice)~=1 then reaper.MIDIEditor_OnCommand(ed,voice) end
  applied[#applied+1]="Automatic voicing"
 else missing[#missing+1]="Notation: Automatically voice overlapping notes" end

 local zoom=midi_action_by_name("View: Zoom to content")
 if zoom then reaper.MIDIEditor_OnCommand(ed,zoom) end

 if #missing==0 then
  status="Lesbarkeit verbessert: proportionale Abstände, Anzeige 1/16, Mindestlänge 1/16, Triolen- und Stimmenautomatik."
 else
  status="Teilweise ausgeführt. Nicht gefunden: "..table.concat(missing," | ")
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

local function send_ai(request)
 if ai_busy then status="KI arbeitet bereits."; return end
 local context,count=selection_context()
 if count==0 then status="Bitte zuerst Note(n) im nativen Notationseditor markieren."; return end
 local key=get_key()
 if not key then status="Kein API-Key verfügbar."; return end
 local prompt=[[Du bist der musikalische Assistent von Notation Studio in REAPER.
Beziehe dich ausschließlich auf die als NOTATION_SELECTION übergebenen markierten Noten.
Erfinde keine nicht vorhandenen Noten. Bei Analyse- oder Beurteilungsaufträgen veränderst du nichts.
Antworte musikalisch präzise und konkret.

AUFTRAG:
]]..request.."\n\n"..context
 local base=os.tmpname()
 local rq,rs,cd=base..".json",base..".out",base..".code"
 local body,url,headers
 if provider=="openai" then
  body='{"model":"'..json_escape(model)..'","input":"'..json_escape(prompt)..'"}'
  url="https://api.openai.com/v1/responses"
  headers="-H "..shell_quote("Authorization: Bearer "..key).." -H 'Content-Type: application/json'"
 elseif provider=="anthropic" then
  body='{"model":"'..json_escape(model)..'","max_tokens":8000,"messages":[{"role":"user","content":"'..json_escape(prompt)..'"}]}'
  url="https://api.anthropic.com/v1/messages"
  headers="-H "..shell_quote("x-api-key: "..key).." -H 'anthropic-version: 2023-06-01' -H 'Content-Type: application/json'"
 else
  body='{"contents":[{"parts":[{"text":"'..json_escape(prompt)..'"}]}]}'
  url="https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent?key="..key
  headers="-H 'Content-Type: application/json'"
 end
 if not write_file(rq,body) then status="KI-Anfrage konnte nicht vorbereitet werden."; return end
 local cmd="/usr/bin/curl -sS --max-time 180 -o "..shell_quote(rs).." -w '%{http_code}' "..headers.." --data-binary @"..shell_quote(rq).." "..shell_quote(url).." > "..shell_quote(cd).." 2>/dev/null &"
 os.execute(cmd)
 ai_job={rq=rq,rs=rs,cd=cd,pv=provider}
 ai_busy=true
 status="KI arbeitet …"
end

local function poll_ai_result()
 if not ai_job then return end
 local code=read_file(ai_job.cd)
 if not code or trim(code)=="" then return end
 local raw=read_file(ai_job.rs)
 local http=trim(code)
 local pv=ai_job.pv
 os.remove(ai_job.rq); os.remove(ai_job.rs); os.remove(ai_job.cd)
 ai_job=nil; ai_busy=false
 if http~="200" or not raw then status="KI-Aufruf fehlgeschlagen (HTTP "..http..")."; return end
 local text=pv=="openai" and response_text(raw) or first_text_field(raw)
 if not text or trim(text)=="" then status="KI-Antwort konnte nicht gelesen werden."; return end
 ai_answer=trim(text)
 status="KI-Antwort erhalten."
end

local function draw()
 reaper.ImGui_SetNextWindowSize(ctx,520,680,reaper.ImGui_Cond_FirstUseEver())
 local visible
 visible,open=reaper.ImGui_Begin(ctx,"Notation Studio v"..VERSION.."###NotationStudio",open)
 if visible then
  local pushed=false
  if ui_font and type(reaper.ImGui_PushFont)=="function" then
   pushed=pcall(reaper.ImGui_PushFont,ctx,ui_font,20)
  end
  local _,nsel=selection_context()
  reaper.ImGui_Text(ctx,"Native REAPER-Notation · "..tostring(nsel).." Note(n) markiert")
  if not active_editor() then reaper.ImGui_TextWrapped(ctx,"Kein MIDI-Editor gebunden – bitte Notation Studio aus dem geöffneten Notationseditor starten.") end
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
   reaper.ImGui_Text(ctx,model_label())
   if reaper.ImGui_Button(ctx,"Auswahl analysieren",-1,30) then
    send_ai("Analysiere ausschließlich die im Notationseditor markierten Noten: Melodik, Rhythmus, Harmonik, Phrasierung, Lesbarkeit und auffällige Probleme. Verändere nichts.")
   end
   if reaper.ImGui_Button(ctx,"Artikulation / Dynamik beurteilen",-1,30) then
    send_ai("Beurteile ausschließlich für die markierten Noten Artikulation, Dynamik und Phrasierung. Schlage konkrete Verbesserungen vor, ohne etwas zu verändern.")
   end
   local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##notation_ai_input",ai_input,-1,72)
   if changed then ai_input=v end
   if reaper.ImGui_Button(ctx,ai_busy and "KI arbeitet …" or "KI-Auftrag zur Auswahl",-1,32) and not ai_busy then
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
  if pushed then reaper.ImGui_PopFont(ctx) end
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
