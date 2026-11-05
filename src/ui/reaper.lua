local function wrap_text(s,limit) limit=math.max(12,math.floor(limit or 40)); local out={}; for line in (tostring(s or "").."\n"):gmatch("(.-)\n") do while #line>limit do local cut=limit; local part=line:sub(1,limit); local sp=part:match("^.*()%s+"); if sp and sp>math.floor(limit*0.55) then cut=sp end; out[#out+1]=line:sub(1,cut):gsub("%s+$",""); line=line:sub(cut+1):gsub("^%s+","") end; out[#out+1]=line end; return table.concat(out,"\n"):gsub("\n$","") end
local function clipboard_set(s) if type(reaper.ImGui_SetClipboardText)=="function" then reaper.ImGui_SetClipboardText(ctx,s or "") end end
local function clipboard_get() if type(reaper.ImGui_GetClipboardText)=="function" then return reaper.ImGui_GetClipboardText(ctx) or "" end return "" end
local function text_context_menu(id,text,editable)
 if type(reaper.ImGui_BeginPopupContextItem)~="function" then return text end
 if reaper.ImGui_BeginPopupContextItem(ctx,id) then
  if editable and reaper.ImGui_MenuItem(ctx,"Ausschneiden") then clipboard_set(text); text="" end
  if reaper.ImGui_MenuItem(ctx,"Kopieren") then clipboard_set(text) end
  if editable and reaper.ImGui_MenuItem(ctx,"Einfügen") then text=text..clipboard_get() end
  if editable and reaper.ImGui_MenuItem(ctx,"Alles löschen") then text="" end
  reaper.ImGui_EndPopup(ctx)
 end
 return text
end

local function info_text()
 return "Composition Studio "..VERSION.." · 19.10.2026\nGemeinsamer Workflow-Kern "..workflow_core.version..
 "\n\nAnalyse → Überarbeitung → Vorschlag → Änderungen anwenden. Original und Vorschläge bleiben im Ergebnisverlauf erhalten. Das Modell für Analyse und Überarbeitung ist jeweils frei wählbar."..
 "\n\nAufträge direkt eingeben: Verlängere um 16 Takte; ergänze eine weitere Stimme; analysiere die Auswahl; überarbeite anhand der letzten Analyse. Für einen Übergang zum Beispiel: Verlängere um 16 Takte und gestalte die letzten 2 Takte neu. Ohne Freigabe bleibt der Schluss erhalten."..
 "\n\nModelllisten werden direkt beim Anbieter abgefragt. Ausdruck wird als Notendauer, Velocity, Tempo und MIDI-Controller übernommen; die Wirkung hängt vom Instrument ab."..
-- BEGIN MUSIC WORKSPACE HELP
 "\n\nMusikgedächtnis: Merke musikalisch: Die Begleitung bleibt schlicht. Anzeigen mit Zeige Musikgedächtnis; bewusst zurücksetzen mit Lösche Musikgedächtnis.\nWerkzusammenhang: Analysiere den Werkzusammenhang.\nSong-Aufbau: Entwickle die Auswahl zu einem vollständigen Song. Der Song wird als Vorschlag auf neuen Spuren vorbereitet; Projekttempo und Original bleiben erhalten."..
-- END MUSIC WORKSPACE HELP
 "\n\nTechnische Tests verwenden simulierte REAPER-Schnittstellen. Der praktische Test dieser Version steht aus."
end
local function fit_label(text,width)
 text=tostring(text or "")
 local function measured(value) return reaper.ImGui_CalcTextSize(ctx,value) end
 if measured(text)<=width then return text end
 local chars={};for ch in text:gmatch("[\0-\127\194-\244][\128-\191]*") do chars[#chars+1]=ch end
 while #chars>0 and measured(table.concat(chars).."…")>width do table.remove(chars) end
 return table.concat(chars).."…"
end
local function draw_model_picker(width)
 -- Opening the picker is local: a network refresh must be an explicit action.
 if reaper.ImGui_Button(ctx,fit_label(model_label(),math.max(1,width-36)).." v###model",width) and not busy then
  workflow_adapter.models.filter=""
  workflow_adapter.models.view_provider=provider
  workflow_adapter.models.show_all=false
  reaper.ImGui_OpenPopup(ctx,"##model_menu")
 end
 local popup_width=math.max(260,math.min(480,width))
 reaper.ImGui_SetNextWindowSizeConstraints(ctx,popup_width,0,popup_width,600)
 if not reaper.ImGui_BeginPopup(ctx,"##model_menu") then return end
 reaper.ImGui_TextWrapped(ctx,"Aktuell: "..provider.." / "..model)
 -- Provider controls stay outside the scrolling catalog: OpenAI must never
 -- push Anthropic and Google below the screen.
 for _,pv in ipairs({"openai","anthropic","google"}) do
  local title=pv=="openai" and "OpenAI" or pv=="anthropic" and "Anthropic" or "Google"
  if reaper.ImGui_Button(ctx,title..(workflow_adapter.models.view_provider==pv and " *" or "").."###provider_"..pv,-1) then
   workflow_adapter.models.view_provider=pv;workflow_adapter.models.filter=""
  end
 end
 if reaper.ImGui_Button(ctx,workflow_adapter.models.show_all and "Nur Hauptmodelle" or "Alle verfügbaren Modelle",-1) then
  workflow_adapter.models.show_all=not workflow_adapter.models.show_all;workflow_adapter.models.filter=""
 end
 if workflow_adapter.models.show_all then
  if reaper.ImGui_MenuItem(ctx,"Verfügbare Modelle aktualisieren",nil,false,not busy and not workflow_adapter.models.job) then workflow_adapter.models.refresh(false,workflow_adapter.models.view_provider) end
  local changed,value=reaper.ImGui_InputText(ctx,"Suche",workflow_adapter.models.filter)
  if changed then workflow_adapter.models.filter=value end
 end
 local query=workflow_adapter.models.filter:lower()
 -- Keep all providers reachable even with hundreds of cached models.
 if reaper.ImGui_BeginChild(ctx,"##model_list",0,math.min(200,reaper.ImGui_GetFrameHeight(ctx)*6),reaper.ImGui_ChildFlags_Borders()) then
  local count=0
  for _,pv in ipairs({"openai","anthropic","google"}) do
   if pv==workflow_adapter.models.view_provider then
   local rows={};local has_current=false
   for _,m in ipairs(workflow_adapter.models.show_all and MODELS[pv] or workflow_adapter.models.featured[pv]) do
    rows[#rows+1]=m;if pv==provider and m[2]==model then has_current=true end
   end
   if pv==provider and not has_current then table.insert(rows,1,{model.." (gespeichert)",model}) end
   for _,m in ipairs(rows) do
    if query=="" or (pv.." "..m[1].." "..m[2]):lower():find(query,1,true) then
     count=count+1
     local available=reaper.ImGui_GetContentRegionAvail(ctx)
     -- Identity uses provider + model ID, independent of shortened/duplicate names.
     local label=fit_label(m[1],math.max(1,available-30)).."###model_"..pv.."/"..m[2]
     if reaper.ImGui_MenuItem(ctx,label,nil,provider==pv and model==m[2],not busy) then select_model(pv,m[2]) end
    end
   end
   end
  end
  if count==0 then reaper.ImGui_TextWrapped(ctx,"Keine passenden Modelle. Suche ändern oder Liste aktualisieren.") end
  reaper.ImGui_EndChild(ctx)
 end
 if workflow_adapter.models.message~="" then reaper.ImGui_TextWrapped(ctx,workflow_adapter.models.message) end
 reaper.ImGui_EndPopup(ctx)
end
local function draw_workflow_status()
 local width=reaper.ImGui_GetContentRegionAvail(ctx)
 if workflow_adapter.pending then
  reaper.ImGui_TextWrapped(ctx,"Vorschlag: "..(workflow_adapter.labels[workflow_adapter.pending.stage] or "Musik").." · "..(workflow_adapter.states[workflow_adapter.pending.state] or ""))
  if reaper.ImGui_Button(ctx,"Änderungen anwenden",width) then workflow_adapter.apply() end
 end
 if update_status~="" then reaper.ImGui_TextWrapped(ctx,update_status) end
end
local function draw_history()
 if history_mode then
  reaper.ImGui_TextWrapped(ctx,"Gespeicherte Ergebnisse (ohne neuen KI-Aufruf)")
  for i=#workflow_adapter.records,1,-1 do local r=workflow_adapter.records[i]
   local width=reaper.ImGui_GetContentRegionAvail(ctx)
   local label=(r.created or "").." · "..(workflow_adapter.labels[r.stage] or r.stage).." · "..(workflow_adapter.states[r.state] or r.state)
   if reaper.ImGui_Button(ctx,fit_label(label,math.max(1,width-20)).."##result"..i,width) then
    if r.stage=="analysis" then workflow_adapter.analysis=r else workflow_adapter.pending=r end
    add("Arbeitsstand",r.song_summary or workflow_core.readable(r.raw_response)); history_mode=false
   end
  end
 end
 if info_visible then reaper.ImGui_TextWrapped(ctx,info_text()); return end; local flags=0; if type(reaper.ImGui_InputTextFlags_ReadOnly)=="function" then flags=flags|reaper.ImGui_InputTextFlags_ReadOnly() end; if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then flags=flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end; local avail=select(1,reaper.ImGui_GetContentRegionAvail(ctx)); local limit=math.max(18,math.floor((avail-24)/9.5)); for i=chat_start,#history do local m=history[i]; reaper.ImGui_Text(ctx,m.role..":"); local text=wrap_text(m.text or "",limit); local lines=1; for _ in text:gmatch("\n") do lines=lines+1 end; local height=math.max(math.floor(48*font_size/14),math.min(math.floor(260*font_size/14),lines*math.floor(font_size*1.57)+math.floor(12*font_size/14))); reaper.ImGui_InputTextMultiline(ctx,"##chatmsg"..i,text,-1,height,flags); text_context_menu("##chat_context"..i,text,false); reaper.ImGui_Spacing(ctx) end; if history_mode then reaper.ImGui_Separator(ctx); if reaper.ImGui_Button(ctx,"Verlauf löschen") then clear_saved_history() end end end
local function remember_closed() save_history(); reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"0",true) end
local function check_project_change() local p=reaper.EnumProjects(-1,""); if p~=current_project then save_history(current_project); current_project=p; load_history(current_project); workflow_adapter.history_error=false; workflow_adapter.load() end end
local function loop() focused_or_last_notation_editor(); workflow_adapter.models.poll(); poll_update(); poll_job(); finish_save_panel(); if not open then if not restarting then remember_closed() end; return end; check_project_change(); reaper.ImGui_SetNextWindowSize(ctx,360,620,reaper.ImGui_Cond_FirstUseEver()); reaper.ImGui_SetNextWindowSizeConstraints(ctx,360,480,10000,10000); local visible; visible,open=reaper.ImGui_Begin(ctx,"Studio v"..VERSION.."###CompositionStudioMain",open); if visible then local pushed=push_font(); local items=selected_items(false); local tracks=selected_tracks(); reaper.ImGui_Text(ctx,"Studio"); reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A-") then set_font_size(font_size-1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A+") then set_font_size(font_size+1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"...") then reaper.ImGui_OpenPopup(ctx,"##studio_menu") end; if reaper.ImGui_BeginPopup(ctx,"##studio_menu") then if reaper.ImGui_MenuItem(ctx,"Info") then info_visible=true; history_mode=false end; if reaper.ImGui_MenuItem(ctx,"Kostenübersicht") then costs.show() end; if reaper.ImGui_MenuItem(ctx,"Kostenpreise einstellen ...") then costs.edit_rate() end;
if reaper.ImGui_MenuItem(ctx,"Komponieren: Konzeption + Komposition"..(composition_mode=="concept" and " ✓" or "")) then composition_mode="concept"; reaper.SetExtState(EXT_SECTION,COMPOSITION_MODE_KEY,composition_mode,true); update_status="Verfahren: Konzeption + Komposition (2 KI-Aufrufe)." end
if reaper.ImGui_MenuItem(ctx,"Komponieren: Direktes JSON"..(composition_mode=="direct" and " ✓" or "")) then composition_mode="direct"; reaper.SetExtState(EXT_SECTION,COMPOSITION_MODE_KEY,composition_mode,true); update_status="Verfahren: Direktes JSON (1 KI-Aufruf)." end
if reaper.ImGui_MenuItem(ctx,"Schrift kleiner (A-)") then set_font_size(font_size-1) end
if reaper.ImGui_MenuItem(ctx,"Schrift größer (A+)") then set_font_size(font_size+1) end
if reaper.ImGui_MenuItem(ctx,"Schrift Standard (14)") then set_font_size(14) end; if reaper.ImGui_MenuItem(ctx,"MIDI exportieren …") then export_last_midi() end; if reaper.ImGui_MenuItem(ctx,"SWAM-MIDI exportieren …") then export_swam_midi() end; if reaper.ImGui_MenuItem(ctx,"Diagnose speichern …") then save_diagnosis() end; if reaper.ImGui_MenuItem(ctx,"LilyPond-Pfad einstellen ...") then set_lily_exe() end; if reaper.ImGui_MenuItem(ctx,"Notenansicht vorbereiten") then local ok,msg=open_score_workspace(); add("KI",msg) end; if reaper.ImGui_MenuItem(ctx,"Piano-Roll öffnen") then local ok,msg=open_score_workspace("pianoroll"); add("KI",msg) end; if reaper.ImGui_MenuItem(ctx,"Update") then install_update() end; reaper.ImGui_Separator(ctx); if reaper.ImGui_MenuItem(ctx,"OpenAI API-Key ...") then edit_key("openai") end; if reaper.ImGui_MenuItem(ctx,"Anthropic API-Key ...") then edit_key("anthropic") end; if reaper.ImGui_MenuItem(ctx,"Google API-Key ...") then edit_key("google") end; reaper.ImGui_EndPopup(ctx) end; local model_width=reaper.ImGui_GetContentRegionAvail(ctx); draw_model_picker(model_width)
if reaper.ImGui_Button(ctx,"Denken: "..REASONING_LABELS[reasoning_mode].." v##reasoning",model_width) and not busy then reaper.ImGui_OpenPopup(ctx,"##reasoning_menu") end
if reaper.ImGui_BeginPopup(ctx,"##reasoning_menu") then
 for _,choice in ipairs({"low","medium","high","auto"}) do
  if reaper.ImGui_MenuItem(ctx,REASONING_LABELS[choice],nil,reasoning_mode==choice,not busy) then set_reasoning_mode(choice) end
 end
 reaper.ImGui_TextWrapped(ctx,"Automatisch verwendet die Modellvorgabe. Die Wirkung der Stufen hängt vom Modell ab.")
 if provider=="google" and model:match("^gemini%-2%.5") then reaper.ImGui_TextWrapped(ctx,"Gemini 2.5: Kurz / Mittel / Hoch entsprechen Denkbudgets von 2048 / 8192 / 24576 Tokens.") end
 reaper.ImGui_EndPopup(ctx)
end

-- Update feedback must remain visible even when the conversation is scrolled.
if update_job then reaper.ImGui_Text(ctx,"Update wird geladen …") end
-- Keep variable-height messages inside the scrolling conversation.
reaper.ImGui_Separator(ctx)
local w,h=reaper.ImGui_GetContentRegionAvail(ctx)
local scale=font_size/14
local _,spacing=reaper.ImGui_GetStyleVar(ctx,reaper.ImGui_StyleVar_ItemSpacing())
spacing=spacing or 4
local bh=math.max(reaper.ImGui_GetFrameHeight(ctx),math.floor(34*scale+0.5))
local ih=math.min(math.floor(112*scale+0.5),math.max(bh*2,math.floor(h*0.32)))
local ch=math.max(1,h-ih-bh*2-spacing*5-2)
local child_visible=reaper.ImGui_BeginChild(ctx,"##chat",w,ch,reaper.ImGui_ChildFlags_Borders())
if child_visible then
 reaper.ImGui_TextWrapped(ctx,string.format("%d MIDI | %d Spur(en)",#items,#tracks))
 reaper.ImGui_TextWrapped(ctx,"Auftrag: "..costs.amount(costs.order).." · Gesamt: "..costs.amount(costs.total))
 if busy then reaper.ImGui_TextWrapped(ctx,job and (job.stage=="work_title" and "KI findet einen Werktitel …" or job.stage=="composition_music" and "KI komponiert …" or job.stage=="composition" and "MIDI wird erzeugt …" or job.stage=="summary" and "KI beschreibt das Stück …") or "KI arbeitet …") end
 draw_workflow_status()
 draw_history()
 reaper.ImGui_EndChild(ctx)
end
local input_flags=0
if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then input_flags=input_flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end
local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##request",input,w,ih,input_flags)
if changed then input=v end
input=text_context_menu("##request_context",input,true)
local gap=math.max(4,math.floor(6*scale))
local bw=math.max(1,(w-gap)/2)
if reaper.ImGui_Button(ctx,busy and "Warten…" or "Senden",bw,bh) and not busy then submit() end
reaper.ImGui_SameLine(ctx,0,gap)
if reaper.ImGui_Button(ctx,"Verlauf",bw,bh) then chat_start=1;info_visible=false;history_mode=true end
if reaper.ImGui_Button(ctx,"Chat leeren",bw,bh) then chat_start=#history+1;info_visible=false;history_mode=false end
reaper.ImGui_SameLine(ctx,0,gap)
if reaper.ImGui_Button(ctx,"Schließen",bw,bh) then open=false end
pop_font(pushed)
reaper.ImGui_End(ctx)
end
if open then reaper.defer(loop) elseif not restarting then remember_closed() end
end
loop()
