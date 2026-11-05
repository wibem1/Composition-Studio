-- BEGIN WHOLE TRACK LOCAL_SCOPE
do
-- END WHOLE TRACK LOCAL_SCOPE
local function title_prompt()
 local draft=last_diag.composition_music or ""; local req=last_diag.request or ""
 return [[Gib dieser vorhandenen Komposition einen kurzen, eigenständigen Werktitel. Antworte ausschließlich mit dem Titel, ohne Anführungszeichen, ohne „Titel:“ und ohne Erläuterung. Der Titel soll musikalisch passend sein und nicht bloß Instrumente oder den Auftrag wiederholen.]].."\n\nAUFTRAG:\n"..req.."\n\nFERTIGE KOMPOSITION:\n"..draft
end
ensure_title_then=function(kind)
 if safe_work_title(work_title)~="" then return false end
 local recovered=title_from_draft(last_diag.composition_music or "",last_diag.request or "")
 if recovered~="" then work_title=recovered; reaper.SetProjExtState(0,EXT_SECTION,TITLE_KEY,work_title); diag_set("work_title",work_title); return false end
 local key=get_key(); if not key then update_status="Für die Titelermittlung fehlt der API-Key."; return true end
 update_status="KI findet einen Werktitel …"; launch("work_title",title_prompt(),key,{save_kind=kind}); return true
end
local function summary_prompt(request,comp,made)
 return [[Beschreibe die bereits fertig komponierte MIDI-Komposition kurz, konkret und hörbezogen. Nenne Tempo/BPM, Tonart bzw. falls nicht eindeutig 'tonales Zentrum nicht eindeutig', den Umfang in Takten soweit aus den QN-Daten ableitbar, die prägende musikalische Idee und höchstens eine auffällige klangliche oder satztechnische Eigenheit. Maximal 600 Zeichen. Keine Takt-für-Takt-Analyse, keine Bewertung und keine Verbesserungsvorschläge. Erfinde keine Angaben.]].."\nREAPER-TEMPO: "..string.format("%.2f BPM",reaper.Master_GetTempo()).."\nAUFTRAG: "..request.."\nMIDI-DATEN:\n"..comp
end
-- BEGIN WHOLE TRACK LOCAL_SCOPE_END
end
-- END WHOLE TRACK LOCAL_SCOPE_END
local function poll_job()
 if not job then return end; if reaper.EnumProjects(-1,"")~=job.project then job=nil; busy=false; update_status="KI-Auftrag wegen Projektwechsel verworfen."; return end; local text,e,done=ai_poll(job.ai); if not done then return end; local stage,data,key=job.stage,job.data,job.key; job=nil
 log_communication(stage,"KI → APP ("..(text and "Antwort" or "Fehler")..")",text or e)
 log_communication(stage,"SYSTEM/API Verbrauch",string.format("Eingabe: %s; Ausgabe: %s; Kosten USD: %s; Status: %s",tostring(last_diag.usage_input_tokens or "?"),tostring(last_diag.usage_output_tokens or "?"),tostring(last_diag.usage_estimated_usd or "?"),tostring(last_diag.api_status or "?")))
-- BEGIN WHOLE TRACK RESULT
 if stage=="whole_track_plan" or stage=="whole_track_window" then whole_track.result(stage,text,data,e,key);return end
 if not text and stage=="composition" and last_diag.api_error=="Tokenlimit erreicht; unvollständige Komposition" then
  add("KI","Für den ganzen Track mit gesicherten Zwischenständen: 'Ganzer Track: '..dein Auftrag. Die Vorbereitung ist lokal und zeigt vor dem Start Aufwand und Kostenrisiko.")
 end
-- END WHOLE TRACK RESULT
 if not text then add("KI",e); busy=false; return end; text=trim(text)
-- BEGIN MUSIC WORKSPACE RESULT
 if stage=="song_construction" then
  local ok,why=pcall(workflow_adapter.offer,stage,text,data)
  if not ok then add("KI",tostring(why));busy=false end
  return
 end
-- END MUSIC WORKSPACE RESULT
 if stage=="notation_patch" or stage=="engine_json" or stage=="lily_continuation" or stage=="lily_composition" or stage=="composition" or stage=="swam_translation" then
  local ok,why=pcall(workflow_adapter.offer,stage,text,data)
  if not ok then add("KI",tostring(why)); busy=false end
  return
 end
 if stage=="analysis" then
  local ok,why=pcall(workflow_adapter.offer,"analysis",text,data)
  if not ok then add("KI",tostring(why)); busy=false end
  return
 end
 if stage=="engine_concept" then
  diag_set("concept_result",text)
  local prompt=composed_json_prompt(data.request,text)
  diag_set("composition_prompt",prompt)
  update_status="Musikalische Konzeption wird komponiert …"
  data.concept_mode=true
  launch("engine_json",prompt,key,data)
  return
 end
  if stage=="work_title" then
  local t=safe_work_title(text:gsub("^[Tt][Ii][Tt][Ee][Ll]%s*:%s*","")); if t=="" then update_status="Kein brauchbarer Werktitel erhalten."; busy=false; return end
  work_title=t; reaper.SetProjExtState(0,EXT_SECTION,TITLE_KEY,work_title); diag_set("work_title",work_title); busy=false
  if data.save_kind=="midi" then export_last_midi() elseif data.save_kind=="diagnosis" then save_diagnosis() end; return
 end
 if stage=="controller" then
  diag_set("controller_answer",text); local chat=text:match("^CHAT|(.*)$"); if chat then add("KI",trim(chat)); busy=false; return end; local ask=text:match("^ASK|(.*)$"); if ask then add("KI",trim(ask)); busy=false; return end
  local cb,ct=text:match("^NEED_CONTINUE|(%d+)|(%d+)|")
  if cb then begin_continuation(data.request,tonumber(cb),tonumber(ct));return end
  if text:match("^NEED_REVISE|") then busy=false;workflow_adapter.review(data.request);return end
  if text:match("^NEED_SWAM|") then busy=false;begin_swam_interpretation();return end
  local awhy=text:match("^NEED_ANALYSIS|(.*)$"); if awhy then local full=data.notation_snapshot or selected_items(true); if #full==0 and #data.tracks>0 then full=track_context_items(data.tracks) end; if #full==0 then add("KI","Für die Analyse ist kein MIDI-Material ausgewählt."); busy=false; return end; data.full=full; data.music_tracks=data.tracks; local prompt=analysis_prompt(data.request,full,data.tracks)
   if data.reference_context and data.reference_context~="" then prompt=prompt.."\n\n"..data.reference_context end
   launch("analysis",prompt,key,data); return end
  local newwhy=text:match("^NEED_NEW|(.*)$"); local why=text:match("^NEED_MUSIC|(.*)$"); if newwhy or why then local full=newwhy and {} or (data.notation_snapshot or selected_items(true)); local tracks=newwhy and {} or data.tracks; if #full==0 and #tracks>0 then full=track_context_items(tracks) end; local cp=composition_prompt(data.request,full,tracks,newwhy~=nil)
   if data.reference_context and data.reference_context~="" and not newwhy then cp=cp.."\n\n"..data.reference_context end
   diag_set("composition_prompt",cp); data.full=full; data.music_tracks=tracks; data.is_new=newwhy~=nil; local ext=why and continuation_bars(data.request) or nil
  if ext then
   local tail,tail_error=request_transition(data.request)
   if tail==nil then add("KI",tail_error);busy=false;return end
   begin_continuation(data.request,ext,tail)
  elseif newwhy then
    launch_new_json(data.request,key,data)
   else launch(newwhy and "composition_music" or "composition",cp,key,data) end; return end
  if text:match("^ACTION|") then
   for _,it in ipairs(data.notation_snapshot or {}) do
    if it.score_context then
     add("KI","Alle sichtbaren MIDI-Spuren sind nur Referenzmaterial. Sofortaktionen auf komplette Items sind im Piano-Roll-/Partiturkontext gesperrt.");busy=false;return
    end
    if it.selection_source and #it.selection_source>0 then
     add("KI","Sofortaktionen auf ganze MIDI-Items sind bei Notenauswahl gesperrt. Bitte eine gezielte Transposition oder Vorschlagsvariante verwenden.");busy=false;return
    end
   end
   local a,pe=parse_action(text,data.items); if not a then add("KI","Ich führe nichts aus: "..pe); busy=false; return end; local ok,ae=execute_action(a); if not ok then add("KI","Die Aktion wurde nicht ausgeführt: "..tostring(ae)); else add("KI",trim(a.desc).." – erledigt. REAPER Undo kann die Änderung rückgängig machen.") end; busy=false; return end
  add("KI","Ich konnte den Auftrag nicht eindeutig einem sicheren Vorgang zuordnen und habe nichts verändert."); busy=false; return
 elseif stage=="swam_interpretation" then
  data.swam_performance=text; update_status="SWAM-Interpret wird technisch übersetzt …"; launch("swam_translation",swam_translation_prompt(data.swam_source,text),key,data); return
 elseif stage=="composition_music" then
  diag_set("composition_music",text); data.draft=text; work_title=title_from_draft(text,data.request); if work_title~="" then reaper.SetProjExtState(0,EXT_SECTION,TITLE_KEY,work_title); diag_set("work_title",work_title) end; local bars=numbered_measure_count(text); if bars>=5 and bars<=256 then data.chunk_total=bars; data.chunk_piano=(tostring(data.request or ""):lower():find("klavier",1,true)~=nil and tostring(data.request or ""):lower():find("und",1,true)==nil); data.chunk_first=1; data.chunk_results={}; data.chunk_retries=0; start_translation_chunk(data,key) else local tp=midi_translation_prompt(data.request,text); diag_set("translation_prompt",tp); launch("composition",tp,key,data) end; return
 elseif stage=="translation_chunk" then
  local valid,reason=check_translation_chunk(text)
  if not valid then
   data.chunk_retries=(data.chunk_retries or 0)+1
   if data.chunk_retries<=2 then
    update_status="Abschnitt unvollständig – erneuter Versuch …"
    start_translation_chunk(data,key)
    return
   end
   diag_set("apply_result","ERROR: Takte "..data.chunk_first.."–"..math.min(data.chunk_total,data.chunk_first+6)..": "..tostring(reason))
   diag_set("composition_answer",table.concat(data.chunk_results or {},"\n").."\n"..text)
   add("KI","MIDI-Übertragung im Abschnitt "..data.chunk_first.." abgebrochen: "..tostring(reason)..". Keine MIDI-Daten wurden übernommen.")
   busy=false; return
  end
  -- Validate actual coverage, not merely syntactic validity. Do not accept missing bars.
  local bar_start=(data.chunk_first-1)*4
  local bar_end=math.min(data.chunk_total,data.chunk_first+6)*4
  for q=bar_start,bar_end-4,4 do
   local covered=false
   for line in tostring(text):gmatch("[^\r\n]+") do
    if line:match("^CS|") then
     local notes=line:match("^CS|[^|]+|[^|]+|[^|]+|%d+|(.+)$")
     if notes then
      for note in notes:gmatch("[^;]+") do
       local at=tonumber(note:match("^%s*([%d%.%-]+),"))
       if at and at>=q-0.0001 and at<q+4-0.0001 then covered=true; break end
      end
     end
    end
    if covered then break end
   end
   if not covered then
    diag_set("apply_result","ERROR: Noten fehlen in Takt "..tostring(math.floor(q/4)+1))
    add("KI","MIDI-Übertragung unvollständig: Takt "..tostring(math.floor(q/4)+1).." fehlt. Keine MIDI-Daten übernommen.")
    busy=false; return
   end
  end
  data.chunk_results[#data.chunk_results+1]=text
  data.chunk_first=data.chunk_first+7
  data.chunk_retries=0
  if data.chunk_first<=data.chunk_total then start_translation_chunk(data,key); return end
  text=table.concat(data.chunk_results,"\n")
  -- Normalize inconsistent piano track labels before the existing merging logic.
  if data.chunk_piano then
   local lines={}
   for line in text:gmatch("[^\r\n]+") do
    if line:match("^CS|new|") then
     line=line:gsub("^(CS|new|[^|]+|)[^|]+|","%1Klavier|")
    elseif line:match("^CSCTRL|") then
     line=line:gsub("^(CSCTRL|)[^|]+|","%1Klavier|")
    end
    lines[#lines+1]=line
   end
   text=table.concat(lines,"\n")
  end
  workflow_adapter.offer("composition",text,data); return
 end
 if stage=="summary" then add("KI",workflow_core.readable(text)); busy=false; return end
end
local function submit() local r=trim(input); if r=="" or busy then return end; input=""; info_visible=false; history_mode=false; costs.begin(); last_diag.communication_log=""; last_diag.composition_idea=""; add("Du",r); busy=true; begin_process(r) end
