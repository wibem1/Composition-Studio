-- @description REAPER Notation - 4 Takte und Instrumentenschluessel
-- @author Klangwerke
-- @about One shortcut: show four measures, enable proportional spacing and choose clefs by MIDI-note register. No track-name inference, dialogs, quantization or MIDI note changes. Experimental SCORE chunk format: test on a backup project.
-- No ReaImGui, SWS, ReaPack, AI, or additional setup required after loading into MIDI Editor actions.

local PROJECT = 0
local BARS = 4

-- REAPER's SCORE track-chunk format is undocumented. Values follow the
-- observed default-clef menu order (1=grand,2=treble,3=bass,4=alto,5=tenor).
-- Keep this mapping isolated: a successful chunk write does NOT prove the
-- notation renderer changed in an open REAPER editor.
local SCORE_CLEF = {
  grand = 1,    -- Two staves only for confirmed overlapping registers
  treble = 2,
  bass = 3,
  alto = 4,
  tenor = 5,
}

local function note(msg)
  if reaper.ShowConsoleMsg then
    reaper.ShowConsoleMsg("[REAPER Notation] " .. tostring(msg) .. "\n")
  end
end

-- Determine a staff from actual MIDI pitches, never track/item names.
-- Candidate single staves use diatonic distances to staff boundaries.
-- Four-pitched-note minimum prevents arbitrary key choices from tiny fragments.
local NATURAL_STEP = {[0]=0,0,1,1,2,3,3,4,4,5,5,6}
local STAVES = {
  treble={lo=30,hi=38}, -- E4 .. F5
  alto  ={lo=24,hi=32}, -- F3 .. G4
  tenor ={lo=22,hi=30}, -- D3 .. E4
  bass  ={lo=18,hi=26}, -- G2 .. A3
}
local CHOICES={"treble","alto","tenor","bass"}

local function diatonic_step(pitch)
  local octave=math.floor(pitch/12)-1
  local pitchclass=pitch%12
  return octave*7+NATURAL_STEP[pitchclass]
end

local function staff_cost(pitch,clef)
  local bounds=STAVES[clef]
  local d=diatonic_step(pitch)
  local out=math.max(0,bounds.lo-d,d-bounds.hi)
  -- Ledger lines are much more expensive than placement away from center.
  return (out*out*1.8+out*2)+0.06*math.abs(d-(bounds.lo+bounds.hi)/2)
end

local function note_analysis(takes)
  if type(reaper.MIDI_CountEvts)~="function" or type(reaper.MIDI_GetNote)~="function" then
    return nil,"MIDI-Notenlesefunktionen fehlen"
  end
  local notes,sums={},{}
  for _,clef in ipairs(CHOICES) do sums[clef]=0 end
  local low,high={},{}
  for _,take in ipairs(takes or {}) do
    local ok,count=reaper.MIDI_CountEvts(take)
    if ok and count and count>0 then
      -- Stable sampling when a track has very many notes.
      local step=math.max(1,math.ceil(count/4096))
      for i=0,count-1,step do
        local valid,_,muted,startPPQ,endPPQ,_,pitch=reaper.MIDI_GetNote(take,i)
        if valid and not muted and type(pitch)=="number" and pitch>=0 and pitch<=127 then
          notes[#notes+1]=pitch
          for _,clef in ipairs(CHOICES) do
            sums[clef]=sums[clef]+staff_cost(pitch,clef)
          end
          -- For grand staff, demand actual overlapping low/high voices
          -- within the SAME take, not just a wide melodic range.
          if startPPQ and endPPQ and endPPQ>startPPQ then
            if pitch<=55 then low[#low+1]={take=take,a=startPPQ,b=endPPQ} end
            if pitch>=68 then high[#high+1]={take=take,a=startPPQ,b=endPPQ} end
          end
        end
      end
    end
  end
  if #notes<4 then return nil,"weniger als vier auswertbare MIDI-Noten" end
  local chosen,best,second=nil,math.huge,math.huge
  for _,clef in ipairs(CHOICES) do
    local score=sums[clef]/#notes
    if score<best then second=best;best=score;chosen=clef
    elseif score<second then second=score end
  end
  -- Score only the clef quality, not the track name or MIDI program.
  local lowFraction=#low/#notes
  local highFraction=#high/#notes
  if #low>=3 and #high>=3 and lowFraction>=0.15 and highFraction>=0.15 then
    local overlaps=0
    for _,l in ipairs(low) do
      for _,h in ipairs(high) do
        if l.take==h.take and l.a<h.b and h.a<l.b then
          overlaps=overlaps+1
          if overlaps>=2 then break end
        end
      end
      if overlaps>=2 then break end
    end
    if overlaps>=2 then
      return {clef="grand",notes=#notes,score=best,margin=second-best,polyphony=true},nil
    end
  end
  return {clef=chosen,notes=#notes,score=best,margin=second-best,polyphony=false},nil
end

local function visible_tracks(editor)
  local tracks,seen,takes,byTrack={},{},{},{}
  local function add(take)
    if not take or not reaper.TakeIsMIDI(take) then return end
    if reaper.ValidatePtr2 and not reaper.ValidatePtr2(PROJECT,take,"MediaItem_Take*") then return end
    local item=reaper.GetMediaItemTake_Item(take)
    local track=item and reaper.GetMediaItem_Track(item)
    if not track then return end
    local id=tostring(track)
    if not seen[id] then
      seen[id]=true
      tracks[#tracks+1]=track
      byTrack[id]={}
    end
    byTrack[id][#byTrack[id]+1]=take
    takes[#takes+1]=take
  end
  if reaper.MIDIEditor_EnumTakes then
    for i=0,2047 do
      local take=reaper.MIDIEditor_EnumTakes(editor,i,false)
      if not take then break end
      add(take)
    end
  end
  if #tracks==0 then add(reaper.MIDIEditor_GetTake(editor)) end
  return tracks,takes,byTrack
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
  local tracks,takes,byTrack = visible_tracks(editor)
  if #tracks==0 then note("Keine sichtbaren MIDI-Tracks gefunden.");return end

  local plans = {}
  for index,track in ipairs(tracks) do
    local result,reason=note_analysis(byTrack[tostring(track)])
    if result and SCORE_CLEF[result.clef] and (result.polyphony or result.margin>=0.20) then
      plans[#plans+1]={track=track,clef=result.clef,name="System "..index}
      note(string.format("System %d: %d MIDI-Noten → %s (Hilfslinienanalyse)",
        index,result.notes,result.clef))
    elseif result then
      note("System "..index..": uneindeutiger Tonumfang; bisherigen Schlüssel beibehalten")
    else
      note("System "..index..": keine automatische Schlüsselwahl – "..tostring(reason or "unbestimmt"))
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
