-- @description Notation Studio - REAPER-Notator 2.55 Pausenvergleich (NUR LESEN)
-- @author Composition Studio / A-intheCode (upstream GPL-3.0 engraver)
-- @version 0.1-test
-- SPDX-License-Identifier: GPL-3.0-only
-- This diagnostic NEVER writes MIDI notes, scores, track chunks or settings.
-- Needs the branch's unchanged vendor folder next to the tools folder.

local r=reaper
local function report(s) r.ShowMessageBox(tostring(s),"Notation Studio - GPL-Pausenvergleich",0) end
local ed=r.MIDIEditor_GetActive and r.MIDIEditor_GetActive()
local take=ed and r.MIDIEditor_GetTake(ed)
if not take or not r.TakeIsMIDI(take) then
 report("Bitte zuerst ein MIDI-Item im REAPER-MIDI-Editor oeffnen.")
 return
end

local script=(debug.getinfo(1,"S").source or ""):gsub("^@","")
local directory=script:match("^(.*[/\\])") or ""
local path=directory.."../vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua"
local f=io.open(path,"rb")
if not f then report("Original-Engraver nicht gefunden:\n"..path) return end
f:close()

-- Stub two unrelated dependencies ONLY during loading of pure functions.
local c_prev=package.loaded["constants"]
local o_prev=package.loaded["services.octave_service"]
package.loaded["constants"]={SMUFL={},COLORS={}}
package.loaded["services.octave_service"]={}
local ok,eng=pcall(dofile,path)
package.loaded["constants"]=c_prev
package.loaded["services.octave_service"]=o_prev
if not ok or type(eng)~="table" or type(eng.generate_voice_rests)~="function" then
 report("Original-Engraver nicht geladen: "..tostring(eng)) return
end

local item=r.GetMediaItemTake_Item(take)
local item_start=r.GetMediaItemInfo_Value(item,"D_POSITION")
local qn_start=r.TimeMap2_timeToQN(0,item_start)
local first=r.TimeMap_QNToMeasures(0,qn_start)
local last=first+3
if first<0 or first>2000 then
 report("Taktposition ausserhalb des begrenzten Testbereichs.") return
end

-- Direct measure-index API: TimeMap_GetMeasureInfo returns the QN start/end
-- without guessing from a project QN position. TimeMap_QNToMeasures' optional
-- start/end return values are not reliable to REQUIRE across REAPER setups.
-- Preserve the actual project meter for every bar, including meter changes.
local m={num_m=last,bpi=4,m_start_qn={},m_end_qn={},m_bpi={}}
if type(r.TimeMap_GetMeasureInfo)~="function" then
 report("REAPER bietet TimeMap_GetMeasureInfo nicht an. Keine Aenderung.") return
end
for bar=0,last do
 local ok_measure,_,s,e=pcall(r.TimeMap_GetMeasureInfo,0,bar)
 if not ok_measure or type(s)~="number" or type(e)~="number"
    or e<=s or s~=s or e~=e then
  report("Taktgrenzen konnten fuer Takt "..tostring(bar+1).." nicht gelesen werden. Keine Aenderung.")
  return
 end
 m.m_start_qn[bar],m.m_end_qn[bar],m.m_bpi[bar]=s,e,e-s
end
m.bpi=m.m_bpi[first] or 4

local _,note_count=r.MIDI_CountEvts(take)
local function hash()
 if type(r.MIDI_GetHash)=="function" then
  local success,value=r.MIDI_GetHash(take,true)
  if success then return value end
 end
 return nil
end
local original_hash=hash()

local groups={all={},upper={},lower={}}
local low=m.m_start_qn[first]
local high=m.m_end_qn[last]
for i=0,note_count-1 do
 local yes,_,muted,sp,ep,chan,pitch,vel=r.MIDI_GetNote(take,i)
 if yes and not muted then
  local start=r.MIDI_GetProjQNFromPPQPos(take,sp)
  local finish=r.MIDI_GetProjQNFromPPQPos(take,ep)
  if finish>low and start<high and finish>start then
   local note={start_qn=start,end_qn=finish,dur_qn=finish-start,chan=chan,pitch=pitch,vel=vel}
   groups.all[#groups.all+1]=note
   local part=pitch>=60 and groups.upper or groups.lower
   part[#part+1]=note
  end
 end
end
local settings={
 {label="Ohne Displayquantisierung",grid=nil},
 {label="Anzeige 1/8",grid=0.5},
 {label="Anzeige 1/16",grid=0.25},
 {label="Anzeige 1/32",grid=0.125}
}
-- Read-only source alignment trace: verify exactly which take/timeline bars
-- are being compared before drawing conclusions from the rest counts.
local take_name=""
if type(r.GetSetMediaItemTakeInfo_String)=="function" then
 local success,nm=r.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
 if success and nm then take_name=nm end
end
local track_name=""
if type(r.GetMediaItem_Track)=="function" and type(r.GetTrackName)=="function" then
 local tr=r.GetMediaItem_Track(item)
 if tr then local _,nm=r.GetTrackName(tr); track_name=nm or "" end
end
local onset_counts={}
for bar=first,last do onset_counts[bar]=0 end
local earliest=nil
for _,n in ipairs(groups.all) do
 if not earliest or n.start_qn<earliest then earliest=n.start_qn end
 for bar=first,last do
  local bs,be=m.m_start_qn[bar],m.m_end_qn[bar]
  if n.start_qn>=bs and n.start_qn<be then
   onset_counts[bar]=onset_counts[bar]+1
   break
  end
 end
end

local lines={
 "REAPER-Notator GPL v2.55 / Pausenvergleich (nur lesen)",
 "REAPER: "..tostring(r.GetAppVersion()),
 "Bereich: Takte "..(first+1).." bis "..(last+1),
 "Noten: alle="..#groups.all..", ab C4="..#groups.upper..", unter C4="..#groups.lower,
 "Geoeffneter Take: "..take_name.." | Spur: "..track_name,
 "MIDI-Noten insgesamt im Take: "..tostring(note_count),
 "Item-Start QN: "..string.format("%.3f",qn_start).." | Erste beruecksichtigte Note QN: "..(earliest and string.format("%.3f",earliest) or "keine"),
 "Takt-Anfaenge und Note-On-Anzahlen im REAPER-Take:",
 "Keine Aenderung an MIDI, Track, Notensatz oder Projekt",
 "",
 "HINWEIS: Dies ist die isolierte Pausenfunktion, KEIN fertiges Notenbild.",
 "Die Registergrenze C4 ist keine echte Stimmenzuordnung.",
 ""
}

local original_note_count=#groups.all
for bar=first,last do
 lines[#lines+1]=string.format("  Takt %d: QN %.3f - %.3f; MIDI-Notenanfaenge=%d",
   bar+1,m.m_start_qn[bar],m.m_end_qn[bar],onset_counts[bar])
end
lines[#lines+1]=""
for _,key in ipairs({"all","upper","lower"}) do
 local notes=groups[key]
 if #notes>0 then
  lines[#lines+1]="--- "..key.." ---"
  for _,cfg in ipairs(settings) do
   local good,rests=pcall(eng.generate_voice_rests,notes,last+1,m.bpi,cfg.grid,first,last,m)
   if not good then
    lines[#lines+1]=cfg.label..": FEHLER: "..tostring(rests)
   elseif type(rests)~="table" then
    lines[#lines+1]=cfg.label..": ungueltige Rueckgabe"
   else
    local total,short,full=0,0,0
    local invalid=false
    for _,rest in ipairs(rests) do
     if type(rest.dur_qn)~="number" or rest.dur_qn<0 then invalid=true; break end
     total=total+rest.dur_qn
     if rest.dur_qn<=0.25+1e-6 then short=short+1 end
     if rest.is_full_measure then full=full+1 end
    end
    lines[#lines+1]=string.format(
     "%s: %s; Pausen=%d, kurze (<=1/16)=%d, Summe=%.3f QN, Ganztaktpausen=%d",
     cfg.label,invalid and "UNGUELTIG" or "berechnet",#rests,short,total,full)
   end
  end
 end
end
local hash_after=hash()
if original_hash and hash_after then
 lines[#lines+1]=""
 lines[#lines+1]="MIDI-Hash unveraendert: "..tostring(original_hash==hash_after)
 if original_hash~=hash_after then
  lines[#lines+1]="ACHTUNG: MIDI-Hash hat sich unerwartet geaendert!"
 end
else
 lines[#lines+1]="MIDI-Hash konnte nicht verglichen werden."
end
lines[#lines+1]="Originalnoten im Analyse-Array erhalten: "..tostring(original_note_count==#groups.all)
r.ShowConsoleMsg("\n"..table.concat(lines,"\n").."\n")
report("Pausenvergleich abgeschlossen. Ergebnis in REAPER-Konsole. Keine Schreibfunktionen ausgefuehrt.")
