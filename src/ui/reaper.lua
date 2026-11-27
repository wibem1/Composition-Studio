-- Keep UI locals in their own function: the generated chunk has a 200-local limit.
;(function()
local function wrap_text(s,limit) limit=math.max(12,math.floor(limit or 40)); local out={}; for line in (tostring(s or "").."\n"):gmatch("(.-)\n") do while #line>limit do local cut=limit; local part=line:sub(1,limit); local sp=part:match("^.*()%s+"); if sp and sp>math.floor(limit*0.55) then cut=sp end; out[#out+1]=line:sub(1,cut):gsub("%s+$",""); line=line:sub(cut+1):gsub("^%s+","") end; out[#out+1]=line end; return table.concat(out,"\n"):gsub("\n$","") end
-- One chat session, with separate native window identities for the two views.
local studio_window = (function()
 local mode_key, bounds_key = "InterfaceMode", "StudioWindowBoundsV1"
 local view = {
  mode = reaper.GetExtState(EXT_SECTION,mode_key)=="studio" and "studio" or "compact",
  maximized = false,
 }
 local saved = reaper.GetExtState(EXT_SECTION,bounds_key)
 local x,y,w,h = saved:match("^(-?%d+) (-?%d+) (%d+) (%d+)$")
 if x and math.abs(tonumber(x))<=100000 and math.abs(tonumber(y))<=100000
  and tonumber(w)>=1 and tonumber(w)<=10000 and tonumber(h)>=1 and tonumber(h)<=10000 then
  view.bounds = {tonumber(x),tonumber(y),tonumber(w),tonumber(h)}
 end
 local restore = view.bounds~=nil
 local palette = {
  Text=0x18263AFF, TextDisabled=0x526477FF, WindowBg=0xF7F9FCFF,
  ChildBg=0xFFFFFFFF, PopupBg=0xFFFFFFFF, Border=0xA8B6C6FF,
  FrameBg=0xEDF2F8FF, FrameBgHovered=0xDDE9F5FF, FrameBgActive=0xCDDFF1FF,
  TitleBg=0xDCE6F0FF, TitleBgActive=0xCFDEECFF, TitleBgCollapsed=0xDCE6F0FF,
  Button=0xDCE8F5FF, ButtonHovered=0xC5DCF3FF, ButtonActive=0xA9C9E8FF,
  Header=0xE1ECF7FF, HeaderHovered=0xC5DCF3FF, HeaderActive=0xA9C9E8FF,
  Separator=0xA8B6C6FF, ScrollbarBg=0xEDF2F8FF, ScrollbarGrab=0x8EA4BAFF,
  ScrollbarGrabHovered=0x718DA8FF, ScrollbarGrabActive=0x5D7C9AFF,
  ResizeGrip=0x93AAC4C0, ResizeGripHovered=0x6489B4E0, ResizeGripActive=0x3F6795FF,
  TextSelectedBg=0x86B6E5A0, NavHighlight=0x346CA5FF, NavCursor=0x346CA5FF,
 }
 function view.toggle()
  view.mode = view.mode=="studio" and "compact" or "studio"
  reaper.SetExtState(EXT_SECTION,mode_key,view.mode,true)
 end
 function view.toggle_maximize()
  view.maximized = not view.maximized
  restore = not view.maximized and view.bounds~=nil
 end
 function view.prepare()
  if view.mode=="compact" then
   reaper.ImGui_SetNextWindowSize(ctx,360,620,reaper.ImGui_Cond_FirstUseEver())
   reaper.ImGui_SetNextWindowSizeConstraints(ctx,360,480,10000,10000)
   return "Studio v"..VERSION.."###CompositionStudioMain",0,0
  end
  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local ax,ay = reaper.ImGui_Viewport_GetWorkPos(viewport)
  local aw,ah = reaper.ImGui_Viewport_GetWorkSize(viewport)
  local minimum_w,minimum_h = 460,480
  view.can_maximize = aw>=minimum_w and ah>=minimum_h
  if not view.can_maximize and view.maximized then view.toggle_maximize() end
  local flags = reaper.ImGui_WindowFlags_NoDocking()
  if view.maximized then
   reaper.ImGui_SetNextWindowPos(ctx,ax,ay)
   reaper.ImGui_SetNextWindowSize(ctx,aw,ah)
   flags=flags|reaper.ImGui_WindowFlags_NoMove()|reaper.ImGui_WindowFlags_NoResize()
  elseif restore then
   local bx,by,bw,bh=table.unpack(view.bounds)
   reaper.ImGui_SetNextWindowPos(ctx,bx,by)
   reaper.ImGui_SetNextWindowSize(ctx,bw,bh)
   restore=false
  else
   reaper.ImGui_SetNextWindowSize(ctx,math.min(960,math.max(minimum_w,aw)),math.min(760,math.max(minimum_h,ah)),reaper.ImGui_Cond_FirstUseEver())
  end
  reaper.ImGui_SetNextWindowSizeConstraints(ctx,minimum_w,minimum_h,10000,10000)
  local count=0
  for name,color in pairs(palette) do
   local index=reaper["ImGui_Col_"..name]
   if index then
    reaper.ImGui_PushStyleColor(ctx,index(),color)
    count=count+1
   end
  end
  return "Composition Studio v"..VERSION.."###CompositionStudioWorkspace",flags,count
 end
 function view.remember_bounds()
  if view.mode~="studio" or view.maximized then return end
  local bx,by=reaper.ImGui_GetWindowPos(ctx)
  local bw,bh=reaper.ImGui_GetWindowSize(ctx)
  view.bounds={bx,by,bw,bh}
  if reaper.ImGui_IsMouseDown(ctx,0) and open then return end
  local geometry=("%d %d %d %d"):format(math.floor(bx),math.floor(by),math.floor(bw),math.floor(bh))
  if geometry~=saved then
   reaper.SetExtState(EXT_SECTION,bounds_key,geometry,true)
   saved=geometry
  end
 end
 return view
end)()

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
 if workflow_adapter.pending and workflow_adapter.pending.state=="ready" then
  reaper.ImGui_TextWrapped(ctx,"Ergebnis bereit: "..(workflow_adapter.labels[workflow_adapter.pending.stage] or "Musik").." · "..(workflow_adapter.states[workflow_adapter.pending.state] or ""))
  if reaper.ImGui_Button(ctx,"Änderungen anwenden",width) then workflow_adapter.apply() end
 end
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
local function loop() focused_or_last_notation_editor(); workflow_adapter.models.poll(); poll_update(); poll_job(); finish_save_panel(); if not open then if not restarting then remember_closed() end; return end; check_project_change()
local is_studio=studio_window.mode=="studio"
local title,window_flags,theme_count=studio_window.prepare()
local visible
visible,open=reaper.ImGui_Begin(ctx,title,open,window_flags)
if visible then
 studio_window.remember_bounds()
 local pushed=push_font()
 local items=selected_items(false)
 local tracks=selected_tracks()
 if reaper.ImGui_Button(ctx,studio_window.mode=="compact" and "Studioansicht" or "Kompaktansicht") then studio_window.toggle() end
 reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A-") then set_font_size(font_size-1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A+") then set_font_size(font_size+1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"...") then reaper.ImGui_OpenPopup(ctx,"##studio_menu") end; if reaper.ImGui_BeginPopup(ctx,"##studio_menu") then if is_studio and reaper.ImGui_MenuItem(ctx,studio_window.maximized and "Fenstergröße wiederherstellen" or "Studiofenster maximieren",nil,false,studio_window.can_maximize) then studio_window.toggle_maximize() end; if reaper.ImGui_MenuItem(ctx,"Info") then info_visible=true; history_mode=false end; if reaper.ImGui_MenuItem(ctx,"Kostenübersicht") then costs.show() end; if reaper.ImGui_MenuItem(ctx,"KI-Komponenten…") then open_ai_components() end; if reaper.ImGui_MenuItem(ctx,"Kostenpreise einstellen ...") then costs.edit_rate() end;
if reaper.ImGui_MenuItem(ctx,"Komponieren: Konzeption + Komposition"..(composition_mode=="concept" and " ✓" or "")) then composition_mode="concept"; reaper.SetExtState(EXT_SECTION,COMPOSITION_MODE_KEY,composition_mode,true); update_status="Verfahren: Konzeption + Komposition (2 KI-Aufrufe)." end
if reaper.ImGui_MenuItem(ctx,"Komponieren: Direktes JSON"..(composition_mode=="direct" and " ✓" or "")) then composition_mode="direct"; reaper.SetExtState(EXT_SECTION,COMPOSITION_MODE_KEY,composition_mode,true); update_status="Verfahren: Direktes JSON (1 KI-Aufruf)." end
-- BEGIN WHOLE TRACK MENU
if reaper.ImGui_MenuItem(ctx,"Ganzer Track: Auftrag vorbereiten") and not busy then
 if not input:match("^[Gg]anzer%s+[Tt]rack:") then input="Ganzer Track: "..input end
 update_status="Ganze MIDI-Items oder Quellspuren auswählen, Auftrag ergänzen und Senden. Vorbereitung ohne KI-Aufruf."
end
-- END WHOLE TRACK MENU
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
-- The result action stays visible even if the conversation is scrolled.
draw_workflow_status()
-- Keep variable-height messages inside the scrolling conversation.
reaper.ImGui_Separator(ctx)
local w,h=reaper.ImGui_GetContentRegionAvail(ctx)
local scale=font_size/14
local _,spacing=reaper.ImGui_GetStyleVar(ctx,reaper.ImGui_StyleVar_ItemSpacing())
spacing=spacing or 4
local bh=math.max(reaper.ImGui_GetFrameHeight(ctx),math.min(math.floor(34*scale+0.5),math.floor(h/5)))
local ih=math.min(math.floor(112*scale+0.5),math.max(bh*2,math.floor(h*0.32)))
local ch=math.max(1,h-ih-bh*2-spacing*5-2)
local child_visible=reaper.ImGui_BeginChild(ctx,"##chat",w,ch,reaper.ImGui_ChildFlags_Borders())
if child_visible then
 reaper.ImGui_TextWrapped(ctx,string.format("%d MIDI | %d Spur(en)",#items,#tracks))
 reaper.ImGui_TextWrapped(ctx,"Auftrag: "..costs.amount(costs.order).." · Gesamt: "..costs.amount(costs.total))
 if busy then reaper.ImGui_TextWrapped(ctx,job and (job.stage=="work_title" and "KI findet einen Werktitel …" or job.stage=="composition_music" and "KI komponiert …" or job.stage=="composition" and "MIDI wird erzeugt …" or job.stage=="summary" and "KI beschreibt das Stück …") or "KI arbeitet …") end
-- BEGIN WHOLE TRACK STATUS
 if whole_track and job and (job.stage=="whole_track_plan" or job.stage=="whole_track_window") then
  reaper.ImGui_TextWrapped(ctx,update_status)
  if reaper.ImGui_Button(ctx,"Track-Aufbau anhalten") then whole_track.cancel() end
 end
-- END WHOLE TRACK STATUS
 if update_status~="" then reaper.ImGui_TextWrapped(ctx,update_status) end
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
if ai_component_manager.open then
 local visible,keep_open=reaper.ImGui_Begin(ctx,"KI-Komponenten###CompositionStudioAIComponents",ai_component_manager.open)
 ai_component_manager.open=keep_open
 if visible then draw_ai_components(ctx) end
 reaper.ImGui_End(ctx)
end
if theme_count>0 then reaper.ImGui_PopStyleColor(ctx,theme_count) end
if open then reaper.defer(loop) elseif not restarting then remember_closed() end
end
loop()
end)()
