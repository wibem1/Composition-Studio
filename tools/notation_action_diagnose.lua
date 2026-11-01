-- @description Notation Studio - MIDI-Notationsaktionen diagnostizieren (NUR LESEN)
-- @author Notation Studio
-- @version 0.1
-- Keine Aenderungen an Projekt, MIDI, Notenschluesseln oder Einstellungen.
--
-- REAPER: MIDI-Editor oeffnen, Skript aus der Aktionsliste starten.
-- Vollstaendiges Ergebnis: View > Show console output.

local function report(message)
  if type(reaper.ShowMessageBox)=="function" then
    reaper.ShowMessageBox(message, "Notation Studio - Aktionsdiagnose", 0)
  end
end

if type(reaper.MIDIEditor_GetActive)~="function" or not reaper.MIDIEditor_GetActive() then
  report("Bitte zuerst ein MIDI-Item im REAPER-MIDI-Editor oeffnen.")
  return
end

if type(reaper.SectionFromUniqueID)~="function"
  or type(reaper.kbd_enumerateActions)~="function" then
  report("Dieser REAPER-Version fehlt SectionFromUniqueID oder kbd_enumerateActions.")
  return
end

local section=reaper.SectionFromUniqueID(32060)
if not section then
  report("MIDI-Editor-Aktionsbereich 32060 ist nicht verfuegbar.")
  return
end

local targets={
  "Notation: Set display quantization to 1/16 (default)",
  "Notation: Set minimum display quantization note length to 1/64 (default)",
  "Notation: Set minimum display quantization note length to 1/16",
  "Notation: Proportional (musical) note spacing"
}
local found={}
local relevant={}
local count=0
local reason="Ende der Aktionsliste"
local MAX_ACTIONS=20000

for index=0,MAX_ACTIONS-1 do
  local ok,cmd,name=pcall(reaper.kbd_enumerateActions,section,index)
  if not ok then
    reason="Fehler bei Index "..index..": "..tostring(cmd)
    break
  end
  if type(cmd)~="number" or cmd<=0 then
    reason="Keine Aktion bei Index "..index.." (Rueckgabe: "..tostring(cmd)..")"
    break
  end
  count=count+1
  name=tostring(name or "")
  for _,target in ipairs(targets) do
    if name==target then found[target]=cmd end
  end
  local lower=name:lower()
  if lower:find("notation",1,true)
    and (lower:find("quant",1,true) or lower:find("spacing",1,true)) then
    relevant[#relevant+1]=tostring(cmd).." | "..name
  end
  if index==MAX_ACTIONS-1 then reason="Abbruch am Sicherheitslimit" end
end

local lines={
  "Notation Studio - MIDI-Aktionsdiagnose (read-only)",
  "REAPER: "..tostring(reaper.GetAppVersion and reaper.GetAppVersion() or "unbekannt"),
  "Eintraege: "..count,
  "Abbruchgrund: "..reason,
  "",
  "Gesuchte Aktionen:"
}
for _,target in ipairs(targets) do
  lines[#lines+1]=(found[target] and ("OK ID "..found[target]) or "NICHT GEFUNDEN").." | "..target
end
lines[#lines+1]=""
lines[#lines+1]="Alle passenden Notationsaktionen:"
for _,entry in ipairs(relevant) do lines[#lines+1]=entry end
if #relevant==0 then lines[#lines+1]="Keine Treffer." end

local output=table.concat(lines,"\n").."\n"
if type(reaper.ShowConsoleMsg)=="function" then
  reaper.ShowConsoleMsg("\n"..output)
end

local matched=0
for _,target in ipairs(targets) do
  if found[target] then matched=matched+1 end
end
report(string.format(
  "Aktionen gelesen: %d\nTreffer: %d/%d\n\n%s\n\nDetails stehen in der REAPER-Konsole.\nEs wurden keinerlei Einstellungen geaendert.",
  count, matched, #targets, reason
))
