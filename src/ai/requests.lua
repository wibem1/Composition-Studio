local function ai_command(prompt,key)
 local timeout=600
 local thinking,requested=reasoning_parameters(provider,model,reasoning_mode)
 diag_set("reasoning_mode",reasoning_mode); diag_set("reasoning_requested",requested)
 local base=temp_path(); local rq,rs,cd=base..".json",base..".out",base..".code"; local body,url,headers,win_headers
 if provider=="openai" then body='{"model":"'..json_escape(model)..'","input":"'..json_escape(prompt)..'"'..thinking..'}'; url="https://api.openai.com/v1/responses"; win_headers={"Authorization: Bearer "..key,"Content-Type: application/json"}
 elseif provider=="anthropic" then body='{"model":"'..json_escape(model)..'","max_tokens":16000,"messages":[{"role":"user","content":"'..json_escape(prompt)..'"}]'..thinking..'}'; url="https://api.anthropic.com/v1/messages"; win_headers={"x-api-key: "..key,"anthropic-version: 2023-06-01","Content-Type: application/json"}
 else body='{"contents":[{"parts":[{"text":"'..json_escape(prompt)..'"}]}]'..thinking..'}'; url="https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent?key="..key; win_headers={"Content-Type: application/json"} end
 if not write_file(rq,body) then return nil,"Anfrage konnte nicht geschrieben werden: "..rq end
 if IS_WINDOWS then
  local script=windows_curl_script(nil,rq,rs,cd,win_headers,url,timeout)
  if not script then return nil,"PowerShell-Aufruf konnte nicht vorbereitet werden." end
  if not ps_launch(script,true) then os.remove(script); os.remove(rq); return nil,"Windows-Hintergrundprozess konnte nicht gestartet werden." end
 else
  headers=""; for _,h in ipairs(win_headers) do headers=headers.." -H "..shell_quote(h) end
  local pending=cd..".pending"
  local cmd="(/usr/bin/curl -sS --max-time "..timeout.." -o "..shell_quote(rs).." -w '%{http_code}' "..headers.." --data-binary @"..shell_quote(rq).." "..shell_quote(url).." > "..shell_quote(pending).." 2>/dev/null; cs_exit=$?; if [ \"$cs_exit\" -eq 28 ]; then printf '%s' TIMEOUT > "..shell_quote(pending).."; fi; mv "..shell_quote(pending).." "..shell_quote(cd)..") &"
  os.execute(cmd)
 end
 local a={rq=rq,rs=rs,cd=cd,provider=provider,model=model,reasoning_mode=reasoning_mode,reasoning_requested=requested,timeout_seconds=timeout,deadline=reaper.time_precise()+timeout+20}
 costs.start(a)
 return a,nil
end

local function ai_poll(a)
 local status=read_file(a.cd)
 if not status or trim(status)=="" then
  if reaper.time_precise()<a.deadline then return nil,nil,false end
  costs.record(a,read_file(a.rs))
  diag_set("api_status","TIMEOUT")
  diag_set("api_error","Zeitlimit / Hintergrundprozess ohne Statusdatei")
  return nil,"KI-Zeitlimit erreicht; siehe Diagnose und CompositionStudioTemp.",true
 end
 status=trim(status)
 local raw=read_file(a.rs)
 costs.record(a,raw)
 -- Don't retain access credentials: API responses do not include submitted keys.
 diag_set("api_status",status); diag_set("api_stop_reason",raw and (raw:match('"stop_reason"%s*:%s*"([^"]+)"') or raw:match('"finishReason"%s*:%s*"([^"]+)"') or raw:match('"finish_reason"%s*:%s*"([^"]+)"')) or "")
 if status=="TIMEOUT" then
  diag_set("api_error","Zeitlimit / KI-Antwort nicht vollständig eingetroffen")
  os.remove(a.rq);os.remove(a.rs);os.remove(a.cd)
  local usage=last_diag.usage_input_tokens and last_diag.usage_input_tokens~="" and "Vorliegende Verbrauchsdaten stehen in der Kostenübersicht." or "Verbrauch dieses Aufrufs ist unbekannt."
  return nil,"KI-Zeitlimit erreicht ("..tostring(a.timeout_seconds or 600).." Sekunden). Kein Ergebnis übernommen. Nicht automatisch erneut angefragt. "..usage,true
 end
 if status~="200" or not raw then
  local excerpt=(raw or ""):sub(1,1500)
  diag_set("api_response_excerpt",excerpt)
  diag_set("api_error","HTTP/Transport: "..status)
  os.remove(a.rq); os.remove(a.rs); os.remove(a.cd)
  return nil,"KI-Aufruf fehlgeschlagen ("..status.."): "..excerpt:sub(1,350),true
 end
 local stop_reason=raw:match('"stop_reason"%s*:%s*"([^"]+)"') or raw:match('"finishReason"%s*:%s*"([^"]+)"')
 if stop_reason=="max_tokens" or stop_reason=="MAX_TOKENS" or stop_reason=="length" then
  diag_set("api_error","Tokenlimit erreicht; unvollständige Komposition")
  os.remove(a.rq); os.remove(a.rs); os.remove(a.cd)
  return nil,"Die KI hat das Tokenlimit erreicht. Keine unvollständige Komposition importiert.",true
 end
 local result=a.provider=="openai" and response_text(raw) or first_text_field(raw)
 if not result or trim(result)=="" then
  diag_set("api_error","Antwortformat nicht erkannt ("..a.provider..")")
  diag_set("api_response_excerpt",raw:sub(1,1500))
  os.remove(a.rq); os.remove(a.rs); os.remove(a.cd)
  return nil,"KI-Antwort konnte nicht gelesen werden. Antwortanfang: "..raw:sub(1,350),true
 end
 diag_set("api_error","")
 os.remove(a.rq); os.remove(a.rs); os.remove(a.cd)
 return result,nil,true
end
local function log_communication(stage,kind,body)
 local prior=last_diag.communication_log or ""
 local entry=os.date("%Y-%m-%d %H:%M:%S").." ["..tostring(stage).."] "..kind.."\n"..tostring(body or "").."\n"
 diag_set("communication_log",prior..entry)
end
launch=function(stage,prompt,key,data)
 data=data or {}; data.workflow_guard=data.workflow_guard or workflow_adapter_guard(); data.workflow_provider=provider; data.workflow_model=model
-- BEGIN MUSIC WORKSPACE MEMORY
 if music_workspace and stage~="controller" and stage~="work_title" then
  local memory,why=music_workspace.context()
  if not memory then add("KI",why);busy=false;job=nil;return false end
  if memory~="" then prompt=prompt.."\n\n"..memory;data.music_memory_context=memory end
 end
-- END MUSIC WORKSPACE MEMORY
 prompt=workflow_core.prompt(stage=="analysis" and "analysis" or "common").."\n"..prompt
 if stage=="controller" or stage=="swam_interpretation" or stage=="work_title" then costs.begin() end; local _,requested=reasoning_parameters(provider,model,reasoning_mode); log_communication(stage,"APP → KI (Denkaufwand "..reasoning_mode.."; gesendet "..requested.."; Prompt; Modell "..tostring(model)..", Provider "..tostring(provider)..")",prompt)
 local a,e=ai_command(prompt,key); if not a then log_communication(stage,"FEHLER",e); add("KI",e); busy=false; job=nil; return false end; job={stage=stage,ai=a,key=key,data=data or {},project=reaper.EnumProjects(-1,"")}; return true end

