-- Dynamic provider catalog; cached IDs are data, never executable code.
workflow_adapter.models={job=nil,message="",filter="",view_provider=provider,show_all=false,
 featured={openai=MODELS.openai,anthropic=MODELS.anthropic,google=MODELS.google}}
function workflow_adapter.models.report(text,notify)
 workflow_adapter.models.message=text;update_status=text
 if notify then reaper.ShowMessageBox(text,SCRIPT_NAME.." – Modelle",0) end
end
function workflow_adapter.models.parse(pv,value)
 local source=pv=="google" and value.models or value.data
 assert(type(source)=="table","Die Modellliste konnte nicht gelesen werden.")
 local out={}
 for _,m in ipairs(source) do
  local id=tostring(pv=="google" and m.name or m.id or ""):gsub("^models/","")
  local allowed=id~=""
  if pv=="google" then allowed=false; for _,method in ipairs(m.supportedGenerationMethods or {}) do if method=="generateContent" then allowed=true end end end
  if pv=="openai" then for _,term in ipairs({"embedding","moderation","image","audio","realtime","transcribe","tts","whisper","dall-e","sora"}) do if id:lower():find(term,1,true) then allowed=false end end end
  if allowed then out[#out+1]={tostring(m.display_name or m.displayName or id),id} end
 end
 local next_page=pv=="google" and value.nextPageToken or pv=="anthropic" and value.has_more and value.last_id or nil
 if next_page==false or next_page=="" then next_page=nil end
 return out,next_page
end
function workflow_adapter.models.page(j,token)
 local url,headers
 if j.provider=="openai" then url="https://api.openai.com/v1/models";headers={"Authorization: Bearer "..j.key}
 elseif j.provider=="anthropic" then url="https://api.anthropic.com/v1/models?limit=1000"..(token and "&after_id="..enc(token) or "");headers={"x-api-key: "..j.key,"anthropic-version: 2023-06-01"}
 else url="https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000"..(token and "&pageToken="..enc(token) or "");headers={"x-goog-api-key: "..j.key} end
 local output,code=temp_path(".models.json"),temp_path(".models.code")
 j.output=output;j.code=code;j.deadline=reaper.time_precise()+30
 if IS_WINDOWS then
  local script=windows_curl_script(nil,nil,output,code,headers,url,20);j.script=script
  assert(script and ps_launch(script,true),"Modellabfrage konnte nicht gestartet werden.")
 else
  -- Store the secret header in a private curl config, not in the command line.
  local config=temp_path(".curl-config");j.config=config
  local f=assert(io.open(config,"wb")); for _,h in ipairs(headers) do f:write('header = "'..h:gsub('\\','\\\\'):gsub('"','\\"')..'"\n') end;f:close()
  local cmd="umask 077; chmod 600 "..shell_quote(config).."; /usr/bin/curl --config "..shell_quote(config).." -sS --connect-timeout 10 --max-time 20 -o "..shell_quote(output).." -w '%{http_code}' "..shell_quote(url).." > "..shell_quote(code..".pending").."; rm -f "..shell_quote(config).."; mv "..shell_quote(code..".pending").." "..shell_quote(code)
  j.script=assert(unix_launch_script(cmd))
 end
 workflow_adapter.models.job=j
end
function workflow_adapter.models.refresh(quiet,catalog_provider)
 local pv=catalog_provider or provider
 if not MODELS[pv] then return end
 local title=pv=="openai" and "OpenAI" or pv=="anthropic" and "Anthropic" or "Google"
 if busy then
  if not quiet then workflow_adapter.models.report("Bitte den laufenden Auftrag abwarten.",true) end
  return
 end
 if workflow_adapter.models.job then return end
 local key=trim(reaper.GetExtState(EXT_SECTION,KEY_NAMES[pv]))
 if not key or key=="" then
  workflow_adapter.models.report("Für "..title.." fehlt der API-Key. Im Studio-Menü hinterlegen.",false)
  return
 end
 local j={provider=pv,key=key,rows={},seen={},quiet=quiet}
 local ok,err=pcall(workflow_adapter.models.page,j)
 if ok then workflow_adapter.models.report("Verfügbare Modelle für "..title.." werden eingelesen …",false)
 else
  if j.config then os.remove(j.config) end
  if j.script then os.remove(j.script) end
  workflow_adapter.models.report("Modellabfrage konnte nicht gestartet werden. Bitte erneut versuchen.",not quiet)
 end
end
function workflow_adapter.models.poll()
 local j=workflow_adapter.models.job; if not j then return end
 local status=read_file(j.code)
 if not status and reaper.time_precise()<j.deadline then return end
 workflow_adapter.models.job=nil
 local raw=read_file(j.output);os.remove(j.code);os.remove(j.output)
 if j.config then os.remove(j.config) end
 if j.script then os.remove(j.script) end
 if trim(status or "")~="200" then
  local code=trim(status or "Zeitlimit")
  local hint=(code=="401" or code=="403") and " Bitte API-Key und Zugriffsrechte prüfen." or code=="429" and " Bitte später erneut versuchen." or ""
  workflow_adapter.models.report("Modellabfrage fehlgeschlagen ("..code..")."..hint.." Bisherige Auswahl bleibt verfügbar.",not j.quiet)
  return
 end
 local ok,err=pcall(function()
  local page,next_page=workflow_adapter.models.parse(j.provider,decode_engine_json(raw or ""))
  for _,row in ipairs(page) do if not j.seen[row[2]] then j.seen[row[2]]=true;j.rows[#j.rows+1]=row end end
  if next_page then assert(not j.seen["page:"..next_page],"Wiederholte Modellseite");j.seen["page:"..next_page]=true;workflow_adapter.models.page(j,next_page);return end
  assert(#j.rows>0,"Keine passenden Textmodelle zurückgegeben.")
  table.sort(j.rows,function(a,b)return a[1]<b[1] end)
  MODELS[j.provider]=j.rows
  reaper.SetExtState(EXT_SECTION,"ModelCatalogV1-"..j.provider,workflow_adapter.encode(j.rows),true)
  workflow_adapter.models.report(tostring(#j.rows).." verfügbare Modelle eingelesen.",false)
 end)
 if not ok then
  if j.config then os.remove(j.config) end
  if j.script then os.remove(j.script) end
  workflow_adapter.models.report("Die Modellantwort konnte nicht gelesen werden. Bisherige Auswahl bleibt verfügbar.",not j.quiet)
 end
end
for _,pv in ipairs({"openai","anthropic","google"}) do
 local raw=reaper.GetExtState(EXT_SECTION,"ModelCatalogV1-"..pv)
 if raw~="" then local ok,rows=pcall(decode_engine_json,raw);if ok and type(rows)=="table" and #rows>0 then MODELS[pv]=rows end end
end

-- End shared workflow host adapter.

