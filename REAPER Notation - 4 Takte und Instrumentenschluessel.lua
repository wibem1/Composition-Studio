-- @description REAPER Notation - 4 Takte und Instrumentenschluessel
-- @author Klangwerke
-- @about One shortcut: fit four measures, turn on proportional musical note spacing, set clefs on visible MIDI tracks. No dialogs, no quantization, no MIDI note changes. Experimental SCORE chunk format; use on a backed-up project.
-- No ReaImGui, SWS, ReaPack, AI, or additional setup required after loading into MIDI Editor actions.

local PROJECT = 0
local BARS = 4

-- In the earlier REAL notation test, SCORE ... 4 produced an alto clef,
-- not a treble clef. The previous script copied the incorrect mapping.
-- This table follows the native "Default clef" menu order (1=grand,
-- 2=treble, 3=bass, 4=alto). The result is still subject to a visual
-- check in the installed REAPER version; do not treat a mock as proof.
-- Unknown instruments are deliberately left untouched.
local SCORE_CLEF = {
  grand = 1,    -- Treble + bass (piano)
  treble = 2,   -- Violin, flute
  bass = 3,     -- Cello, bassoon
  alto = 4,     -- Viola
}

local function note(msg)
  if reaper.ShowConsoleMsg then
    reaper.ShowConsoleMsg("[REAPER Notation] " .. tostring(msg) .. "\n")
  end
end

local function identify(name)
  local n = tostring(name or ""):lower()
  -- Long/specific terms first; avoid "violin" matching "violoncello".
  if n:find("violoncello", 1, true) or n:find("cello", 1, true)
    or n:find("bassoon", 1, true) or n:find("fagott", 1, true)
    or n:find("kontrabass", 1, true) or n:find("double bass", 1, true)
    or n:find("contrabass", 1, true) then
    return "bass"
  elseif n:find("viola", 1, true) or n:find("bratsche", 1, true) then
    return "alto"
  elseif n:find("violin", 1, true) or n:find("geige", 1, true)
    or n:find("flute", 1, true) or n:find("flöte", 1, true) then
    return "treble"
  elseif n:find("piano", 1, true) or n:find("klavier", 1, true)
    or n:find("grand piano", 1, true) then
    return "grand"
  end
  return nil
end

local function visible_tracks(editor)
  local tracks, seen, takes = {}, {}, {}
  local function add(take)
    if not take or not reaper.TakeIsMIDI(take) then return end
    if reaper.ValidatePtr2 and not reaper.ValidatePtr2(PROJECT, take, "MediaItem_Take*") then return end
    local item = reaper.GetMediaItemTake_Item(take)
    local track = item and reaper.GetMediaItem_Track(item)
    if track and not seen[tostring(track)] then
      seen[tostring(track)] = true
      tracks[#tracks+1] = track
    end
    takes[#takes+1] = take
  end
  if reaper.MIDIEditor_EnumTakes then
    for i=0,2047 do
      local take = reaper.MIDIEditor_EnumTakes(editor,i,false)
      if not take then break end
      add(take)
    end
  end
  if #tracks==0 then add(reaper.MIDIEditor_GetTake(editor)) end
  return tracks,takes
end

local function edit_clef(track, code)
  local ok, original = reaper.GetTrackStateChunk(track,"",false)
  if not ok or not original then return false,"Track-Chunk nicht lesbar" end

  local target = "SCORE 0 " .. tostring(code) .. " 0 0"
  -- Work with a single, simple top-level SCORE line only; preserve all other chunk content.
  local found, count = nil,0
  for line in original:gmatch("[^\r\n]+") do
    if line:match("^SCORE%s") then
      count = count+1
      found = line
    end
  end
  if count>1 then return false,"mehrere SCORE-Zeilen; übersprungen" end

  local changed
  if count==1 then
    local a,b,c,d = found:match("^SCORE%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*$")
    if not a or a~="0" or c~="0" or d~="0" then
      return false,"unbekanntes SCORE-Format; übersprungen"
    end
    if tonumber(b)==code then return false,nil end
    -- Replace the exact line, not a substring; preserve other settings and line endings.
    local escaped = found:gsub("([^%w])","%%%1")
    changed = original:gsub("("..escaped..")",function() return target end,1)
  else
    -- New MIDI tracks may not yet have a SCORE setting. Add it in the top-level
    -- track header; never inside nested item or FX chunks.
    local start,finish = original:find("^<TRACK[^\r\n]*\r?\n")
    if not start then return false,"TRACK-Header nicht erkannt" end
    local newline = original:find("\r\n",1,true) and "\r\n" or "\n"
    changed = original:sub(1,finish)..target..newline..original:sub(finish+1)
  end

  if changed==original then return false,nil end
  if not reaper.SetTrackStateChunk(track,changed,false) then
    return false,"REAPER hat Track-Chunk abgewiesen"
  end
  -- A successful setter does not prove that REAPER accepted the SCORE value.
  -- Read back the exact canonical line and report the result in the console.
  local read_ok,now = reaper.GetTrackStateChunk(track,"",false)
  local seen = false
  if read_ok and type(now)=="string" then
    for line in now:gmatch("[^\r\n]+") do
      if line==target then seen=true; break end
    end
  end
  if not seen then return false,"SCORE-Wert nach SetTrackStateChunk nicht gespeichert" end
  return true,nil
end

local function four_bar_window()
  local cursor = reaper.GetCursorPosition()
  local qn = reaper.TimeMap2_timeToQN(PROJECT,cursor)
  local _,startQN,endQN = reaper.TimeMap_QNToMeasures(PROJECT,qn)
  if not (startQN and endQN and endQN>startQN) then
    return nil,nil,"Taktgrenzen nicht ermittelbar"
  end
  -- Iterate exact measure boundaries: also works across time signature changes.
  local last = endQN
  for _=2,BARS do
    local _,nextStart,nextEnd = reaper.TimeMap_QNToMeasures(PROJECT,last+1e-7)
    if not nextStart or not nextEnd or nextEnd<=last then
      return nil,nil,"Folgetakt nicht ermittelbar"
    end
    last=nextEnd
  end
  return reaper.TimeMap2_QNToTime(PROJECT,startQN),
         reaper.TimeMap2_QNToTime(PROJECT,last),nil
end

local function midi_action(editor, label)
  if not reaper.kbd_enumerateActions or not reaper.SectionFromUniqueID then return false end
  local section = reaper.SectionFromUniqueID(32060)
  if not section then return false end
  for i=0,19999 do
    local command,text = reaper.kbd_enumerateActions(section,i)
    if not command or command==0 then break end
    if text==label then
      return reaper.MIDIEditor_OnCommand(editor,command) ~= false
    end
  end
  return false
end

-- A toggle must only be sent if proportional note spacing is currently OFF.
-- REAPER exposes the state in the MIDI Editor action section (32060).
-- Fail closed when the action or its toggle state cannot be identified.
local function enable_proportional_spacing(editor)
  if type(reaper.kbd_enumerateActions)~="function" or
     type(reaper.SectionFromUniqueID)~="function" or
     type(reaper.GetToggleCommandStateEx)~="function" then
    return false,"MIDI-Aktionen oder Toggle-Status nicht verfügbar"
  end
  local section = reaper.SectionFromUniqueID(32060)
  if not section then return false,"MIDI-Editor-Aktionsbereich fehlt" end
  local command
  for i=0,19999 do
    local id,label = reaper.kbd_enumerateActions(section,i)
    if not id or id==0 then break end
    if label=="Notation: Proportional (musical) note spacing" then
      command=id
      break
    end
  end
  if not command then return false,"Aktion für proportionale Notenabstände nicht gefunden" end
  local state = reaper.GetToggleCommandStateEx(32060,command)
  if state==1 then return true,"bereits aktiv" end
  if state~=0 then return false,"Zustand unbekannt; Abstände unverändert" end
  reaper.MIDIEditor_OnCommand(editor,command)
  if reaper.GetToggleCommandStateEx(32060,command)~=1 then
    return false,"Aktivierung nicht bestätigt; REAPER-Einstellung prüfen"
  end
  return true,"aktiviert"
end

local function zoom_four_bars(editor)
  local startTime,endTime,problem = four_bar_window()
  if not startTime then return false,problem end
  -- Preserve both selections even when REAPER is configured to link them.
  local timeStart,timeEnd = reaper.GetSet_LoopTimeRange2(PROJECT,false,false,0,0,false)
  local loopStart,loopEnd = reaper.GetSet_LoopTimeRange2(PROJECT,false,true,0,0,false)
  if not (timeStart and timeEnd and loopStart and loopEnd) then
    return false,"Vorhandene Zeit-/Loop-Auswahl nicht lesbar"
  end
  local ok,done = pcall(function()
    reaper.GetSet_LoopTimeRange2(PROJECT,true,true,startTime,endTime,false)
    return midi_action(editor,"View: Zoom to project loop selection")
  end)
  -- Always restore loop and time selection. No persistent project-time edits.
  reaper.GetSet_LoopTimeRange2(PROJECT,true,true,loopStart,loopEnd,false)
  reaper.GetSet_LoopTimeRange2(PROJECT,true,false,timeStart,timeEnd,false)
  if not ok then return false,tostring(done) end
  if not done then return false,"MIDI-Aktion 'View: Zoom to project loop selection' nicht verfügbar" end
  return true,nil
end

local function main()
  local editor = reaper.MIDIEditor_GetActive()
  if not editor then note("Kein aktiver MIDI-Editor. Shortcut im MIDI-Editor zuweisen.");return end
  local tracks,takes = visible_tracks(editor)
  if #tracks==0 then note("Keine sichtbaren MIDI-Tracks gefunden.");return end

  local plans = {}
  for _,track in ipairs(tracks) do
    local _,name = reaper.GetTrackName(track)
    local clef = identify(name)
    if clef and SCORE_CLEF[clef] then
      plans[#plans+1]={track=track,clef=clef,name=name}
    else
      note("Unbekanntes Instrument übersprungen: "..tostring(name))
    end
  end

  local changed=0
  if #plans>0 then
    reaper.Undo_BeginBlock2(PROJECT)
    for _,plan in ipairs(plans) do
      local success,problem = edit_clef(plan.track,SCORE_CLEF[plan.clef])
      if success then
        changed=changed+1
        note(plan.name..": "..plan.clef.." → SCORE 0 "..SCORE_CLEF[plan.clef].." 0 0 gespeichert")
      end
      if problem then note(plan.name..": "..problem) end
    end
    reaper.Undo_EndBlock2(PROJECT,"REAPER-Notation: sichtbare Instrumentenschlüssel",-1)
  end

  if changed>0 then
    reaper.UpdateArrange()
    if reaper.MIDI_RefreshEditors then
      for _,take in ipairs(takes) do reaper.MIDI_RefreshEditors(take) end
    end
  end
  local spacingOk,spacingInfo=enable_proportional_spacing(editor)
  if not spacingOk then note("Proportionale Abstände: "..tostring(spacingInfo)) end
  local zoomed,zoomErr=zoom_four_bars(editor)
  if not zoomed then note("Vier-Takte-Zoom: "..tostring(zoomErr)) end
  note(string.format("Abgeschlossen: %d sichtbare Tracks, %d geänderte Schlüssel, Vier-Takte-Zoom %s, proportionale Abstände %s.",
    #tracks,changed,zoomed and "ausgeführt" or "nicht verfügbar",
    spacingOk and spacingInfo or "unverändert (Status prüfen)"))
end

local ok,problem=pcall(main)
if not ok then note("Skriptfehler: "..tostring(problem)) end
