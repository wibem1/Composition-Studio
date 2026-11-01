-- @description Notation Studio - GPL-Notator-Rhythmusanalyse (NUR LESEN)
-- @version 0.1-test
-- @author Notation Studio; uses REAPER-Notator v2.55 FilterNotesService, (C) A-intheCode, GPL-3.0
-- The original GPL module is vendored unchanged; see ../vendor/REAPER-Notator-2.55/LICENSE.
-- This adapter does not edit MIDI events, scores, notes, channels, track settings or project state.

local r = reaper
local function show_error(message)
  r.ShowMessageBox(tostring(message), "Notation Studio - GPL-Rhythmusanalyse", 0)
end

local ed = r.MIDIEditor_GetActive and r.MIDIEditor_GetActive()
local take = ed and r.MIDIEditor_GetTake(ed)
if not take or not r.TakeIsMIDI(take) then
  show_error("Bitte zuerst ein MIDI-Item im REAPER-MIDI-Editor oeffnen.")
  return
end

local source = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
local script_dir = source:match("^(.*[/\\])") or ""
local module_file = script_dir .. "../vendor/REAPER-Notator-2.55/modules/services/filter_notes_service.lua"
local f = io.open(module_file, "rb")
if not f then
  show_error("GPL-Modul nicht gefunden:\n" .. module_file
    .. "\n\nBitte das Repository mit seiner Verzeichnisstruktur herunterladen.")
  return
end
f:close()

-- The upstream module requires the large MIDI service for other operations.
-- For the PURE is_note_regular() check, no service functions are needed.
-- Limit the stand-in to module loading; immediately restore Lua's package cache.
local prior = package.loaded["services.midi_service"]
package.loaded["services.midi_service"] = {}
local loaded, filter = pcall(dofile, module_file)
package.loaded["services.midi_service"] = prior
if not loaded or type(filter) ~= "table" or type(filter.is_note_regular) ~= "function" then
  show_error("GPL-Modul konnte nicht geladen werden: " .. tostring(filter))
  return
end

local item = r.GetMediaItemTake_Item(take)
local item_start = r.GetMediaItemInfo_Value(item, "D_POSITION")
local item_qn = r.TimeMap2_timeToQN(0, item_start)
local first_measure = r.TimeMap_QNToMeasures(0, item_qn)
local ok, total_notes = r.MIDI_CountEvts(take)
if not ok then
  show_error("MIDI_CountEvts ist fehlgeschlagen.")
  return
end

local counts = {
  considered=0, grid16=0, grid32=0, grid32triplets=0, irregular=0
}
local examples = {}
local MAX_BARS = 4
local TOLERANCE_TICKS = 10

for i = 0, total_notes - 1 do
  local got, _, muted, start_ppq, _, _, pitch = r.MIDI_GetNote(take, i)
  if got and not muted then
    local qn = r.MIDI_GetProjQNFromPPQPos(take, start_ppq)
    local bar = r.TimeMap_QNToMeasures(0, qn)
    if bar >= first_measure and bar < first_measure + MAX_BARS then
      counts.considered = counts.considered + 1
      local reg16 = filter.is_note_regular(take, start_ppq, 0.25, TOLERANCE_TICKS, false)
      local reg32 = filter.is_note_regular(take, start_ppq, 0.125, TOLERANCE_TICKS, false)
      local reg32t = filter.is_note_regular(take, start_ppq, 0.125, TOLERANCE_TICKS, true)
      if reg16 then counts.grid16 = counts.grid16 + 1 end
      if reg32 then counts.grid32 = counts.grid32 + 1 end
      if reg32t then counts.grid32triplets = counts.grid32triplets + 1 end
      if not reg32t then
        counts.irregular = counts.irregular + 1
        if #examples < 12 then
          examples[#examples + 1] = string.format("T%d MIDI-Ton %d bei QN %.4f",
            bar - first_measure + 1, pitch, qn)
        end
      end
    end
  end
end

local lines = {
  "Notation Studio / REAPER-Notator 2.55 - Rhythmusanalyse (NUR LESEN)",
  "REAPER " .. tostring(r.GetAppVersion()),
  "Quelle: A-intheCode/ReaperNotator, GPL-3.0, Commit 069821351b5d374d80788719cf951a2e01f5cf5b",
  "Geprueft: erste 4 Takte des aktiven MIDI-Items",
  "Ausgewertete Noten: " .. counts.considered,
  "Auf 1/16 ausgerichtete Anfaenge: " .. counts.grid16,
  "Auf 1/32 ausgerichtete Anfaenge: " .. counts.grid32,
  "Auf 1/32 inkl. Triolen ausgerichtete Anfaenge: " .. counts.grid32triplets,
  "Auch mit Triolen irregulaer: " .. counts.irregular,
  "Toleranz: " .. TOLERANCE_TICKS .. " Norm-Ticks (REAPER-Notator-Pruefregel)",
  "Die Analyse prueft nur die NotenANFAENGE. Notenenden, Pausen und Stimmen folgen separat.",
  "Es wurden keine MIDI-/Notationseinstellungen geaendert.",
  "",
  "Beispiele:"
}
for _, line in ipairs(examples) do lines[#lines+1] = line end
if #examples == 0 then lines[#lines+1] = "Keine." end

r.ShowConsoleMsg("\n" .. table.concat(lines, "\n") .. "\n")
r.ShowMessageBox("Rhythmusanalyse abgeschlossen. Der Bericht steht in der REAPER-Konsole. Keine Daten wurden geaendert.",
  "Notation Studio - GPL-Rhythmusanalyse", 0)
