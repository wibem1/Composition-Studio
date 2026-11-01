-- @description Notation Studio - Notator 2.55 rhythm values (READ ONLY, GPL-3.0)
-- @author Composition Studio contributors; upstream engraver (C) A-intheCode
-- @version 0.1-test
-- SPDX-License-Identifier: GPL-3.0-only
-- Requires repository folder structure: tools/ next to vendor/
-- No MIDI, track, project, notation, or audio writes.

local r=reaper
local function message(s) r.ShowMessageBox(tostring(s),"Notation Studio - Engraver-Audit",0) end
local ed=r.MIDIEditor_GetActive and r.MIDIEditor_GetActive()
local take=ed and r.MIDIEditor_GetTake(ed)
if not take or not r.TakeIsMIDI(take) then
 message("Bitte zuerst ein MIDI-Item im REAPER-MIDI-Editor oeffnen.")
 return
end

local script=(debug.getinfo(1,"S").source or ""):gsub("^@","")
local directory=script:match("^(.*[/\\])") or ""
local source=directory.."../vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua"
local f=io.open(source,"rb")
if not f then
 message("GPL-Engraver nicht gefunden:\n"..source.."\n\nBitte die Verzeichnisstruktur des GitHub-Branches beibehalten.")
 return
end
f:close()

-- Only pure duration interpretation is used. No ReaImGui rendering or octave
-- functions. The original module is not modified; its dependencies are stubbed
-- for this isolated read-only test, and previous Lua module cache is restored.
local old_c=package.loaded["constants"]
local old_o=package.loaded["services.octave_service"]
package.loaded["constants"]={SMUFL={},COLORS={}}
package.loaded["services.octave_service"]={}
local success,eng=pcall(dofile,source)
package.loaded["constants"]=old_c
package.loaded["services.octave_service"]=old_o
if not success or type(eng)~="table" or type(eng.get_nominal_rhythmic_duration)~="function" then
 message("Engraver-Laden fehlgeschlagen: "..tostring(eng))
 return
end

local item=r.GetMediaItemTake_Item(take)
local item_qn=r.TimeMap2_timeToQN(0,r.GetMediaItemInfo_Value(item,"D_POSITION"))
local first_measure=r.TimeMap_QNToMeasures(0,item_qn)
local ok,num_notes=r.MIDI_CountEvts(take)
if not ok then message("MIDI_CountEvts fehlgeschlagen.") return end

local sample={}
local counters={}
local count=0
local short=0
for i=0,num_notes-1 do
 local got,_,muted,sp,ep,_,pitch=r.MIDI_GetNote(take,i)
 if got and not muted then
  local qn_start=r.MIDI_GetProjQNFromPPQPos(take,sp)
  local qn_end=r.MIDI_GetProjQNFromPPQPos(take,ep)
  local m=r.TimeMap_QNToMeasures(0,qn_start)
  if m>=first_measure and m<first_measure+4 then
   local raw=math.max(0,qn_end-qn_start)
   local nominal=eng.get_nominal_rhythmic_duration(raw)
   counters[string.format("%.4f",nominal)]=(counters[string.format("%.4f",nominal)] or 0)+1
   count=count+1
   if raw<0.25 then short=short+1 end
   if #sample<24 then
    sample[#sample+1]=string.format("T%d Ton=%d MIDI=%.3f -> notierter Kandidat=%.4f",
      m-first_measure+1,pitch,raw,nominal)
   end
  end
 end
end
local keys={}
for k in pairs(counters) do keys[#keys+1]=k end
table.sort(keys,function(a,b)return tonumber(a)<tonumber(b)end)
local lines={
 "REAPER-Notator 2.55 / Engraver-Dauertest (nur lesen)",
 "REAPER: "..tostring(r.GetAppVersion()),
 "Ausgewertet: "..count.." MIDI-Noten (erste vier Takte)",
 "Original-MIDI-Noten kuerzer als 1/16: "..short,
 "Vorgeschlagene notierte Dauern (Viertelnote=1):"
}
for _,k in ipairs(keys) do lines[#lines+1]="  "..k.." : "..counters[k] end
lines[#lines+1]=""
lines[#lines+1]="Beispiele:"
for _,s in ipairs(sample) do lines[#lines+1]=s end
lines[#lines+1]=""
lines[#lines+1]="Nur Dauerkandidaten, keine fertige Partitur; Stimmen, Pausen und Bindungen nicht beruecksichtigt."
lines[#lines+1]="Keine MIDI- oder Projekt-Einstellungen geaendert."
r.ShowConsoleMsg("\n"..table.concat(lines,"\n").."\n")
message("Engraver-Dauertest abgeschlossen. Details in REAPER-Konsole. Keine Aenderungen.")
