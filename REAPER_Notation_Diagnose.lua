-- @description REAPER Notation: einmalige Nur-Lesen-Diagnose
-- @version 0.1.0
-- @author Klangwerke
-- No note, chunk, selection, setting or view writes. Opens the console once.
local lines={"REAPER-Notationsdiagnose 0.1.0 (nur lesen)"}
local function out(s) lines[#lines+1]=tostring(s) end
local expected={
 "View: Zoom to project loop selection",
 "Notation: Proportional (musical) note spacing",
 "View: Zoom to content",
 "View: Zoom in vertically",
}
local required={"MIDIEditor_GetActive","MIDIEditor_GetTake","TakeIsMIDI",
 "GetMediaItemTake_Item","GetMediaItem_Track","MIDI_CountEvts","MIDI_GetNote",
 "GetTrackStateChunk","GetCursorPosition","TimeMap2_timeToQN",
 "TimeMap_QNToMeasures","TimeMap2_QNToTime","GetSet_LoopTimeRange2",
 "kbd_enumerateActions","SectionFromUniqueID","GetToggleCommandStateEx"}
local function run()
 if reaper.GetAppVersion then out("REAPER: "..reaper.GetAppVersion()) end
 if reaper.GetOS then out("System: "..reaper.GetOS()) end
 if reaper.get_action_context then
  local _,_,section=reaper.get_action_context()
  out("Start-Aktionsbereich: "..tostring(section).." (32060=MIDI-Editor, 0=Hauptbereich)")
 end
 for _,name in ipairs(required) do
  if type(reaper[name])~="function" then out("FEHLENDE API: "..name) end
 end
 local editor=reaper.MIDIEditor_GetActive and reaper.MIDIEditor_GetActive()
 out("Fokussierter MIDI-Editor: "..(editor and "vorhanden" or "NICHT GEFUNDEN"))
 if editor then
  local takes={}
  if reaper.MIDIEditor_EnumTakes then
   for i=0,2047 do local take=reaper.MIDIEditor_EnumTakes(editor,i,false);if not take then break end;takes[#takes+1]=take end
  else
   out("MIDIEditor_EnumTakes fehlt; nur aktiver Take pruefbar")
   local take=reaper.MIDIEditor_GetTake(editor);if take then takes[1]=take end
  end
  out("Takes im Editor: "..#takes)
  for i,take in ipairs(takes) do
   if i>8 then out("Weitere Takes ausgelassen");break end
   if reaper.TakeIsMIDI(take) then
    local ok,n=reaper.MIDI_CountEvts(take)
    out("Take "..i..": Notenlesung="..tostring(ok)..", Noten="..tostring(n))
    local item=reaper.GetMediaItemTake_Item(take)
    local track=item and reaper.GetMediaItem_Track(item)
    if track and reaper.GetTrackStateChunk then
     local valid,chunk=reaper.GetTrackStateChunk(track,"",false)
     local scores={}
     if valid and type(chunk)=="string" then
      for line in chunk:gmatch("[^\r\n]+") do if line:match("^SCORE%s") then scores[#scores+1]=line end end
      out("  SCORE: "..(#scores>0 and table.concat(scores," / ") or "keine; VU="..tostring(chunk:find("\nVU ",1,true)~=nil)))
     else out("  Track-State nicht lesbar") end
    end
   else out("Take "..i..": kein MIDI") end
  end
  local qn=reaper.TimeMap2_timeToQN(0,reaper.GetCursorPosition())
  local measure,a,b=reaper.TimeMap_QNToMeasures(0,qn)
  out("Cursor: QN="..tostring(qn)..", Takt="..tostring(measure)..", Grenzen="..tostring(a)..".."..tostring(b))
 end
 local section=reaper.SectionFromUniqueID and reaper.SectionFromUniqueID(32060)
 if not section or not reaper.kbd_enumerateActions then out("MIDI-Aktionsliste NICHT LESBAR");return end
 local found,candidates={},{}
 for i=0,19999 do
  local id,label=reaper.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=tostring(label or "")
  for _,want in ipairs(expected) do if label==want then found[want]=id end end
  local lower=label:lower()
  if lower:find("zoom",1,true) or lower:find("proport",1,true) or lower:find("mode:",1,true)
    or lower:find("modus:",1,true) then
   if #candidates<45 then candidates[#candidates+1]=tostring(id).." | "..label end
  end
 end
 for _,label in ipairs(expected) do
  local id=found[label]
  out((id and "GEFUNDEN "..id or "FEHLT").." | "..label)
  if id and label==expected[2] and reaper.GetToggleCommandStateEx then
   out("  Toggle-Status: "..tostring(reaper.GetToggleCommandStateEx(32060,id)))
  end
 end
 out("Tatsaechliche Aktionsnamen (max. 45):")
 for _,line in ipairs(candidates) do out(line) end
 out("Keine Aktion ausgefuehrt; Noten, Schluessel, Auswahl und Ansicht unveraendert.")
end
local ok,problem=xpcall(run,debug.traceback)
if not ok then out("DIAGNOSEFEHLER: "..tostring(problem)) end
local report=table.concat(lines,"\n").."\n"
if reaper.ShowConsoleMsg then reaper.ShowConsoleMsg(report)
elseif reaper.ShowMessageBox then reaper.ShowMessageBox(report,"Notationsdiagnose",0) end
