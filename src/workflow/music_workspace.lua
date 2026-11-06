music_workspace={memory_key="MusicMemoryV1"}
workflow_adapter.labels.song_construction="Song-Aufbau"
function music_workspace.read_memory()
 local _,raw=reaper.GetProjExtState(0,EXT_SECTION,music_workspace.memory_key)
 if not raw or raw=="" then return music_memory.empty() end
 assert(#raw<=20000,"Musikgedächtnis überschreitet die unterstützte Größe.")
 return music_memory.validate(decode_engine_json(raw))
end
function music_workspace.store_memory(value)
 music_memory.validate(value)
 local raw=workflow_adapter.encode(value)
 assert(#raw<=20000,"Musikgedächtnis ist nach Kodierung zu groß; bitte kürzere Entscheidungen verwenden.")
 reaper.SetProjExtState(0,EXT_SECTION,music_workspace.memory_key,raw)
 local _,stored=reaper.GetProjExtState(0,EXT_SECTION,music_workspace.memory_key)
 assert(stored==raw,"Musikgedächtnis konnte nicht gespeichert werden.")
end
function music_workspace.context()
 local ok,result=pcall(function() return music_memory.context(music_workspace.read_memory()) end)
 if ok then return result end
 return nil,"Musikgedächtnis nicht lesbar: "..tostring(result)..". Prüfen oder bewusst mit 'Lösche Musikgedächtnis' zurücksetzen."
end
function music_workspace.capture(request)
 local words=request_words(request)
 local explicit_notes=words:find("noten",1,true) and (words:find("markiert",1,true) or words:find("ausgewaehlt",1,true))
 local explicit_items=words:find("item",1,true) or words:find("arrangement",1,true)
 local items
 if score_request_intent(request:lower()) and not explicit_notes and not explicit_items then
  local why;items,why=notation_visible_items(true);assert(items,why)
 else
  items=selected_items(true,explicit_items and "items" or nil)
  if explicit_notes then
   local count=0;for _,item in ipairs(items) do count=count+#(item.selection_source or {}) end
   assert(count>0,"Keine editierbaren Einzelnoten markiert; kein Rückfall auf ganze Items.")
  elseif explicit_items then
   assert(#items>0,"Keine Arrangement-MIDI-Items ausgewählt; kein Rückfall auf ganze Spuren.")
  elseif #items==0 then
   local tracks=selected_tracks();if #tracks>0 then items=track_context_items(tracks) end
  end
 end
 local num,den=reaper.TimeMap_GetTimeSigAtTime(0,0)
 local snapshot=music_model.capture(items,reaper.Master_GetTempo(),num,den)
 snapshot.tempo_map={}
 local map_count=reaper.CountTempoTimeSigMarkers(0)
 assert(map_count<=256,"Mehr als 256 Tempo-/Taktmarker; bitte ein kleineres Ausgangsprojekt verwenden.")
 for i=0,map_count-1 do
  local ok,at,_,_,bpm,n,d,linear=reaper.GetTempoTimeSigMarker(0,i)
  assert(ok,"Tempo-/Taktkarte konnte nicht gelesen werden.")
  snapshot.tempo_map[#snapshot.tempo_map+1]={at=reaper.TimeMap2_timeToQN(0,at),bpm=bpm,numerator=n,denominator=d,linear=linear}
 end
 local reference=""
 for _,item in ipairs(items) do if item.selection_source and #item.selection_source>0 then reference=editor_reference_excerpt(items);break end end
 return snapshot,items,score_context_tracks(items),reference
end
function music_workspace.song_to_cs(text,snapshot)
 local ok,result,summary=pcall(function()
  local song=music_model.validate_song(decode_engine_json(text),snapshot)
  local cs,why=engine_translate_json(text);assert(cs,why)
  local rows={}
  for line in cs:gmatch("[^\r\n]+") do
   -- A new song is a separate variant; its metadata never replaces the project map.
   if not line:match("^CSMETA|") then
    assert(line:match("^CS|new|%-|") or line:match("^CSCTRL|"),"Unzulässige Songoperation.")
    rows[#rows+1]=line
   end
  end
  local description={"Song als separate neue Spuren; Original und Projekttempo bleiben erhalten.","Für den Hörvergleich neue Songspuren solo schalten; Quellspuren werden nicht automatisch stummgeschaltet."}
  for _,section in ipairs(song.sections) do
   description[#description+1]=string.format("%s: QN %.3f–%.3f%s",section.name,section.start_qn,section.end_qn,section.purpose and " · "..section.purpose or "")
  end
  for _,track in ipairs(song.tracks) do if track.role then description[#description+1]=track.name..": "..track.role end end
  for _,relation in ipairs(song.relationships or {}) do description[#description+1]=relation.from.." → "..relation.to..": "..relation.description end
  description[#description+1]="Form-/Rollenbeschreibungen sind KI-Interpretationen, keine unabhängig bestätigte musikalische Qualität."
  return table.concat(rows,"\n"),table.concat(description,"\n")
 end)
 if ok then return result,summary end
 return nil,tostring(result)
end
function music_workspace.request_kind(request)
 local words=request_words(request)
 if words:match("^%s*merke%s+musikalisch%s*:") then return "remember" end
 if words:match("^%s*zeige%s+musikgedaechtnis%s*[%.!]?%s*$") then return "show_memory" end
 if words:match("^%s*loesche%s+musikgedaechtnis%s*[%.!]?%s*$") then return "clear_memory" end
 if words:find("song",1,true) and (words:find("entwick",1,true) or words:match("^%s*baue%s") or words:find("songaufbau",1,true) or words:find("song%-aufbau")) then return "song" end
 if (words:find("werkzusammenhang",1,true) or words:find("musikalischen gesamtzusammenhang",1,true)) and
  (words:find("analys",1,true) or words:find("pruef",1,true) or words:find("untersuch",1,true)) then return "analysis" end
 return nil
end
function music_workspace.try_request(request)
 local kind=music_workspace.request_kind(request)
 if not kind then return false end
 local ok,why=pcall(function()
  if kind=="remember" then
   local text=request:match(":%s*(.-)%s*$")
   music_workspace.store_memory(music_memory.append(music_workspace.read_memory(),text))
   add("KI","Musikalische Entscheidung im Projektgedächtnis gespeichert. Projekt speichern, damit sie nach erneutem Öffnen erhalten bleibt.");busy=false;return
  elseif kind=="show_memory" then
   local context=music_memory.context(music_workspace.read_memory())
   add("KI",context~="" and context or "Noch keine musikalischen Entscheidungen gespeichert.");busy=false;return
  elseif kind=="clear_memory" then
   music_workspace.store_memory(music_memory.empty())
   add("KI","Musikgedächtnis dieses Projekts gelöscht. MIDI und gespeicherte Vorschläge bleiben erhalten.");busy=false;return
  end
  local snapshot,items,tracks,reference=music_workspace.capture(request)
  local memory,error_text=music_workspace.context();assert(memory,error_text)
  assert(not workflow_adapter.history_error,"Ergebnisverlauf nicht lesbar; bitte erst die gespeicherten Daten prüfen.")
  local project=reaper.EnumProjects(-1,"")
  local guard=workflow_adapter.guard()
  local key=get_key();assert(key,"API-Key fehlt.")
  assert(reaper.EnumProjects(-1,"")==project and workflow_adapter.normalize_guard(workflow_adapter.guard())==workflow_adapter.normalize_guard(guard),"Projekt oder Quelle während der Auftragserfassung verändert.")
  local context=workflow_adapter.encode(snapshot)
  assert(#context<=256000,"Musikkontext zu groß; bitte einen kleineren Ausschnitt auswählen.")
  last_diag={version=VERSION,provider=provider,model=model,request=request,composition_engine="Composition Studio music workspace / JSON schema adapter"}
  diag_set("context",context.."\n"..reference)
  local data={request=request,full=items,music_tracks=tracks,reference_context=reference,workflow_guard=guard,music_snapshot=snapshot,music_memory_context=memory}
  if kind=="analysis" then
   local task=request.."\nBetrachte alle Stimmen als zusammenhängendes Werk. Unterscheide beobachtete Performance-Daten von Interpretationen zu Motiven, Phrasen, Harmonik, Stimmenrollen, Form, Kontrast und Entwicklung. Bewusste Einfachheit bewahren; keine vorgeschriebene Form oder zusätzliche Komplexität. Nenne Unsicherheit und höchstens wenige konkrete Verbesserungen. Keine automatische Änderung."
   local prompt=analysis_prompt(task,items,tracks).."\nVERSIONIERTES PERFORMANCE-MODELL (keine quantisierte Notation):\n"..context
   if reference~="" then prompt=prompt.."\n"..reference end
   launch("analysis",prompt,key,data)
  else
   local task=request.."\nEntwickle aus dem konkreten Ausgangsmaterial eine vollständige zusammenhängende Songfassung. Motive, Phrasen, Stimmenrollen, Form, Kontraste und Übergänge aus dem Material und dem Nutzerauftrag entwickeln. Keine Standardform, festen Acht-Takt-Variationen oder Pflicht zur Komplexität. Nicht bloß einen Loop mechanisch verlängern. Komponiere das vollständige Werk in diesem einen Aufruf; keine vorgelagerte Konzeptabfrage. Originale nur als read-only Quelle; alle Ergebnisstimmen werden neu angelegt. Bestehendes Projekttempo und bestehende Tempo-/Taktkarte erhalten.\nQUELLMODELL (MIDI-Performance, keine sicher rekonstruierte Notation):\n"..context
   if reference~="" then task=task.."\n"..reference end
   local prompt=engine_json_prompt(task)..[[

Ergänze das bestehende JSON-Objekt um "schema":"Composition-Song-1".
"bpm" muss dem Quellmodelltempo entsprechen, "timeSignature" dessen time_signature; keine tempoEvents.
Zusätzlich "sections":[{"id":"a","name":"freier Abschnittsname","start_qn":0,"end_qn":16,"purpose":"musikalische Funktion"}].
Abschnitte beschreiben lückenlos den gesamten Song ab QN 0; ihre Länge und Anzahl ergeben sich frei aus der Musik.
Die Beispielzahlen sind keine Längenvorgabe. Abschnittskennungen müssen eindeutig sein.
Optional "relationships":[{"from":"a","to":"b","description":"konkreter motivischer oder formaler Bezug"}].
Pro Spur optional "role":"musikalische Rolle". Namen müssen eindeutig sein, ohne | oder Zeilenumbrüche.
Technische Obergrenzen: 32 Spuren, 32 Abschnitte, 20000 Noten und 4096 QN; keine musikalischen Zielwerte.
Form-/Rollenbeschreibungen aus der in derselben Antwort tatsächlich komponierten Musik ableiten, keine bloßen Absichtserklärungen.
Gib nur das vollständige JSON zurück. Keine Änderung des Quellmaterials und keine zweite technische KI-Übersetzung.
]]
   launch("song_construction",prompt,key,data)
  end
 end)
 if not ok then add("KI",tostring(why));busy=false end
 return true
end

