return function(compact_music_excerpt)
local function continuation_prompt(request,items,tracks,count,at)
 return [[Komponiere die musikalische Fortsetzung des vorhandenen Werks: GENAU ]]..count..[[ NEUE Takte.
Schreibe nur diese neuen ]]..count..[[ Takte als vollständige LilyPond-Partitur mit \score { ... }.
Die App setzt sie nach dem Ende des bisher vorhandenen Werks bei Viertelposition ]]..at..[[ ein.
Du darfst vorhandene Takte nicht nochmals ausgeben. Keine MIDI-QN-Codierung.
Nutze die übergebenen Originalnoten als musikalischen Kontext und entwickle
eine wirkliche Variation mit neuer melodischer Gestalt, verändertem Rhythmus
und einer dazugehörigen eigenständigen Begleitung. Keine reine Oktavierung,
keine bloße Transposition, keine starre Viertelkette.
Für ein Klavierstück notiere rechte und linke Hand in separaten Staves.
LilyPond muss ausführbar sein; nur Quellcode, keine Erläuterung.

AUFTRAG:
]]..request.."\n\nMUSIKALISCHER KONTEXT:\n"..compact_music_excerpt(items,at)
end

-- BEGIN MODULE EXPORTS
return {continuation_prompt=continuation_prompt}
end
