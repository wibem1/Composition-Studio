-- @description Notation Studio - MIDI-Rhythmusdiagnose (NUR LESEN)
-- @version 0.1-test
-- @author Notation Studio
-- Reads note onsets, endings and gaps; changes no MIDI, notation or track settings.
-- Use with a MIDI item open in the MIDI editor. Report: REAPER console.

local r = reaper
local ed = r.MIDIEditor_GetActive and r.MIDIEditor_GetActive()
if not ed then
  r.ShowMessageBox("Bitte zuerst ein MIDI-Item im MIDI-Editor oeffnen.", "Notation Studio", 0)
  return
end
local take = r.MIDIEditor_GetTake(ed)
if not take or not r.TakeIsMIDI(take) then
  r.ShowMessageBox("Der aktive Take enthaelt keine MIDI-Daten.", "Notation Studio", 0)
  return
end
local item = r.GetMediaItemTake_Item(take)
local track = item and r.GetMediaItem_Track(item)
local track_name = ""
if track then
  local _, name = r.GetTrackName(track)
  track_name = name or ""
end
local ok, note_count = r.MIDI_CountEvts(take)
if not ok or note_count == 0 then
  r.ShowMessageBox("Keine MIDI-Noten im aktiven Take.", "Notation Studio", 0)
  return
end

local item_qn = r.TimeMap2_timeToQN(0, r.GetMediaItemInfo_Value(item, "D_POSITION"))
local first_measure = r.TimeMap_QNToMeasures(0, item_qn)
local MAX_BARS = 4
local MIN_STEP = 0.25 -- 1/16 note in quarter-note units
local OFF_GRID = 0.04
local all = {}
local sampled = {}
local bars_seen = {}

for i = 0, note_count - 1 do
  local note_ok, _, muted, start_ppq, end_ppq, _, pitch, _ = r.MIDI_GetNote(take, i)
  if note_ok and not muted then
    local start_qn = r.TimeMap2_timeToQN(0, r.MIDI_GetProjTimeFromPPQPos(take, start_ppq))
    local end_qn = r.TimeMap2_timeToQN(0, r.MIDI_GetProjTimeFromPPQPos(take, end_ppq))
    local bar_index, bar_start = r.TimeMap_QNToMeasures(0, start_qn)
    if bar_index >= first_measure and bar_index < first_measure + MAX_BARS then
      local length_qn = math.max(0, end_qn - start_qn)
      local onset_offset = start_qn - bar_start
      local onset_error = math.abs(onset_offset - math.floor(onset_offset / MIN_STEP + 0.5) * MIN_STEP)
      local end_bar, end_bar_start = r.TimeMap_QNToMeasures(0, end_qn)
      local end_offset = end_qn - end_bar_start
      local end_error = math.abs(end_offset - math.floor(end_offset / MIN_STEP + 0.5) * MIN_STEP)
      local entry = {
        bar = bar_index - first_measure + 1, pitch = pitch, a = start_qn, b = end_qn,
        dur = length_qn, start_error = onset_error, end_error = end_error
      }
      all[#all + 1] = entry
      bars_seen[entry.bar] = true
      if onset_error > OFF_GRID or end_error > OFF_GRID or length_qn < MIN_STEP then
        sampled[#sampled + 1] = entry
      end
    end
  end
end

table.sort(all, function(a, b)
  if a.a ~= b.a then return a.a < b.a end
  return a.pitch < b.pitch
end)

local count_onset = 0
local count_end = 0
local short_count = 0
for _, n in ipairs(all) do
  if n.start_error > OFF_GRID then count_onset = count_onset + 1 end
  if n.end_error > OFF_GRID then count_end = count_end + 1 end
  if n.dur < MIN_STEP then short_count = short_count + 1 end
end

local function gap_report(threshold)
  local sections = {}
  for _, n in ipairs(all) do
    if (threshold == "upper" and n.pitch >= 60) or (threshold == "lower" and n.pitch < 60) then
      sections[#sections + 1] = n
    end
  end
  if #sections == 0 then return "keine Noten" end
  table.sort(sections, function(a, b) return a.a < b.a end)
  local end_current = sections[1].b
  local gap_count, gap_total = 0, 0
  local examples = {}
  for i = 2, #sections do
    local n = sections[i]
    if n.a > end_current + 0.03 then
      local gap = n.a - end_current
      if gap <= 1.0 then
        gap_count = gap_count + 1
        gap_total = gap_total + gap
        if #examples < 5 then examples[#examples + 1] = string.format("%.3f", gap) end
      end
    end
    end_current = math.max(end_current, n.b)
  end
  return string.format("%d Luecken bis 1 Viertel, zusammen %.3f Viertel (Beispiele: %s)",
    gap_count, gap_total, #examples > 0 and table.concat(examples, ", ") or "keine")
end

local out = {
  "Notation Studio - MIDI-Rhythmusdiagnose (NUR LESEN)",
  "REAPER: " .. tostring(r.GetAppVersion and r.GetAppVersion() or "unbekannt"),
  "Track: " .. tostring(track_name or "") .. "; aktive MIDI-Noten insgesamt: " .. tostring(note_count),
  "Bereich: erste 4 Takte ab Item-Anfang (ohne stummgeschaltete Noten)",
  "Untersuchte Noten: " .. #all,
  "Mehr als 0.04 Viertel vom 1/16-Raster entfernt: Beginn " .. count_onset .. ", Ende " .. count_end,
  "MIDI-Noten kuerzer als 1/16: " .. short_count,
  "Tonbereich ab C4 (MIDI >=60): " .. gap_report("upper"),
  "Tonbereich unter C4 (MIDI <60): " .. gap_report("lower"),
  "Hinweis: Die Trennung bei C4 ist nur eine statistische Hilfe, keine zuverlaessige Stimmzuordnung.",
  "Hinweis: Notierte Pausen koennen auch von Stimmenzuordnung und Darstellungseinstellungen kommen.",
  "",
  "Erste 30 auffaellige Noten (Takt, Tonhoehe als MIDI-Zahl, Dauer in Vierteln, Rasterabweichungen):"
}
table.sort(sampled, function(a, b) return a.a < b.a end)
for i = 1, math.min(30, #sampled) do
  local n = sampled[i]
  out[#out + 1] = string.format("T%d  Ton=%d  Dauer=%.3f  StartAbw=%.3f  EndeAbw=%.3f",
    n.bar, n.pitch, n.dur, n.start_error, n.end_error)
end
if #sampled == 0 then out[#out + 1] = "Keine Auffaelligkeiten nach den genannten Schwellenwerten." end
out[#out + 1] = ""
out[#out + 1] = "Es wurden weder MIDI-Daten noch REAPER-Einstellungen veraendert."
r.ShowConsoleMsg("\n" .. table.concat(out, "\n") .. "\n")
r.ShowMessageBox("Rhythmusdiagnose abgeschlossen. Der Bericht steht in der REAPER-Konsole. Keine Aenderungen vorgenommen.", "Notation Studio", 0)
