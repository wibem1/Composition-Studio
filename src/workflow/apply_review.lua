function workflow_adapter.apply()
 local r=workflow_adapter.pending; if not r or busy then return end
 local ok,err=pcall(function()
  workflow_core.check("apply",{state=r.state,source_guard=r.source_guard,current_guard=workflow_adapter.guard()})
  workflow_adapter.save()
  local result,why
  if r.stage=="composition" and (r.score_scope or #(r.notation_selection or {})>0) then
   assert(not r.payload:find("CS|target|",1,true),"Notenauswahl darf Original-Item nicht überschreiben.")
   assert(not r.payload:find("CS|track|",1,true),"Notenauswahl darf nicht ungeprüft in bestehende Spuren schreiben.")
  end
  if #(r.bindings or {})>0 and r.stage=="composition" then assert(not r.payload:match("CSMETA|"),"Die vorhandene Tempo- und Taktkarte bleibt bei Varianten erhalten. Bitte ohne globale CSMETA-Angaben neu erzeugen.") end
  if r.stage=="notation_patch" then
   result,why=apply_notation_patch(r)
  elseif r.stage=="notation_transpose" then
   result,why=apply_notation_transpose(r)
  elseif r.stage=="lily_continuation" or r.stage=="lily_composition" then local items=workflow_adapter.bindings(r)
   result,why=lily_compile_import(r.payload,r.extension_start,r.extension_bars,r.transition_bars>0 and items or nil)
  else
   local text=r.payload
-- BEGIN WHOLE TRACK APPLY
   if r.stage=="whole_track" then text=whole_track.to_cs(text,r.track_snapshot) end
-- END WHOLE TRACK APPLY
-- BEGIN MUSIC WORKSPACE APPLY
   if r.stage=="song_construction" then text,why=music_workspace.song_to_cs(text,r.music_snapshot);assert(text,why) end
-- END MUSIC WORKSPACE APPLY
   if r.stage=="engine_json" then text,why=engine_translate_json(text); assert(text,why) end
   local items,tracks=workflow_adapter.bindings(r)
   result,why=apply_composition(text,items,tracks,r.chunk_piano)
   if result then
    if r.stage=="swam_translation" then swam_last_made=result else last_made=result end
    local ids={}; for _,it in ipairs(result) do ids[#ids+1]=item_guid(it) end
    reaper.SetProjExtState(0,EXT_SECTION,"LastMadeGUIDs",table.concat(ids,"\n"))
    local ok,why=pcall(initialize_halion_project)
    if not ok then diag_set("halion_result",tostring(why)) end
   end
  end
  assert(result,why or "Vorschlag konnte nicht angewendet werden.")
  r.state=workflow_core.advance(r.state,"apply"); workflow_adapter.pending=nil; workflow_adapter.save()
  add("KI",(r.stage=="notation_transpose" or r.stage=="notation_patch")
   and "Nur markierte MIDI-Noten bearbeitet; unmarkierte Noten und Steuerdaten bleiben erhalten. Rückgängig über REAPER Undo."
   or "Änderungen angewendet. Das Original bleibt erhalten. Rückgängig über REAPER Undo.")
 end)
 if not ok then update_status=tostring(err); add("KI",update_status) end
end
function workflow_adapter.review(task)
 if busy then return end
 local r=workflow_adapter.analysis
 if not r then
  for i=#workflow_adapter.records,1,-1 do if workflow_adapter.records[i].stage=="analysis" then r=workflow_adapter.records[i];break end end
 end
 if not r then update_status="Bitte zuerst die Komposition analysieren lassen oder eine gespeicherte Analyse im Verlauf öffnen.";return end
 local ok,err=pcall(function()
  assert(workflow_adapter.guard()==r.source_guard,"Das Original wurde verändert. Bitte neu analysieren.")
  local items,tracks=workflow_adapter.bindings(r)
  if #tracks==0 then
   local seen={}; for _,it in ipairs(items) do local guid=track_guid(it.track); if not seen[guid] then seen[guid]=true; local _,name=reaper.GetTrackName(it.track); tracks[#tracks+1]={track=it.track,guid=guid,name=name} end end
  end
  -- Preserve the analysed editor scope even after saving/reloading a result.
  -- Track membership never authorizes extending a selected-note edit.
  local full=track_context_items(tracks)
  if r.score_scope or #(r.notation_selection or {})>0 then
   local allowed,selection={},{}
   for _,guid in ipairs(r.bindings or {}) do allowed[guid]=true end
   for _,scope in ipairs(r.notation_selection or {}) do selection[scope.guid]=scope.notes end
   local scoped={}
   for _,it in ipairs(full) do
    if allowed[it.guid] then
     if r.score_scope then it.score_context=true end
     if selection[it.guid] then
      it.notes={};it.selection_source=selection[it.guid]
      for _,ref in ipairs(it.selection_source) do
       local sq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(it.take,ref.start_ppq))
       local eq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(it.take,ref.end_ppq))
       it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=ref.pitch,velocity=ref.velocity,channel=ref.channel}
      end
      it.start_qn=it.notes[1] and it.notes[1].start_qn or it.start_qn
      it.end_qn=it.start_qn
      for _,n in ipairs(it.notes) do it.end_qn=math.max(it.end_qn,n.start_qn+n.duration_qn) end
     end
     scoped[#scoped+1]=it
    end
   end
   full=scoped
  end
  assert(#full>0,"Bitte die analysierten Spuren auswählen und erneut analysieren.")
  local key=get_key(); assert(key,"API-Key fehlt.")
  local task=task or (trim(input)~="" and trim(input) or "Setze die musikalisch sinnvollen Vorschläge aus der Analyse um.")
  local prompt=workflow_core.prompt("revise").."\nANALYSE:\n"..r.raw_response.."\n"..composition_prompt(task,full,tracks,false).."\nDie vorhandene Tempo- und Taktkarte erhalten. Keine CSMETA-Zeilen ausgeben. Ausdruck kann in CSCTRL stehen."
  if r.reference_context and r.reference_context~="" then prompt=prompt.."\n\n"..r.reference_context end
  busy=true; launch("composition",prompt,key,{request=task,full=full,music_tracks=tracks,reference_context=r.reference_context,workflow_guard=r.source_guard})
 end)
 if not ok then update_status=tostring(err); busy=false end
end
workflow_adapter_guard=workflow_adapter.guard
workflow_adapter.load()
