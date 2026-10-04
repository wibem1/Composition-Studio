-- @description Notation Studio
-- @version 0.1.22
-- @author Klangwerke
-- @about Native REAPER notation tools and AI palette.

local EXT_SECTION="CompositionStudio"
local VERSION="0.1.22"
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
local selected_takes

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
local function fetch_update(url,extra_headers)
 local tmp=os.tmpname()..".lua"
 local code=os.tmpname()..".code"
 local headers=extra_headers or ""
 local cmd="/usr/bin/curl -sS -L --max-time 60 -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "..headers.." -o "..shell_quote(tmp).." -w '%{http_code}' "..shell_quote(url).." > "..shell_quote(code)
 os.execute(cmd)
 local http=trim(read_file(code))
 local fresh=read_file(tmp)
 os.remove(code); os.remove(tmp)
 return http,fresh
end

local function install_update()
 if ai_busy then status="Update erst möglich, wenn die KI fertig ist."; return end
 status="Update wird geladen …"

 local api="https://api.github.com/repos/wibem1/Composition-Studio/contents/Notation%20Studio.lua?ref=main&nocache="..tostring(os.time())
 local http,fresh=fetch_update(api,"-H 'Accept: application/vnd.github.raw+json'")
 local rv=fresh and fresh:match("%-%- @version%s+([%w%.%-]+)") or nil

 if http~="200" or not fresh or not rv then
  http,fresh=fetch_update(UPDATE_URL.."?nocache="..tostring(os.time()))
  rv=fresh and fresh:match("%-%- @version%s+([%w%.%-]+)") or nil
 end

 if http~="200" or not fresh or #fresh<500 then
  status="Update fehlgeschlagen (HTTP "..tostring(http)..")."
  return
 end
 if not rv or not fresh:find("%-%- @description Notation Studio") then
  status="Update abgebrochen: ungültige Datei."
  return
 end
 if rv==VERSION then
  status="Bereits aktuell: "..VERSION
  return
 end
 if not version_is_newer(rv,VERSION) then
  status="Kein neueres Update verfügbar. Lokal: "..VERSION..", GitHub: "..rv
  return
 end

 local compiled,err=load(fresh,"@Notation Studio update","t")
 if not compiled then
  status="Update abgebrochen: Lua-Syntaxfehler: "..tostring(err)
  return
 end

 local previous=read_file(SCRIPT_PATH)
 if not previous or not write_file(SCRIPT_PATH..".backup",previous) or not write_file(SCRIPT_PATH,fresh) then
  status="Update konnte nicht sicher installiert werden."
  return
 end

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

local function all_midi_actions()
 local out={}
 local section=midi_section()
 if not section or type(reaper.kbd_enumerateActions)~="function" then return out end
 local i=0
 while true do
  local cmd,txt=reaper.kbd_enumerateActions(section,i)
  if not cmd or cmd==0 then break end
  out[#out+1]={cmd=cmd,text=tostring(txt or "")}
  i=i+1
 end
 return out
end

local function find_action_variants(variants)
 local acts=all_midi_actions()
 for _,terms in ipairs(variants or {}) do
  for _,a in ipairs(acts) do
   local low=a.text:lower()
   local ok=true
   for _,term in ipairs(terms) do
    if not low:find(tostring(term):lower(),1,true) then ok=false; break end
   end
   if ok then return a.cmd,a.text end
  end
 end
 return nil,nil
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

local function selected_note_stats()
 local first_qn,last_qn,count=nil,nil,0
 for _,tk in ipairs(selected_takes and selected_takes() or {}) do
  local i=-1
  while true do
   i=reaper.MIDI_EnumSelNotes(tk,i)
   if i==-1 then break end
   local ok,_,mut,sp,ep=reaper.MIDI_GetNote(tk,i)
   if ok and not mut then
    local st=reaper.MIDI_GetProjTimeFromPPQPos(tk,sp)
    local et=reaper.MIDI_GetProjTimeFromPPQPos(tk,ep)
    local sq=reaper.TimeMap2_timeToQN(0,st)
    local eq=reaper.TimeMap2_timeToQN(0,et)
    first_qn=first_qn and math.min(first_qn,sq) or sq
    last_qn=last_qn and math.max(last_qn,eq) or eq
    count=count+1
   end
  end
 end
 return first_qn,last_qn,count
end

local function disable_continuous_view(ed)
 local cmd,txt=find_action_variants({
  {"notation","continuous view always"},
  {"continuous view always"},
  {"continuous","regardless of zoom"}
 })
 if not cmd then
  local found={}
  for _,a in ipairs(all_midi_actions()) do
   local low=a.text:lower()
   if low:find("continuous",1,true) or (low:find("notation",1,true) and low:find("view",1,true)) then
    found[#found+1]=a.text
    if #found>=8 then break end
   end
  end
  return false,"Continuous-View-Action nicht gefunden"..(#found>0 and " | Gefunden: "..table.concat(found," || ") or "")
 end
 local before=reaper.GetToggleCommandStateEx(32060,cmd)
 if before==1 then reaper.MIDIEditor_OnCommand(ed,cmd) end
 local after=reaper.GetToggleCommandStateEx(32060,cmd)
 if after==1 then return false,"Continuous View ist weiterhin EIN ["..tostring(txt).."]" end
 return true,"Continuous View AUS ["..tostring(txt).."]"
end

local function count_visible_tracks(ed)
 local tracks={}
 if type(reaper.MIDIEditor_EnumTakes)~="function" then return nil end
 local i=0
 while true do
  local tk=reaper.MIDIEditor_EnumTakes(ed,i,false)
  if not tk then break end
  if reaper.ValidatePtr2(0,tk,"MediaItem_Take*") and reaper.TakeIsMIDI(tk) then
   local item=reaper.GetMediaItemTake_Item(tk)
   local tr=item and reaper.GetMediaItem_Track(item)
   if tr then tracks[tostring(tr)]=true end
  end
  i=i+1
 end
 local n=0
 for _ in pairs(tracks) do n=n+1 end
 return n
end

local function enlarge_notation_vertically(ed)
 local cmd=midi_action_by_name("View: Zoom in vertically") or 40111
 if not cmd then return false,"Vertikale Zoom-Aktion nicht gefunden." end
 -- Drei Schritte waren bereits in v0.1.6 der bewährte REAPER-native Wert.
 -- Anders als damals wird KEIN "Zoom to content" mehr davor ausgeführt:
 -- die horizontale Seitenskalierung bleibt dadurch unangetastet.
 for _=1,3 do reaper.MIDIEditor_OnCommand(ed,cmd) end
 return true,"vertikal ×3"
end

local function apply_readable_scale(ed)
 local first_qn,last_qn,count=selected_note_stats()
 if not first_qn or count==0 then return false,"keine markierten Noten" end

 local first_measure=reaper.TimeMap_QNToMeasures(0,first_qn)
 local last_measure=reaper.TimeMap_QNToMeasures(0,last_qn)
 local measures=math.max(1,last_measure-first_measure+1)
 local density=count/measures

 -- Bewährte adaptive Skalierung aus v0.1.10 wiederhergestellt.
 -- Dichte Musik bekommt deutlich mehr horizontalen Raum.
 local px_per_qn=80
 if density>=28 then px_per_qn=120
 elseif density>=18 then px_per_qn=105
 elseif density>=10 then px_per_qn=90 end

 local unit=reaper.MIDIEditor_GetSetting_int(ed,"timebase_unit")
 local px_per_unit=px_per_qn
 if unit==0 then
  local bpm=reaper.Master_GetTempo()
  px_per_unit=px_per_qn*(bpm/60.0)
 end

 local setting=math.floor(px_per_unit*1024+0.5)
 local ok=reaper.MIDIEditor_SetSetting_int(ed,"pixels_per_timebase_unit",setting)
 if not ok then return false,"REAPER hat pixels_per_timebase_unit nicht übernommen" end

 local actual=reaper.MIDIEditor_GetSetting_int(ed,"pixels_per_timebase_unit")
 return true,string.format("%.0f px/Viertelnote · %.1f markierte Noten/Takt · REAPER-Wert %d",px_per_qn,density,actual or -1)
end

local function selected_track_profile()
 local names={}
 local pitches={}
 for _,tk in ipairs(selected_takes and selected_takes() or {}) do
  local item=reaper.GetMediaItemTake_Item(tk)
  local tr=item and reaper.GetMediaItem_Track(item)
  local _,tn=tr and reaper.GetTrackName(tr) or false,""
  names[#names+1]=string.lower(tostring(tn or ""))
  local i=-1
  while true do
   i=reaper.MIDI_EnumSelNotes(tk,i); if i==-1 then break end
   local ok,_,mut,_,_,_,p=reaper.MIDI_GetNote(tk,i)
   if ok and not mut then pitches[#pitches+1]=p end
  end
 end
 local name=table.concat(names," ")
 if name:find("violin",1,true) or name:find("violine",1,true) or name:find("geige",1,true) then return "treble","Violine" end
 if name:find("viola",1,true) or name:find("bratsche",1,true) then return "alto","Viola" end
 if name:find("cello",1,true) or name:find("violoncello",1,true) then return "bass","Cello" end
 if name:find("double bass",1,true) or name:find("kontrabass",1,true) then return "bass","Kontrabass" end
 if name:find("piano",1,true) or name:find("klavier",1,true) then return "grand","Klavier" end
 if #pitches>0 then
  local lo,hi,sum=127,0,0
  for _,p in ipairs(pitches) do lo=math.min(lo,p); hi=math.max(hi,p); sum=sum+p end
  local avg=sum/#pitches
  if hi-lo>30 then return "grand","großer Tonumfang" end
  if avg>=62 then return "treble","hohe Einzelstimme" end
  if avg<=55 then return "bass","tiefe Einzelstimme" end
 end
 return "treble","Einzelstimme"
end

local CLEF_SCORE_VALUE={
 treble=1,
 bass=2,
 alto=3,
 tenor=4,
 ["treble-8"]=5,
 ["treble+8"]=6,
 ["treble+15"]=7,
 ["bass-8"]=8,
 ["bass-15"]=9,
 percussion=10,
 ["percussion-oneline"]=11,
 chart=12
}

local function active_midi_track()
 local ed=active_editor()
 if not ed then return nil end
 local tk=reaper.MIDIEditor_GetTake(ed)
 if not tk or not reaper.TakeIsMIDI(tk) then return nil end
 local item=reaper.GetMediaItemTake_Item(tk)
 return item and reaper.GetMediaItem_Track(item) or nil
end

local function set_default_clef_chunk(profile)
 if profile=="grand" then
  return false,"Treble+bass ist ein Sonderfall und wird nicht über die numerische SCORE-Reihe gesetzt."
 end
 local value=CLEF_SCORE_VALUE[profile]
 if value==nil then return false,"Unbekannter Notenschlüssel: "..tostring(profile) end

 local tr=active_midi_track()
 if not tr then return false,"Aktiver MIDI-Track konnte nicht ermittelt werden." end

 local ok,chunk=reaper.GetTrackStateChunk(tr,"",false)
 if not ok or not chunk then return false,"Track-State konnte nicht gelesen werden." end

 local newline="SCORE 0 "..tostring(value).." 0 0"
 local changed=0
 chunk,changed=chunk:gsub("SCORE%s+[^\r\n]+",newline,1)
 if changed==0 then
  local inserted=false
  chunk,changed=chunk:gsub("(\nVU%s+[^\r\n]+)", "%1\n"..newline,1)
  inserted=changed>0
  if not inserted then return false,"Keine geeignete Stelle für die SCORE-Zeile gefunden." end
 end

 local set_ok=reaper.SetTrackStateChunk(tr,chunk,false)
 if not set_ok then return false,"REAPER hat den Track-State nicht übernommen." end
 reaper.UpdateArrange()
 return true,newline
end

local function cleanup_notation()
 local ed=active_editor()
 if not ed then
  status="Keine Verbindung zum MIDI-/Notationseditor. Notation Studio bitte direkt aus dem geöffneten MIDI-Editor starten."
  return
 end

 local done={}
 local missing={}

 local function execute_found(label,variants,toggle_on)
  local cmd,txt=find_action_variants(variants)
  if not cmd then missing[#missing+1]=label; return false end
  if toggle_on then
   local st=reaper.GetToggleCommandStateEx(32060,cmd)
   if st~=1 then reaper.MIDIEditor_OnCommand(ed,cmd) end
  else
   reaper.MIDIEditor_OnCommand(ed,cmd)
  end
  done[#done+1]=label.." ["..txt.."]"
  return true
 end

 local function execute_exact(label,name)
  local cmd=midi_action_by_name(name)
  if not cmd then missing[#missing+1]=label.." ["..name.."]"; return false end
  reaper.MIDIEditor_OnCommand(ed,cmd)
  done[#done+1]=label.." ["..name.."]"
  return true
 end

 execute_found("proportionale Abstände",{
   {"notation","proportional"},
   {"proportional","spacing"}
 },true)

 execute_exact(
  "Anzeigequantisierung 1/16",
  "Notation: Set display quantization to 1/16 (default)"
 )

 execute_exact(
  "Mindestnotenlänge 1/16",
  "Notation: Set minimum display quantization note length to 1/16"
 )

 local profile,instrument=selected_track_profile()

 -- Für Solo-Streicher sind MIDI-Überlappungen meist Legato/Performance-Daten
 -- und sollen nicht automatisch als zusätzliche Notationsstimmen erscheinen.
 local voice_cmd,voice_txt=find_action_variants({
   {"notation","voice","overlapping"},
   {"notation","stimm"}
 })
 if voice_cmd then
  local want_voice=(profile=="grand")
  local vst=reaper.GetToggleCommandStateEx(32060,voice_cmd)
  if vst~=-1 and (vst==1)~=want_voice then reaper.MIDIEditor_OnCommand(ed,voice_cmd) end
  done[#done+1]="automatische Stimmenzuordnung "..(want_voice and "EIN" or "AUS").." ["..tostring(voice_txt).."]"
 else
  missing[#missing+1]="automatische Stimmenzuordnung"
 end
 local clef_ok,clef_info=set_default_clef_chunk(profile)
 if clef_ok then
  done[#done+1]="Notensystem: "..instrument.." → "..profile.." ["..tostring(clef_info).."]"
 elseif profile=="grand" then
  done[#done+1]="Notensystem: "..instrument.." → Treble+bass unverändert"
 else
  missing[#missing+1]="Notensystem: "..instrument.." → "..tostring(clef_info)
 end

 local visible_tracks=count_visible_tracks(ed)
 if visible_tracks and visible_tracks>1 then
  missing[#missing+1]="Page View benötigt genau einen sichtbaren Track; aktuell sichtbar: "..tostring(visible_tracks)
 end

 local page_ok,page_info=disable_continuous_view(ed)
 if page_ok then done[#done+1]=page_info
 else missing[#missing+1]=page_info end

 local scaled,scale_info=apply_readable_scale(ed)
 if scaled then done[#done+1]="lesbare horizontale Zielskalierung ["..scale_info.."]"
 else missing[#missing+1]="Horizontale Zielskalierung: "..tostring(scale_info) end

 local vertical_ok,vertical_info=enlarge_notation_vertically(ed)
 if vertical_ok then done[#done+1]="größere Notensysteme ["..vertical_info.."]"
 else missing[#missing+1]="Vertikale Skalierung: "..tostring(vertical_info) end

 if #missing==0 then
  status="Ausgeführt:\n• "..table.concat(done,"\n• ")
 else
  status="Ausgeführt:\n• "..table.concat(done,"\n• ").."\n\nNicht gefunden:\n• "..table.concat(missing,"\n• ")
 end
end

selected_takes=function()
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
  reaper.ImGui_Text(ctx,"Native REAPER-Notation · "..tostring(nsel).." Note(n) markiert · Editor "..(active_editor() and "gebunden" or "NICHT gebunden"))
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx,"...") then reaper.ImGui_OpenPopup(ctx,"##notationstudio_menu") end
  if reaper.ImGui_BeginPopup(ctx,"##notationstudio_menu") then
   if reaper.ImGui_MenuItem(ctx,"Update") then install_update() end
   reaper.ImGui_Separator(ctx)
   reaper.ImGui_Text(ctx,"Version "..VERSION)
   reaper.ImGui_EndPopup(ctx)
  end
  if not active_editor() then reaper.ImGui_TextWrapped(ctx,"Kein MIDI-Editor gebunden – bitte Notation Studio aus dem geöffneten Notationseditor starten.") end
  reaper.ImGui_Separator(ctx)

  if reaper.ImGui_CollapsingHeader(ctx,"Lesbarkeit",reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
   reaper.ImGui_TextWrapped(ctx,"Für den mehrzeiligen Seitenumbruch darf in REAPER nur ein Track sichtbar sein.")
   if reaper.ImGui_Button(ctx,"Lesbarkeit verbessern",-1,36) then cleanup_notation() end
   if status~="" then reaper.ImGui_TextWrapped(ctx,status) end
   reaper.ImGui_TextWrapped(ctx,"Seitendarstellung mit adaptiver Skalierung. Anzeigequantisierung und Mindestnotenlänge werden beim Aufräumen über REAPERs native Notationsaktionen auf 1/16 gesetzt. Die Triolenerkennung wird nicht automatisch verändert. Für Solo-Streicher bleibt die automatische Überlappungs-Stimmenzuordnung AUS.")
   local on=select(1,spacing_state())
   if reaper.ImGui_Button(ctx,(on and "Musikalische Abstände ✓" or "Musikalische Abstände").."##spacing",-1,30) then set_musical_spacing(not on) end
   local w=select(1,reaper.ImGui_GetContentRegionAvail(ctx)); local g=6; local h=math.max(100,(w-g)/2)
   if reaper.ImGui_Button(ctx,"Breiter +",h,30) then run_action("View: Zoom in horizontally",1) end
   reaper.ImGui_SameLine(ctx,0,g)
   if reaper.ImGui_Button(ctx,"Schmaler –",h,30) then run_action("View: Zoom out horizontally",1) end
   if reaper.ImGui_Button(ctx,"Auswahl komplett einpassen",h,30) then run_action("View: Zoom to selected notes/CC",1) end
   reaper.ImGui_SameLine(ctx,0,g)
   if reaper.ImGui_Button(ctx,"Gesamten Inhalt einpassen",h,30) then run_action("View: Zoom to content",1) end
   if reaper.ImGui_Button(ctx,"Systeme größer",h,30) then run_action("View: Zoom in vertically",1) end
   reaper.ImGui_SameLine(ctx,0,g)
   if reaper.ImGui_Button(ctx,"Systeme kleiner",h,30) then run_action("View: Zoom out vertically",1) end
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
   reaper.ImGui_TextWrapped(ctx,"Default-Clef wird direkt über REAPERs Track-State-Zeile SCORE gesetzt. Solo-Streicher: Violine → Treble, Viola → Alto, Cello/Kontrabass → Bass. Treble+bass bleibt als Sonderfall unverändert.")
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
