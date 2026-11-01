-- @description Notation Studio - Quantisierung 1/16 testen (REAPER 7.83)
-- @author Notation Studio
-- @version 0.1-test
-- Tests native REAPER display-quantization actions, without changing MIDI note timing.
-- Applies display 1/16 and minimum display note length 1/64, then opens native dialog.

local ED_SECTION=32060
local COMMANDS={
 {id=41030, name="Notation: Set display quantization to 1/16 (default)"},
 {id=41212, name="Notation: Set minimum display quantization note length to 1/64 (default)"},
 {id=41745, name="Notation: Adjust display quantization..."}
}

local function error_box(message)
 reaper.ShowMessageBox(message,"Notation Studio - Quantisierungstest",0)
end

local ed=reaper.MIDIEditor_GetActive()
if not ed then
 error_box("Bitte zuerst ein MIDI-Item im MIDI-Editor oeffnen.")
 return
end

local section=reaper.SectionFromUniqueID(ED_SECTION)
if not section or type(reaper.kbd_enumerateActions)~="function" then
 error_box("MIDI-Aktionsliste ist nicht verfuegbar.")
 return
end

local names={}
for i=0,19999 do
 local cmd,name=reaper.kbd_enumerateActions(section,i)
 if not cmd or cmd==0 then break end
 names[cmd]=tostring(name or "")
end
for _,action in ipairs(COMMANDS) do
 if names[action.id]~=action.name then
  error_box("Abbruch: Aktions-ID "..action.id.." ist nicht verifiziert.\nGefunden: "..tostring(names[action.id]))
  return
 end
end

reaper.ShowConsoleMsg("\nNotation Studio: REAPER "..tostring(reaper.GetAppVersion()).."\n")
for i=1,2 do
 local action=COMMANDS[i]
 local ok,err=pcall(reaper.MIDIEditor_OnCommand,ed,action.id)
 if not ok then
  error_box("Aufruf "..action.id.." fehlgeschlagen: "..tostring(err))
  return
 end
 reaper.ShowConsoleMsg("Gesendet: "..action.id.." - "..action.name.."\n")
end
reaper.ShowConsoleMsg("Kontrolle: Im REAPER-Dialog Anzeige 1/16 und Mindestlaenge 1/64 ablesen.\n")
reaper.MIDIEditor_OnCommand(ed,41745)
