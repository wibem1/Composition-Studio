-- Host coordinator. No partial MIDI commits and no automatic retries.
whole_track={}
workflow_adapter.labels.whole_track="Ganzer Track"
function whole_track.path() return workflow_adapter.history_path()..".whole-track.json" end
function whole_track.save(state)
 local path=whole_track.path();local raw=workflow_adapter.encode(state)
 assert(#raw<=8000000,"Track-Zwischenstand zu groß.")
 assert(write_file(path..".pending",raw) and read_file(path..".pending")==raw,"Track-Zwischenstand nicht gespeichert.")
 if read_file(path) then
  os.remove(path..".bak");assert(os.rename(path,path..".bak"),"Track-Sicherung fehlgeschlagen.")
 end
 local ok=os.rename(path..".pending",path)
 if not ok then os.rename(path..".bak",path);error("Track-Zwischenstand nicht gespeichert.") end
end
function whole_track.load()
 local path=whole_track.path();local raw=read_file(path)
 if not raw then raw=read_file(path..".bak") end
 assert(raw and #raw<=8000000,"Kein unterstützter Track-Zwischenstand vorhanden.")
 local state=decode_engine_json(raw)
 assert(type(state)=="table" and state.schema=="Composition-TrackJob-1","Track-Zwischenstand nicht lesbar.")
 return state
end
function whole_track.check(state)
 assert(state.guard==workflow_adapter.guard(),"Projekt/Quelle verändert. Track-Auftrag neu vorbereiten.")
 assert(state.provider==provider and state.model==model and state.reasoning==reasoning_mode,"Anbieter, Modell oder Denkaufwand verändert. Ursprüngliche Auswahl wiederherstellen oder neu vorbereiten.")
 assert(not (provider=="google" and model:match("^gemini%-2%.5") and reasoning_mode~="auto"),"Für Gemini 2.5 ist der begrenzte Track-Aufbau nur mit Denkaufwand Automatisch unterstützt; explizite Denkbudgets können das Antwortlimit überschreiten.")
 local memory,why=music_workspace.context();assert(memory,why)
 assert(memory==state.memory,"Musikgedächtnis verändert. Track-Auftrag neu vorbereiten.")
 assert(not workflow_adapter.history_error,"Ergebnisverlauf nicht lesbar.")
end
function whole_track.remaining(state)
 local windows=track_plan.windows(state.snapshot)
 return #windows-#state.results+(state.plan and 0 or 1)
end
function whole_track.preview(state)
 local windows,duration=track_plan.windows(state.snapshot)
 local rate=costs.rate(provider,model)
 local cost_text="Kein hinterlegter Tarif: Start gesperrt, bis ein Tarif in der Kostenübersicht gesetzt ist."
 if rate then
  local example=(50000*rate[1]+track_plan.window_tokens*rate[2])/1000000
  cost_text=string.format("Rechenbeispiel pro Abschnitt bei 50.000 Eingabe- und maximal %d Ausgabetokens: %.3f USD. Tatsächliche Eingabe/Denktokens können abweichen; keine Preisgarantie.",track_plan.window_tokens,example)
 end
 add("KI",string.format("Ganzer Track: %.3f QN, %d technische Arbeitsfenster; musikalische Form frei. Noch höchstens %d KI-Aufrufe (Werkplan + Abschnitte), keine automatische Wiederholung. Bereits %d/%d Abschnitte gesichert.\n%s\nBekannte bisherige Kosten: %.4f USD%s.\nKostenfreigabe z. B. 'Track-Aufbau starten: 2 USD'. Das ist ein geschätztes Ausgabenbudget, keine garantierte Rechnungsobergrenze. Vor jedem weiteren Aufruf wird erneut geprüft. Abbrechen: 'Track-Aufbau abbrechen'.",duration,#windows,whole_track.remaining(state),#state.results,#windows,cost_text,state.spent or 0,state.unknown and "; zusätzlich unbekannter Verbrauch" or ""))
 busy=false
end
function whole_track.prepare(request)
 assert(#request>0,"Auftrag hinter 'Ganzer Track:' fehlt.")
 -- The explicit full-track command uses complete arrangement items, never selected editor notes.
 local items=selected_items(true,"items");local tracks=score_context_tracks(items)
 if #items==0 then tracks=selected_tracks();items=track_context_items(tracks) end
 local num,den=reaper.TimeMap_GetTimeSigAtTime(0,0)
 local snapshot=music_model.capture(items,reaper.Master_GetTempo(),num,den,20000)
 local first,last=math.huge,-math.huge
 for _,it in ipairs(items) do
  assert(type(it.start_qn)=="number" and type(it.end_qn)=="number" and it.start_qn>=0 and it.end_qn>it.start_qn,"Ungültige Itemgrenzen.")
  first=math.min(first,it.start_qn);last=math.max(last,it.end_qn)
 end
 assert(snapshot.bounds.start_qn>=0,"Quellnoten vor Projektbeginn nicht unterstützt.")
 snapshot.bounds.start_qn=math.min(first,snapshot.bounds.start_qn);snapshot.bounds.end_qn=math.max(last,snapshot.bounds.end_qn)
 track_plan.windows(snapshot)
 assert(#workflow_adapter.encode(snapshot)<=2000000,"Musikkontext überschreitet die unterstützte Größe; keine Kürzung vorgenommen.")
 local memory,why=music_workspace.context();assert(memory,why)
 assert(not workflow_adapter.history_error,"Ergebnisverlauf nicht lesbar.")
 local state={schema="Composition-TrackJob-1",id=reaper.genGuid(""),request=request,snapshot=snapshot,guard=workflow_adapter.guard(),provider=provider,model=model,reasoning=reasoning_mode,memory=memory,results={},bindings={},track_bindings={},spent=0}
 for _,it in ipairs(items) do state.bindings[#state.bindings+1]=it.guid end
 for _,tr in ipairs(tracks) do state.track_bindings[#state.track_bindings+1]=tr.guid end
 whole_track.save(state);whole_track.preview(state)
end
function whole_track.prompt(state)
 local windows,duration=track_plan.windows(state.snapshot)
 if not state.plan then
  local context=track_plan.excerpt(state.snapshot,{start_qn=0,end_qn=duration})
  return [=[Plane den GESAMTEN vorhandenen Track gemäß Auftrag. Noch KEINE Noten ausgeben.
Antwort nur JSON: {"schema":"Composition-TrackPlan-1","title":"...","idea":"konkrete motivische/harmonische Werkidee","tracks":[{"name":"...","program":0,"channel":0,"role":"..."}],"sections":[{"name":"...","start_qn":0,"end_qn":16,"direction":"Entwicklung, Harmonik, Motive, Übergang"}]}.
Maximal 16 Stimmen, 32 frei gewählte musikalische Abschnitte. Abschnitte decken die gesamte vorgegebene Dauer lückenlos ab QN 0 ab. Keine Standardform oder Pflicht zu mehr Komplexität. Technische Fenster sind KEINE musikalischen Phrasengrenzen. Quelle read-only, neue Fassung nur auf neuen Spuren.
]=].."AUFTRAG: "..state.request.."\nEXAKTE DAUER QN: "..duration.."\nQUELLE (relative QN ab Trackanfang):\n"..workflow_adapter.encode(context),track_plan.plan_tokens,"whole_track_plan"
 end
 local index=#state.results+1;local window=windows[index]
 local previous=state.results[index-1]
 local tail={}
 if previous then
  for _,tr in ipairs(previous.tracks) do
   local row={name=tr.name,notes={}}
   for _,n in ipairs(tr.notes) do if n[1]+n[2]>window.start_qn-2 then row.notes[#row.notes+1]=n end end
   tail[#tail+1]=row
  end
 end
 return [=[Komponiere das folgende technische Arbeitsfenster als Teil EINER zusammenhängenden Fassung des GESAMTEN Tracks. Gemeinsamen Werkplan und vorherige Übergabe beachten; keine unabhängigen Loops, keine erfundene Verkürzung und keine musikalische Zäsur allein wegen Fenstergrenzen. Noten dürfen über eine Fenstergrenze bis maximal zum Werkende klingen; nicht erneut anschlagen, wenn sie schon im vorherigen Fenster beginnen.
Antwort ausschließlich JSON:
{"schema":"Composition-TrackWindow-1","start_qn":0,"end_qn":16,"bpm":120,"timeSignature":[4,4],"continuity":"tatsächliche Motive/Harmonik/Entwicklung und Übergabe","tracks":[{"name":"exakt aus Plan","program":0,"channel":0,"notes":[[0,1,60,80]],"ccEvents":[]}]}
Noten: [StartQN,DauerQN,Pitch,Velocity], ALLE Starts relativ zum Anfang des GESAMTEN Werks, nicht des Fensters. Nur Noten mit Start innerhalb des aktuellen halboffenen Fensters ausgeben. Keine tempoEvents/pedalEvents/pitchBend; Tempo-/Taktkarte unverändert. CC innerhalb des Fensters; Sustain vor Fensterende lösen. Stille Stimmen dürfen fehlen; ganz stilles Fenster nur mit "rest":true und "tracks":[], ausdrücklich im Übergabetext begründen. Maximal 4000 Noten/Fenster und 20000 insgesamt; technische Grenzen, keine musikalischen Zielwerte. Instrument/Kanal/Name exakt beibehalten. Musik und Ausdruck aus Auftrag/Quelle entwickeln.
]=].."AUFTRAG: "..state.request.."\nWERKPLAN:\n"..workflow_adapter.encode(state.plan).."\nEXAKTES FENSTER:\n"..workflow_adapter.encode(window).."\nTEMPO/TAKT UND QUELLE:\n"..workflow_adapter.encode(track_plan.excerpt(state.snapshot,window)).."\nVORHERIGE ÜBERGABE:\n"..(previous and previous.continuity or "Werkbeginn").."\nVORHERIGE AUSKLINGENDE NOTEN:\n"..workflow_adapter.encode(tail),track_plan.window_tokens,"whole_track_window"
end
function whole_track.next(state,key)
 whole_track.check(state)
 local windows,duration=track_plan.windows(state.snapshot)
 if #state.results==#windows then
  local score=track_plan.assemble(state.plan,state.results,windows,state.snapshot)
  music_model.validate_song(score,state.snapshot)
  local raw=workflow_adapter.encode(score);local cs,why=engine_translate_json(raw);assert(cs,why)
  -- A saved complete proposal is offered once, including after restart.
  for _,r in ipairs(workflow_adapter.records) do if r.track_run_id==state.id then add("KI","Vollständiger Track bereits im Ergebnisverlauf gespeichert.");busy=false;return end end
  local items,tracks=workflow_adapter.bindings(state)
  workflow_adapter.offer("whole_track",raw,{request=state.request,full=items,music_tracks=tracks,workflow_guard=state.guard,workflow_provider=state.provider,workflow_model=state.model,music_memory_context=state.memory,track_snapshot=state.snapshot,track_run_id=state.id})
  return
 end
 if state.plan then
  track_plan.validate(state.plan,duration)
  assert(#state.results<=#windows,"Zu viele gespeicherte Abschnitte.")
  for i,result in ipairs(state.results) do track_plan.validate_window(result,windows[i],state.plan,state.snapshot,duration) end
 end
 local prompt,limit,stage=whole_track.prompt(state)
 local rate=costs.rate(provider,model);assert(rate,"Kein gültiger Tarif für die Kostenplanung hinterlegt.")
 -- Conservative byte-based estimate plus transport overhead, not a billing guarantee.
 local input_estimate=#prompt+#state.memory+4096
 local estimate=(input_estimate*rate[1]+limit*rate[2])/1000000
 assert(estimate<=state.allowance-(state.spent or 0),string.format("Kostenbudget reicht für den nächsten Aufruf voraussichtlich nicht (%.3f USD). Zwischenstand gesichert; keine weitere Anfrage. 'Track-Aufbau fortsetzen' zeigt den Stand.",estimate))
 state.inflight=true;whole_track.save(state)
 update_status=stage=="whole_track_plan" and "Werkplan für ganzen Track …" or string.format("Ganzer Track: Abschnitt %d/%d …",#state.results+1,#windows)
 local started=launch(stage,prompt,key,{whole_track_state=state,whole_track_output_limit=limit,workflow_guard=state.guard})
 if not started then state.inflight=false;whole_track.save(state) end
end
function whole_track.result(stage,text,data,error_text,key)
 local state=data.whole_track_state
 local ok,why=pcall(function()
  whole_track.check(state)
  state.inflight=false
  local usd=tonumber(last_diag.usage_estimated_usd)
  if usd then state.spent=(state.spent or 0)+usd else state.unknown=true end
  whole_track.save(state)
  assert(text,error_text or "KI-Antwort fehlt.")
  local windows,duration=track_plan.windows(state.snapshot)
  local value=decode_engine_json(text)
  if stage=="whole_track_plan" then track_plan.validate(value,duration);state.plan=value
  else
   track_plan.validate_window(value,windows[#state.results+1],state.plan,state.snapshot,duration)
   state.results[#state.results+1]=value
  end
  whole_track.save(state)
  assert(usd,"Verbrauch unbekannt: gültiges Ergebnis gesichert, vor weiteren kostenpflichtigen Aufrufen erneut freigeben.")
  whole_track.next(state,key)
 end)
 if not ok then add("KI",tostring(why).."\nKeine Teilübernahme, keine automatische Wiederholung. Gültige Zwischenstände bleiben gespeichert. 'Track-Aufbau fortsetzen' zeigt Aufwand und Kostenrisiko.");busy=false end
end
function whole_track.to_cs(text,snapshot)
 local score=music_model.validate_song(decode_engine_json(text),snapshot)
 local origin=snapshot.bounds.start_qn
 for _,tr in ipairs(score.tracks) do
  for _,n in ipairs(tr.notes) do n[1]=n[1]+origin end
  for _,c in ipairs(tr.ccEvents or {}) do c.at=c.at+origin end
 end
 local cs,why=engine_translate_json(workflow_adapter.encode(score));assert(cs,why)
 local rows={};for line in cs:gmatch("[^\r\n]+") do if not line:match("^CSMETA|") then rows[#rows+1]=line end end
 return table.concat(rows,"\n")
end
function whole_track.cancel()
 if job and (job.stage=="whole_track_plan" or job.stage=="whole_track_window") then
  -- The detached transport may already incur charges; do not launch any successor.
  job=nil;busy=false
  add("KI","Track-Aufbau angehalten. Laufender Anbieteraufruf kann weiter Kosten verursachen; dessen Ergebnis wird nicht übernommen. Bereits gesicherte Abschnitte bleiben erhalten.")
 end
end
function whole_track.try_request(request)
 local task=request:match("^%s*[Gg]anzer%s+[Tt]rack:%s*(.*)$")
 local words=request_words(request)
 local resume=words:match("^%s*track%-aufbau fortsetzen%s*[%.!]?%s*$")
 local cancel=words:match("^%s*track%-aufbau abbrechen%s*[%.!]?%s*$")
 local amount=words:match("^%s*track%-aufbau starten:%s*(%d+[.,]?%d*)%s*usd%s*$")
 if not task and not resume and not cancel and not amount then return false end
 local ok,why=pcall(function()
  if task then whole_track.prepare(task)
  elseif cancel then whole_track.cancel();busy=false;add("KI","Keine weiteren Track-Aufrufe gestartet. Gesicherter Zwischenstand bleibt erhalten.")
  else
   local state=whole_track.load();whole_track.check(state)
   if resume then whole_track.preview(state)
   else
    local budget=tonumber((amount:gsub(",",".")));assert(budget and budget>0 and budget<=100,"Budget muss größer 0 und höchstens 100 USD sein.")
    -- A fresh explicit allowance also acknowledges uncertain cost of an interrupted call.
    state.allowance=(state.spent or 0)+budget
    if state.inflight then state.unknown=true;state.inflight=false end
    local key=get_key();assert(key,"API-Key fehlt.")
    last_diag={version=VERSION,provider=provider,model=model,request=state.request,composition_engine="Composition Studio whole-track workflow"}
    whole_track.next(state,key)
   end
  end
 end)
 if not ok then add("KI",tostring(why));busy=false end
 return true
end
