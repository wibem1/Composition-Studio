local function begin_continuation(request,bars,tail)
 if type(bars)~="number" or bars~=math.floor(bars) or bars<1 or bars>128 or (tail~=0 and tail~=2 and tail~=3 and tail~=4) then
  add("KI","Bitte eine Verlängerung von 1 bis 128 Takten und gegebenenfalls 2, 3 oder 4 Übergangstakte angeben.");busy=false;return
 end
 local lower=request:lower()
 if (lower:find("markiert",1,true) or lower:find("ausgewählt",1,true)) and lower:find("noten",1,true) then
  add("KI","Fortsetzung einzelner markierter Noten ist noch nicht freigegeben. Bitte ausdrücklich die Partitur, den Piano-Roll oder Arrangement-Items als Quelle wählen.");busy=false;return
 end
 local tracks=selected_tracks()
 local context=selected_items(true,"items")
 -- An explicit score-workspace command must not silently fall back to the
 -- current arrangement item selection, even when items are selected there.
 if score_request_intent(request:lower()) then
  local visible,why=notation_visible_items(true)
  if not visible then add("KI",why);busy=false;return end
  context=visible; tracks=score_context_tracks(context)
 end
 if #context==0 and #tracks>0 then context=track_context_items(tracks) end
 if #context==0 then add("KI","Bitte die MIDI-Items oder Spuren des vorhandenen Stücks auswählen.");busy=false;return end
 local endpoint=0;for _,it in ipairs(context) do endpoint=math.max(endpoint,it.end_qn or 0) end
 if endpoint<=0 then add("KI","Ende des Ausgangsstücks nicht gefunden.");busy=false;return end
 local ok,start=pcall(workflow_adapter.transition,context,endpoint,tail)
 if not ok then add("KI",tostring(start));busy=false;return end
 local key=get_key()
 if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar.");busy=false;return end
 last_diag={version=VERSION,composition_engine=COMPOSITION_ENGINE_NAME.." "..COMPOSITION_ENGINE_VERSION,composition_engine_build=tostring(COMPOSITION_ENGINE_BUILD),provider=provider,model=model,request=request}
 diag_set("context",compact_context(context,tracks,false));diag_set("continuation_start_qn",tostring(start));diag_set("continuation_bars",tostring(bars));diag_set("transition_bars",tostring(tail))
 local total=bars+tail
 local prompt=workflow_core.prompt("continue").."\n"..continuation_prompt(request,context,tracks,total,start)
 if tail>0 then prompt=prompt.."\nDie ersten "..tail.." Takte ersetzen die freigegebenen Schlusstakte; danach exakt "..bars.." NEUE Takte. Früheren Verlauf nicht erneut ausgeben." end
 diag_set("composition_prompt",prompt)
 launch("lily_continuation",prompt,key,{request=request,extension_start=start,extension_bars=total,transition_bars=tail,full=context,music_tracks=tracks})
end

