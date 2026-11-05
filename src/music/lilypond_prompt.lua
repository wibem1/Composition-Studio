local function lily_composition_prompt(request)
 return [[Komponiere das vollständige verlangte Musikstück als LilyPond-Partitur.
Gib ausschließlich gültigen LilyPond-Quellcode zurück. Keine Entwürfe oder Erläuterungen.
Komponiere musikalisch frei: Akkorde, Phrasierung, Stimmen, Triolen, Bindungen,
Dynamik, Artikulationen und Tempoänderungen sind erlaubt, soweit sinnvoll.
Notiere das vollständige Werk mit einem \score { ... }-Block.
Der MIDI-Block wird von der App ergänzt. Keine Markdown-Codezäune.
AUFTRAG:
]]..request
end
-- BEGIN MODULE EXPORTS
return {lily_composition_prompt=lily_composition_prompt}
