-- @description Notation Clef Probe
-- @version 0.6.0
-- @author Klangwerke
-- @about Shows only the current REAPER SCORE line of the active MIDI track.

local SCRIPT_NAME="Notation Clef Probe"

local function get_active_track()
  local ed=reaper.MIDIEditor_GetActive()
  if not ed then return nil,"Kein aktiver MIDI-Editor." end

  local tk=reaper.MIDIEditor_GetTake(ed)
  if not tk or not reaper.TakeIsMIDI(tk) then
    return nil,"Kein aktiver MIDI-Take im MIDI-Editor."
  end

  local item=reaper.GetMediaItemTake_Item(tk)
  local tr=item and reaper.GetMediaItem_Track(item) or nil
  if not tr then return nil,"Aktiver Track konnte nicht ermittelt werden." end
  return tr
end

local tr,err=get_active_track()
if not tr then
  reaper.ShowMessageBox(err,SCRIPT_NAME,0)
  return
end

local ok,chunk=reaper.GetTrackStateChunk(tr,"",false)
if not ok or not chunk then
  reaper.ShowMessageBox("Track-State konnte nicht gelesen werden.",SCRIPT_NAME,0)
  return
end

local score=chunk:match("\n(SCORE[^\r\n]*)") or chunk:match("^(SCORE[^\r\n]*)")
if not score then
  score="<keine SCORE-Zeile gefunden>"
end

local _,name=reaper.GetTrackName(tr,"")
reaper.ShowMessageBox(
  "Track: "..tostring(name or "").."\n\nAktueller Wert:\n"..score..
  "\n\nStelle in REAPER einen anderen Default clef ein und starte dieses Skript erneut.",
  SCRIPT_NAME.." v0.6.0",0
)
