-- Host adapter: source binding and durable, reloadable proposals. No AI keys in records.
local workflow_adapter={labels={engine_json="Komposition",composition="Überarbeitung",analysis="Analyse",notation_patch="Markierte Noten KI-Überarbeitung",notation_transpose="Markierte Noten transponieren",lily_continuation="Fortsetzung",lily_composition="Komposition",swam_translation="SWAM-Interpretation"},states={ready="Vorschlag",applied="Übernommen",draft="Analyse",invalid="Fehlerhafte Antwort"},records={},pending=nil,committing=false,analysis=nil}
function workflow_adapter.encode(v)
 local kind=type(v)
 if kind=="nil" then return "null" elseif kind=="boolean" or kind=="number" then return tostring(v)
 elseif kind=="string" then return '"'..v:gsub('[%z\1-\31\\"]',function(ch) local map={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}; return map[ch] or string.format('\\u%04x',ch:byte()) end)..'"'
 elseif kind=="table" then local out={}; if #v>0 then for _,x in ipairs(v) do out[#out+1]=workflow_adapter.encode(x) end; return '['..table.concat(out,',')..']' end; for k,x in pairs(v) do out[#out+1]=workflow_adapter.encode(tostring(k))..':'..workflow_adapter.encode(x) end; table.sort(out); return '{'..table.concat(out,',')..'}' end
 error("Nicht speicherbarer Arbeitsstand")
end
function workflow_adapter.guard()
 local rows={}
 for i=0,reaper.CountTracks(0)-1 do
  local tr=reaper.GetTrack(0,i); local _,name=reaper.GetTrackName(tr)
  rows[#rows+1]=track_guid(tr).."\n"..name
  for j=0,reaper.CountTrackMediaItems(tr)-1 do
   local item=reaper.GetTrackMediaItem(tr,j); local ok,chunk=reaper.GetItemStateChunk(item,"",false)
   assert(ok,"Original konnte nicht gesichert werden"); rows[#rows+1]=chunk
  end
 end
 rows[#rows+1]=tostring(reaper.Master_GetTempo())
 for i=0,reaper.CountTempoTimeSigMarkers(0)-1 do local _,tm,mp,bp,bpm,num,den,linear=reaper.GetTempoTimeSigMarker(0,i); rows[#rows+1]=workflow_adapter.encode({tm,mp,bp,bpm,num,den,linear}) end
 return table.concat(rows,"\n")
end
function workflow_adapter.history_path()
 local dir=reaper.GetResourcePath().."/CompositionStudioResults"
 reaper.RecursiveCreateDirectory(dir,0)
 local _,identity=reaper.GetProjExtState(0,EXT_SECTION,"WorkflowProjectIdV1")
 if not identity or identity=="" then
  identity=reaper.genGuid("")
  assert(type(identity)=="string" and identity~="","Projektbindung konnte nicht erzeugt werden.")
  reaper.SetProjExtState(0,EXT_SECTION,"WorkflowProjectIdV1",identity)
  local _,stored=reaper.GetProjExtState(0,EXT_SECTION,"WorkflowProjectIdV1")
  assert(stored==identity,"Projektbindung konnte nicht gespeichert werden.")
 end
 local guid=identity:gsub("[^%w%-]","")
 assert(guid~="","Projektbindung fehlt")
 return dir.."/Workflow-"..guid..".json"
end
function workflow_adapter.save()
 local raw=workflow_adapter.encode(workflow_adapter.records)
 local path=workflow_adapter.history_path()
 assert(write_file(path..".pending",raw) and read_file(path..".pending")==raw,"Der Arbeitsstand konnte nicht gesichert werden.")
 if read_file(path) then
  os.remove(path..".bak")
  assert(os.rename(path,path..".bak"),"Verlaufssicherung konnte nicht angelegt werden.")
 end
 local ok=os.rename(path..".pending",path)
 if not ok then os.rename(path..".bak",path); error("Der Arbeitsverlauf konnte nicht gespeichert werden.") end
 reaper.SetProjExtState(0,EXT_SECTION,"WorkflowHistoryV1",raw)
 local _,actual=reaper.GetProjExtState(0,EXT_SECTION,"WorkflowHistoryV1")
 assert(actual==raw and read_file(path)==raw,"Der Arbeitsstand konnte nicht gesichert werden.")
end
function workflow_adapter.load_unchecked()
 workflow_adapter.history_error=false
 workflow_adapter.pending=nil; workflow_adapter.analysis=nil; workflow_adapter.records={}
 local path=workflow_adapter.history_path()
 local raw=read_file(path)
 if not raw then raw=read_file(path..".bak") end
 if not raw then local _,project=reaper.GetProjExtState(0,EXT_SECTION,"WorkflowHistoryV1");raw=project end
 if raw and raw~="" then
  local ok,v=pcall(decode_engine_json,raw)
  if ok and type(v)=="table" then workflow_adapter.records=v
  else
   local backup=read_file(path..".bak");local restored,records=pcall(decode_engine_json,backup or "")
   if restored and type(records)=="table" then workflow_adapter.records=records;update_status="Arbeitsverlauf aus Sicherung geladen."
   else update_status="Arbeitsverlauf konnte nicht gelesen werden; gespeicherte Daten bleiben erhalten.";workflow_adapter.history_error=true end
  end
 end
end
function workflow_adapter.load()
 local ok,err=pcall(workflow_adapter.load_unchecked)
 if not ok then
  workflow_adapter.history_error=true
  workflow_adapter.pending=nil;workflow_adapter.analysis=nil;workflow_adapter.records={}
  update_status="Arbeitsverlauf nicht verfügbar: "..tostring(err)
 end
 return ok
end
function workflow_adapter.offer(stage,text,data)
-- BEGIN WHOLE TRACK VALIDATION
 if stage=="whole_track" then whole_track.to_cs(text,data.track_snapshot) end
-- END WHOLE TRACK VALIDATION
-- BEGIN MUSIC WORKSPACE VALIDATION
 local song_summary
 if stage=="song_construction" then
  local cs,why=music_workspace.song_to_cs(text,data.music_snapshot);assert(cs,why);song_summary=why
 end
-- END MUSIC WORKSPACE VALIDATION
 diag_set(stage=="analysis" and "analysis_answer" or "composition_answer",text)
 if stage=="engine_json" or stage=="song_construction" then
  diag_set("composition_music",text)
  local ok,score=pcall(decode_engine_json,text)
  if ok and type(score)=="table" then
   if type(score.idea)=="string" then diag_set("composition_idea",score.idea); add("KI · Kompositionsidee",score.idea) end
   if type(score.title)=="string" then work_title=safe_work_title(score.title); reaper.SetProjExtState(0,EXT_SECTION,TITLE_KEY,work_title) end
  end
 end
 assert(not workflow_adapter.history_error,"Verlauf ist nicht lesbar. Bitte Projektkopie und Diagnose sichern.")
 local r={format=workflow_core.format,core_version=workflow_core.version,id=tostring(os.time()).."-"..tostring(#workflow_adapter.records+1),created=os.date("%Y-%m-%d %H:%M"),stage=stage,request=data.request or "",raw_response=text,payload=text,state=stage=="analysis" and "draft" or workflow_core.advance("draft","propose"),source_guard=data.workflow_guard or workflow_adapter.guard(),provider=data.workflow_provider or provider,model=data.workflow_model or model,bindings={},track_bindings={},extension_start=data.extension_start,extension_bars=data.extension_bars,transition_bars=data.transition_bars or 0,chunk_piano=data.chunk_piano or false}
-- BEGIN MUSIC WORKSPACE RECORD
 if stage=="song_construction" then r.music_snapshot=data.music_snapshot;r.song_summary=song_summary end
 if data.music_memory_context and data.music_memory_context~="" then r.music_memory_context=data.music_memory_context end
-- END MUSIC WORKSPACE RECORD
-- BEGIN WHOLE TRACK RECORD
 if stage=="whole_track" then r.track_snapshot=data.track_snapshot;r.track_run_id=data.track_run_id end
-- END WHOLE TRACK RECORD
 for _,it in ipairs(data.full or {}) do r.bindings[#r.bindings+1]=it.guid end
 r.notation_selection={}
 for _,it in ipairs(data.full or {}) do if it.selection_source and #it.selection_source>0 then r.notation_selection[#r.notation_selection+1]={guid=it.guid,notes=it.selection_source} end end
 r.reference_context=data.reference_context or ""
 r.score_scope=false
 for _,it in ipairs(data.full or {}) do if it.score_context then r.score_scope=true;break end end
 for _,tr in ipairs(data.music_tracks or data.tracks or {}) do r.track_bindings[#r.track_bindings+1]=tr.guid end
 workflow_adapter.records[#workflow_adapter.records+1]=r
 workflow_adapter.save()
 if stage=="analysis" then workflow_adapter.analysis=r else workflow_adapter.pending=r end
 update_status=stage=="analysis" and "Analyse gespeichert. Zur Umsetzung zum Beispiel eingeben: Überarbeite anhand dieser Analyse." or "Vorschlag gespeichert. Mit Änderungen anwenden übernehmen."
 add("KI",stage=="analysis" and workflow_core.readable(text) or update_status)
-- BEGIN MUSIC WORKSPACE SUMMARY
 if song_summary then add("KI · Songstruktur",song_summary) end
-- END MUSIC WORKSPACE SUMMARY
 busy=false
end
function workflow_adapter.bindings(r)
 local items,tracks={},{}
 for _,guid in ipairs(r.bindings or {}) do
  local found
  for i=0,reaper.CountMediaItems(0)-1 do local it=reaper.GetMediaItem(0,i); if item_guid(it)==guid then found={guid=guid,item=it,take=reaper.GetActiveTake(it),track=reaper.GetMediaItem_Track(it)}; break end end
  assert(found,"Quell-Item fehlt. Bitte neu einlesen."); items[#items+1]=found
 end
 for _,guid in ipairs(r.track_bindings or {}) do local found; for i=0,reaper.CountTracks(0)-1 do local tr=reaper.GetTrack(0,i); if track_guid(tr)==guid then found={guid=guid,track=tr}; break end end; assert(found,"Quellspur fehlt."); tracks[#tracks+1]=found end
 return items,tracks
end
function workflow_adapter.transition(items,endpoint,count)
 workflow_core.check("request",{mode="continue",task="Fortsetzung",transition_bars=count})
 if count==0 then return endpoint end
 local at=reaper.TimeMap2_QNToTime(0,endpoint)
 local num,den=reaper.TimeMap_GetTimeSigAtTime(0,at-0.0001)
 assert(num and den and den>0,"Taktart konnte nicht bestimmt werden.")
 local start=endpoint-count*4*num/den
 assert(start>0,"Vor dem Übergang muss Musik erhalten bleiben.")
 local _,_,ending=reaper.TimeMap_QNToMeasures(0,endpoint-0.0000001)
 local _,beginning=reaper.TimeMap_QNToMeasures(0,start+0.0000001)
 assert(ending and beginning and math.abs(ending-endpoint)<0.00001 and math.abs(beginning-start)<0.00001,"Für einen Übergang muss das Stück an einer vollständigen Taktgrenze enden.")
 for i=0,reaper.CountTempoTimeSigMarkers(0)-1 do local _,tm,_,_,_,n,d=reaper.GetTempoTimeSigMarker(0,i); local q=reaper.TimeMap2_timeToQN(0,tm); assert(q<start or q>endpoint or (n==0 or n==num) and (d==0 or d==den),"Taktwechsel im Übergang: Bitte Schluss erhalten wählen.") end
 for _,it in ipairs(items) do
  for _,note in ipairs(it.notes or {}) do assert(not(note.start_qn<start-0.000001 and note.start_qn+note.duration_qn>start+0.000001),"Eine Note überspannt die Übergangsgrenze. Bitte andere Übergangslänge wählen.") end
  local pedals={}
  local _,_,nc=reaper.MIDI_CountEvts(it.take)
  for j=0,(nc or 0)-1 do local ok,_,_,ppq,msg,ch,cc,v=reaper.MIDI_GetCC(it.take,j); if ok and msg==0xB0 and cc==64 then local q=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(it.take,ppq)); if q<start then pedals[ch]=v end end end
  for _,v in pairs(pedals) do assert(v<64,"Sustain-Pedal überspannt die Übergangsgrenze. Bitte andere Übergangslänge wählen.") end
 end
 return start
end

