local launch
local function swam_source_context()
 local valid={}; for _,it in ipairs(last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then valid=recover_last_made() end
 if #valid==0 then return nil,"Noch keine gültige von Composition Studio erzeugte Komposition für SWAM vorhanden." end
 local rows={}
 for _,item in ipairs(valid) do
  local take=reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then
   local _,name=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); name=name~="" and name or "MIDI"
   rows[#rows+1]="VOICE|"..name
   local _,nc=reaper.MIDI_CountEvts(take)
   for n=0,(nc or 0)-1 do
    local ok,_,mut,sn,en,ch,pit,vel=reaper.MIDI_GetNote(take,n)
    if ok and not mut then
     local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sn); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,en)
     local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et)
     rows[#rows+1]=string.format("N|%s|%.5f|%.5f|%d|%d|%d",name,sq,eq-sq,pit,vel,ch)
    end
   end
  end
 end
 return table.concat(rows,"\\n"),nil
end
local function swam_interpretation_prompt(source)
 return [[Du bist ausschließlich musikalischer Interpret für SWAM Solo Strings. Die Komposition ist fertig und darf nicht umkomponiert werden. Entwickle aus dem musikalischen Entwurf und den vorhandenen Noten eine ausdrucksstarke, natürlich wirkende Streicheraufführung. Denke wie ein sehr guter Geiger bzw. Cellist: Phrasierung, Bogenführung, Ansatz und Loslassen, Vibrato-Verlauf innerhalb längerer Töne, Bogendruck, Klangposition, Legato/Portamento, dynamische Übergänge und sinnvolle Bogenwechsel. Nutze Tremolo, Harmonics, Sordino oder andere Sondertechniken nur, wenn sie musikalisch aus dem Entwurf hervorgehen. Verändere keine Tonhöhen und erfinde keine neuen Noten. Denke noch NICHT in CC-Nummern oder MIDI-Codierung. Schreibe stattdessen eine konkrete Aufführungsanweisung für jede Stimme und ihre Phrasen.]].."\\n\\nFERTIGE KOMPOSITION:\\n"..tostring(last_diag.composition_music or "").."\\n\\nVORHANDENE MIDI-NOTEN:\\n"..source
end
local function swam_translation_prompt(source,performance)
 return [[Du bist ausschließlich technischer SWAM-Performance-Übersetzer. Übertrage die fertige Aufführungsanweisung in Composition-Studios CS/CSCTRL-Format. Komponiere NICHT neu. Alle vorhandenen Tonhöhen und Note-On-Zeitpunkte müssen erhalten bleiben. Notendauern dürfen nur behutsam verändert werden, wenn dies für Legato, Trennung oder Artikulation erforderlich ist. Erzeuge für jede vorhandene Stimme eine neue CS-Zeile und danach die nötigen CSCTRL-Zeilen. Verwende dieses verbindliche Profil "Composition Studio SWAM Strings v1": CC11 Expression, CC1 Vibrato Depth, CC19 Vibrato Rate, CC20 Portamento Time, CC21 Bow Pressure, CC22 Dynamic Transitions, CC23 Bow/Pizz Position, CC24 Bow Lift, CC25 Bow Start, CC26 Bow Noise, CC27 Attack Ramp Speed, CC28 Alternate Fingering, CC29 Harmonics, CC30 Tremolo, CC31 Sordino, CC32 Play Mode, CC33 Staccato Interval Time, CC34 Bowing Sensitivity. Main Volume CC7, Pan CC10, Reverb CC90 und Sustain CC64 nicht für musikalische Expression verwenden. Kontinuierliche Parameter dürfen fein abgestufte Verläufe erhalten; Ereignisparameter nur gezielt setzen. Vibrato soll bei längeren Tönen musikalisch innerhalb des Tons entstehen und sich entwickeln, nicht bloß statisch gesetzt werden. Bow Lift/Bow Start nur an sinnvollen Bogenwechseln. Verwende Sondertechniken nur, wenn die Aufführungsanweisung sie verlangt.
Format:
CS|new|-|NAME SWAM|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CSCTRL|NAME SWAM|startQN|CHANNEL|cc|CONTROLLER|VALUE
Antworte ausschließlich mit CS- und CSCTRL-Zeilen.]].."\\n\\nEXAKTE AUSGANGSNOTEN:\\n"..source.."\\n\\nFERTIGE AUFFÜHRUNGSANWEISUNG:\\n"..performance
end
local function export_swam_midi()
 if busy then return end
 local valid={}; for _,it in ipairs(swam_last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then update_status="Noch keine SWAM-Interpretation zum Exportieren."; return end
 swam_last_made=valid
 local base=work_title~="" and work_title or "Composition Studio"
 begin_save_panel("swam_midi","SWAM-MIDI exportieren",base.." – SWAM.mid","mid")
end
local function begin_swam_interpretation()
 if busy then return end
 local source,e=swam_source_context(); if not source then update_status=e; return end
 local key=get_key(); if not key then update_status="Für die SWAM-Interpretation fehlt der API-Key."; return end
 busy=true; update_status="SWAM-Interpret erstellt Aufführung …"
 launch("swam_interpretation",swam_interpretation_prompt(source),key,{swam_source=source})
end
