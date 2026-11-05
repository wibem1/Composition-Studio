local function begin_process(request)
 -- For an unambiguous new-composition request, do not pay for a controller call.
 local lower=request:lower()
 local pianoDisplay=(lower:find("pianoroll",1,true) or lower:find("piano-roll",1,true)
  or lower:find("piano roll",1,true))
 local viewRequest=(lower:find("zeig",1,true) or lower:find("öffne",1,true)
  or lower:find("öffnen",1,true) or lower:find("aktualisier",1,true)
  or lower:find("vorbereit",1,true) or lower:find("stelle",1,true))
 local nonDisplay=(lower:find("analys",1,true) or lower:find("komponier",1,true)
  or lower:find("verbesser",1,true) or lower:find("überarbeit",1,true)
  or lower:find("ergänz",1,true) or lower:find("verlänger",1,true))
 if pianoDisplay and viewRequest and not nonDisplay then
  local ok,why=open_score_workspace("pianoroll")
  add("KI",why)
  busy=false;return
 end
 -- Local, free display action; never route a view-only command to an AI model.
 if (lower:find("zeig",1,true) or lower:find("öffne",1,true)
    or lower:find("öffnen",1,true) or lower:find("aktualisier",1,true)
    or lower:find("vorbereit",1,true) or lower:find("stelle",1,true))
    and (lower:find("partitur",1,true) or lower:find("notenansicht",1,true)
      or lower:find("notensicht",1,true)) and
    not (lower:find("analys",1,true) or lower:find("komponier",1,true)
      or lower:find("verbesser",1,true) or lower:find("überarbeit",1,true)) then
  local ok,why=open_score_workspace()
  add("KI",why)
  busy=false;return
 end
 local notationItems,notationCount=notation_selection_items(true)
 local mentionsSelectedNotes=(lower:find("markiert",1,true) or lower:find("ausgewählt",1,true))
   and lower:find("noten",1,true)
 local explicitScore=score_request_intent(lower) and not mentionsSelectedNotes
 local scoreItems=nil
 if explicitScore then
  local visible,why=notation_visible_items(true)
  if not visible then add("KI",why);busy=false;return end
  scoreItems=visible
  -- An explicit score analysis uses all VISIBLE MIDI takes, not the
  -- arrangement selection or the currently selected individual notes.
  if lower:find("analys",1,true) or lower:find("untersuch",1,true) then
   local key=get_key()
   if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar.");busy=false;return end
   local tracks=score_context_tracks(scoreItems)
   local prompt=analysis_prompt(request,scoreItems,tracks)
   diag_set("context",music_context(scoreItems,tracks,false))
   launch("analysis",prompt,key,{request=request,full=scoreItems,music_tracks=tracks,workflow_guard=workflow_adapter.guard()})
   return
  end
 end
 -- Never interpret "selected notes" as "entire selected item" when no
 -- editable note selection can be read from the native notation editor.
 if notationCount==0 and mentionsSelectedNotes then
  add("KI","Im REAPER-MIDI-Editor (Piano-Roll oder Notenansicht) sind keine editierbaren Einzelnoten markiert. Kein ganzes MIDI-Item wird ersatzweise bearbeitet.")
  busy=false;return
 end
 local semitones=lower:match("^%s*transponier.-%s+um%s+([%+%-]?%d+)%s+halbton")
                 or lower:match("^%s*transponier.-%s+um%s+([%+%-]?%d+)%s+halbtön")
 if notationCount>0 and semitones then
  local shift=tonumber(semitones)
  if lower:find("nach unten",1,true) and shift>0 then shift=-shift end
  if lower:find("nach oben",1,true) and shift<0 then shift=-shift end
  if shift==0 or math.abs(shift)>24 then add("KI","Markierte Noten um 1–24 Halbtöne transponieren.");busy=false;return end
  local ok,why=pcall(workflow_adapter.offer,"notation_transpose","TRANSPOSE_NOTATION|"..shift,
    {request=request,full=notationItems,workflow_guard=workflow_adapter.guard()})
  if not ok then add("KI",tostring(why));busy=false end
  return
 end
 -- Explicit note editing is routed directly, avoiding an unnecessary
 -- controller call and prohibiting full-item replacement by a loose AI reply.
 local explicitNotes=(lower:find("markiert",1,true) or lower:find("ausgewählt",1,true))
   and lower:find("noten",1,true)
 local editRequested=lower:find("verbesser",1,true) or lower:find("überarbeit",1,true)
   or lower:find("variier",1,true) or lower:find("veränder",1,true)
   or lower:find("ändere",1,true)
 if notationCount>0 and explicitNotes and editRequested then
  -- This first direct-in-place protocol is pitch/velocity only. Do not
  -- silently pretend to honor a rhythmic or structural edit request.
  local unsupported=lower:find("rhythm",1,true) or lower:find("notenläng",1,true)
    or lower:find("notendauer",1,true) or lower:find("einsatzzeit",1,true)
    or lower:find("einfüg",1,true) or lower:find("hinzufüg",1,true)
    or lower:find("lösche",1,true) or lower:find("entfern",1,true)
  if unsupported then
   add("KI","Die direkte Überarbeitung markierter Noten unterstützt bisher ausschließlich Tonhöhen und Anschlagstärken. Rhythmus, Noten einfügen oder löschen ist hier noch nicht freigegeben.")
   busy=false;return
  end
  local key=get_key()
  if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar.");busy=false;return end
  local guard=workflow_adapter.guard()
  local context=notation_patch_prompt(request,notationItems)
  diag_set("composition_prompt",context)
  launch("notation_patch",context,key,{request=request,full=notationItems,workflow_guard=guard})
  return
 end
 if not explicitScore and reaper.CountSelectedMediaItems(0)==0 and select(2,notation_selection_items(false))==0 and
  (lower:find("^%s*komponier") or lower:find("^%s*erstelle%s+ein") or lower:find("^%s*schreibe%s+ein")) and
  (lower:find("stück",1,true) or lower:find("fuge",1,true) or lower:find("sonate",1,true) or lower:find("walzer",1,true) or lower:find("komposition",1,true)) then
  local key=get_key()
  if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar."); busy=false; return end
  last_diag={version=VERSION,composition_engine="Composition Engine JSON bridge "..JSON_ENGINE_VERSION,composition_engine_build="22001",provider=provider,model=model,request=request}
  launch_new_json(request,key,{request=request,full={},music_tracks={}})
  return
 end
 -- Clear text requests avoid an extra routing call; other formulations use the AI controller.
 local bars=continuation_bars(request)
 if bars then
  local tail,why=request_transition(request)
  if tail==nil then add("KI",why);busy=false;return end
  begin_continuation(request,bars,tail);return
 end
 local words=request_words(request)
 if (words:find("ueberarbeit",1,true) or words:find("umsetz",1,true)) and words:find("analyse",1,true) and not words:find("ohne%s+analyse") then
  busy=false;workflow_adapter.review(request);return
 end

 last_diag={version=VERSION,composition_engine=COMPOSITION_ENGINE_NAME.." "..COMPOSITION_ENGINE_VERSION,composition_engine_build=tostring(COMPOSITION_ENGINE_BUILD),provider=provider,model=model,request=request}; persist_diag(); write_file(DIAG_CACHE_PATH,diag_json()); local key=get_key(); if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar."); busy=false; return end
 local items=scoreItems or selected_items(false); local tracks=scoreItems and score_context_tracks(scoreItems) or selected_tracks(); if #tracks==0 then for _,it in ipairs(items) do if it.selection_source then tracks[#tracks+1]={track=it.track,guid=it.track_guid,name=it.track_name,index=math.floor(reaper.GetMediaTrackInfo_Value(it.track,"IP_TRACKNUMBER"))} end end end; diag_set("context",compact_context(items,tracks,false)); local prompt=CONTROLLER.."\n\nBISHERIGER DIALOG:\n"..recent_dialog().."\n\nAKTUELLER AUFTRAG:\n"..request.."\n\nKOMPAKTER REAPER-KONTEXT:\n"..compact_context(items,tracks,false); diag_set("controller_prompt",prompt); local snapshot=scoreItems or selected_items(true); local hasSelection=false
 for _,it in ipairs(snapshot) do if it.selection_source and #it.selection_source>0 then hasSelection=true;break end end
 local reference=hasSelection and editor_reference_excerpt(snapshot) or ""
 if reference~="" then prompt=prompt.."\n\n"..reference; diag_set("controller_prompt",prompt) end
 launch("controller",prompt,key,{request=request,items=items,tracks=tracks,notation_snapshot=snapshot,reference_context=reference,workflow_guard=(hasSelection or scoreItems) and workflow_adapter.guard() or nil})
end

