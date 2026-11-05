return function(editor_reference_excerpt)
-- A narrow, deterministic AI protocol for the explicitly selected notes.
-- No musical advice is interpreted as executable MIDI until fully validated.
local function notation_patch_prompt(request,items)
 local lines={
  "Du bearbeitest ausschließlich die folgenden explizit ausgewählten MIDI-Noten musikalisch.",
  "Erlaubt sind NUR Tonhöhe und Anschlagstärke. Rhythmus, Notenzahl, Notenlängen, ",
  "Kanal, Ausdrucks-/CC-Daten, andere Stimmen und alle unmarkierten Noten bleiben unverändert.",
  "Antworte mit GENAU einer Zeile pro Quellnote, ohne Markdown/Kommentare:",
  "CSNOTE|ITEM_GUID|NOTE_INDEX|PITCH_0_BIS_127|VELOCITY_1_BIS_127",
  "Übernimm jede Quellnotennummer und GUID exakt; auch unveränderte Noten vollständig aufführen.",
  "Erfinde keine Quellnoten, lass keine aus. Erhalte die musikalische Idee des Originals.",
  "AUFTRAG: "..request,
 }
 for _,it in ipairs(items or {}) do
  lines[#lines+1]="SPUR: "..tostring(it.track_name).." ITEM_GUID: "..tostring(it.guid)
  for j,ref in ipairs(it.selection_source or {}) do
   local n=it.notes and it.notes[j] or {}
   lines[#lines+1]=string.format("NOTE guid=%s index=%d pitch=%d velocity=%d kanal=%d startQN=%.6f dauerQN=%.6f",
    it.guid,ref.index,ref.pitch,ref.velocity,ref.channel,n.start_qn or 0,n.duration_qn or 0)
  end
 end
 local reference=editor_reference_excerpt(items)
 if reference~="" then lines[#lines+1]=reference end
 return table.concat(lines,"\n")
end

-- BEGIN MODULE EXPORTS
return {notation_patch_prompt=notation_patch_prompt}
end
