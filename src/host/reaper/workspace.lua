-- Reuse the separately installed, standalone notation shortcut through
-- REAPER's own MIDI action registry. No duplicate SCORE/zoom implementation.
-- This first integration never changes media-item selection or MIDI events.
local function open_score_workspace(mode)
 mode=mode=="pianoroll" and "pianoroll" or "notation"
 local ed=focused_or_last_notation_editor()
 if not ed then
  local count=0
  for i=0,reaper.CountSelectedMediaItems(0)-1 do
   local it=reaper.GetSelectedMediaItem(0,i)
   local tk=it and reaper.GetActiveTake(it)
   if tk and reaper.TakeIsMIDI(tk) then count=count+1 end
  end
  if count==0 then return false,"Bitte MIDI-Items im Arrangement auswählen oder den Noteneditor öffnen." end
  if not reaper.Main_OnCommand then return false,"REAPER-Aktion zum Öffnen des Noteneditors fehlt." end
  reaper.Main_OnCommand(40153,0)
  ed=focused_or_last_notation_editor()
  if not ed then return false,"MIDI-Editor wurde nicht geöffnet; REAPER-Einstellungen überprüfen." end
 end
 if not (reaper.kbd_enumerateActions and reaper.SectionFromUniqueID and reaper.MIDIEditor_OnCommand) then
  return false,"REAPER-MIDI-Aktionen sind nicht verfügbar."
 end
 local section=reaper.SectionFromUniqueID(32060)
 if not section then return false,"REAPER-MIDI-Aktionsbereich nicht verfügbar." end
 local notationMode,pianoMode,shortcut
 for i=0,19999 do
  local id,label=reaper.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=tostring(label or "")
  local lower=label:lower()
  if lower=="view: mode: musical notation" or lower=="view: mode: notation"
    or lower=="view: notation" then notationMode=id end
  if lower=="view: mode: piano roll" or lower=="view: mode: pianoroll"
    or lower=="view: piano roll" then pianoMode=id end
  if lower:find("reaper notation - 4 takte und instrumentenschluessel.lua",1,true) then
   shortcut=id
  end
 end
 if mode=="pianoroll" then
  if not pianoMode then return false,"Piano-Roll-Modus nicht als REAPER-MIDI-Aktion gefunden. Bitte im MIDI-Editor Ansicht → Modus: Piano-Roll (Alt+1) wählen." end
  if reaper.MIDIEditor_OnCommand(ed,pianoMode)==false then
   return false,"REAPER konnte nicht in den Piano-Roll-Modus wechseln."
  end
  return true,"Piano-Roll-Editor aktiviert. Markierte Noten und sichtbare Instrumentalstimmen sind für Composition Studio verfügbar."
 end
 if notationMode and reaper.MIDIEditor_OnCommand(ed,notationMode)==false then
  return false,"REAPER konnte nicht in die Notenansicht wechseln."
 end
 if not shortcut then
  return false,"Notationseditor geöffnet, aber das separate Vier-Takte-Notationsskript ist nicht in der MIDI-Aktionsliste registriert. Bitte den bisherigen Notations-Shortcut einmalig als MIDI-ReaScript laden."
 end
 if reaper.MIDIEditor_OnCommand(ed,shortcut)==false then
  return false,"Der Notations-Shortcut konnte nicht ausgeführt werden."
 end
 -- Do not alter note selection; do not force a new editor on later calls.
 return true,notationMode and "Notationsansicht vorbereitet; Notenschlüssel, Abstände und Zoom über den bestehenden Shortcut angefordert."
  or "Notations-Shortcut ausgeführt. Falls noch Piano-Roll sichtbar ist, in REAPER einmal auf Ansicht → Notation wechseln (Alt+4)."
end

