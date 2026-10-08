-- @description Composition Studio
-- @version 1.0.50
-- @author Klangwerke
-- @about Dockable AI chat, controlled REAPER actions and MIDI composition.

local SCRIPT_NAME="Composition Studio"
local VERSION="1.0.50"
local EXT_SECTION="CompositionStudio"
local COMPOSITION_ENGINE_NAME="Composition Engine"
local COMPOSITION_ENGINE_VERSION="2.3.1"
local COMPOSITION_ENGINE_BUILD=231
local PROVIDER_KEY,MODEL_KEY="AIProvider","AIModel"
local KEY_NAMES={openai="OpenAIAPIKey",anthropic="AnthropicAPIKey",google="GoogleAPIKey"}
local MODELS={openai={{"GPT-5.6 Sol","gpt-5.6-sol"},{"GPT-5.6 Terra","gpt-5.6-terra"},{"GPT-5.6 Luna","gpt-5.6-luna"}},anthropic={{"Claude Fable 5","claude-fable-5"},{"Claude Sonnet 5","claude-sonnet-5"},{"Claude Opus 5","claude-opus-5"}},google={{"Gemini 3.8 Flash","gemini-3.8-flash"},{"Gemini 3.1 Pro","gemini-3.1-pro-preview"},{"Gemini 2.5 Pro","gemini-2.5-pro"}}}
local provider=reaper.GetExtState(EXT_SECTION,PROVIDER_KEY); if provider=="" or not MODELS[provider] then provider="openai" end
local model=reaper.GetExtState(EXT_SECTION,MODEL_KEY); if model=="" then model=MODELS[provider][1][2] end
local WINDOW_STATE_KEY,HISTORY_KEY="WindowOpen","HistoryV1"
local TITLE_KEY="LastWorkTitle"
local work_title=reaper.GetProjExtState(0,EXT_SECTION,TITLE_KEY); if type(work_title)=="number" then local _,v=reaper.GetProjExtState(0,EXT_SECTION,TITLE_KEY); work_title=v end; work_title=tostring(work_title or ""):gsub("^%s+",""):gsub("%s+$","")
local UPDATE_URL="https://raw.githubusercontent.com/wibem1/Composition-Studio/main/Composition%20Studio.lua"
local SCRIPT_PATH=(debug.getinfo(1,"S").source or ""):gsub("^@","")
local SCOREFLOW_COMMIT="b2d86a085504c5ac85bdf5f302167d4c79de50e2"
local SCOREFLOW_HOST_PATH=reaper.GetResourcePath().."/Composition-Studio-ScoreFlow.html"

local function ensure_native_startup_hook()
 local p=reaper.GetResourcePath().."/Scripts/__startup.lua"
 local mark="-- BEGIN COMPOSITION STUDIO AUTO START"
 local f=io.open(p,"rb"); local old=f and (f:read("*a") or "") or ""; if f then f:close() end
 -- Replace old hard-coded startup paths rather than preserving a stale hook.
 old=old:gsub("%-%- BEGIN COMPOSITION STUDIO AUTO START.-%-%- END COMPOSITION STUDIO AUTO START%s*","")
 local block=[[
-- BEGIN COMPOSITION STUDIO AUTO START
do
 if reaper.GetExtState("CompositionStudio","WindowOpen")=="1" then
  local script=reaper.GetExtState("CompositionStudio","ActiveScriptPath")
  local f=script~="" and io.open(script,"rb") or nil
  if f then f:close(); pcall(dofile,script) end
 end
end
-- END COMPOSITION STUDIO AUTO START
]]
 local w=io.open(p,"wb")
 if w then if old~="" and old:sub(-1)~="\n" then old=old.."\n" end; w:write(old..block); w:close() end
end
reaper.SetExtState(EXT_SECTION,"ActiveScriptPath",SCRIPT_PATH,true)
ensure_native_startup_hook()
if type(reaper.ImGui_CreateContext)~="function" then reaper.ShowMessageBox("Composition Studio benötigt ReaImGui.",SCRIPT_NAME,0); return end
local ctx=reaper.ImGui_CreateContext(SCRIPT_NAME,reaper.ImGui_ConfigFlags_DockingEnable())
if type(reaper.ImGui_SetConfigVar)=="function" and type(reaper.ImGui_ConfigVar_DockingNoSplit)=="function" then reaper.ImGui_SetConfigVar(ctx,reaper.ImGui_ConfigVar_DockingNoSplit(),1) end
reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"1",true)
local open,input,busy=true,"",false; local last_made={}; local swam_last_made={}; local last_diag={}; local restarting=false; local update_status=""; local history={}; local chat_start=1; local info_visible=false; local history_mode=false; local notation_status=""; local score_state={items={},notes={},selected=0,selection_signature=""}; local score_bridge_seq=""; local current_project=reaper.EnumProjects(-1,""); local font=nil
if type(reaper.ImGui_CreateFont)=="function" then local ok,f=pcall(reaper.ImGui_CreateFont,"sans-serif"); if ok then font=f end end
if font and type(reaper.ImGui_Attach)=="function" then pcall(reaper.ImGui_Attach,ctx,font) end
local function push_font() if not font then return false end; return pcall(reaper.ImGui_PushFont,ctx,font,18) end
local function pop_font(x) if x then reaper.ImGui_PopFont(ctx) end end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function safe_work_title(t)
 t=trim(t):gsub("[\r\n]"," "):gsub("[/\\:]","-"):gsub("%s+"," "):gsub("^%.*",""):gsub("%.*$","")
 if #t>80 then t=t:sub(1,80):gsub("%s+$","") end
 return t
end
local function title_from_draft(draft,request)
 local t=tostring(draft or ""):match("^[Tt][Ii][Tt][Ee][Ll]%s*:%s*([^\n\r]+)") or tostring(draft or ""):match("^[Ww][Ee][Rr][Kk][Tt][Ii][Tt][Ee][Ll]%s*:%s*([^\n\r]+)")
 t=safe_work_title(t or "")
 return t
end
local IS_WINDOWS=reaper.GetOS():match("Win")~=nil
local function shell_quote(s)
 s=tostring(s)
 if IS_WINDOWS then return '"'..s:gsub('"','\\"')..'"' end
 return "'"..s:gsub("'","'\\''").."'"
end
local function ps_quote(s) return "'"..tostring(s):gsub("'","''").."'" end
local TEMP_DIR=reaper.GetResourcePath().."/CompositionStudioTemp"
reaper.RecursiveCreateDirectory(TEMP_DIR,0)
local temp_seq=0
local function temp_path(ext)
 temp_seq=temp_seq+1
 return TEMP_DIR.."/cs_"..os.time().."_"..temp_seq..(ext or "")
end
-- Launch directly through REAPER: no cmd.exe/start and no PATH-selected curl.
local function ps_launch(path,background)
 local root=os.getenv("SystemRoot") or "C:/Windows"
 local exe=root.."/System32/WindowsPowerShell/v1.0/powershell.exe"
 local ok,result=pcall(reaper.ExecProcess,shell_quote(exe)..' -NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File '..shell_quote(path),-2)
 return ok and result~=nil
end
local function windows_curl_script(body,request_file,output_file,code_file,method_headers,url,timeout)
 local script=temp_path(".ps1")
 local h={"$ErrorActionPreference = 'Stop'", "$code = '000'", "$client = $null", "try {",
 "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12",
 "Add-Type -AssemblyName System.Net.Http", "$client = New-Object System.Net.Http.HttpClient",
 "$client.Timeout = [TimeSpan]::FromSeconds("..tostring(timeout or 180)..")",
 "$request = New-Object System.Net.Http.HttpRequestMessage",
 "$request.RequestUri = [Uri]"..ps_quote(url),
 "$request.Method = [System.Net.Http.HttpMethod]::"..(request_file and "Post" or "Get")}
 if request_file then
  h[#h+1]="$request.Content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,[IO.File]::ReadAllBytes("..ps_quote(request_file).."))"
  h[#h+1]="$request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json')"
 end
 h[#h+1]="$null = $request.Headers.TryAddWithoutValidation('User-Agent','CompositionStudio/1.0.50')"
 for _,v in ipairs(method_headers) do
  local name,value=v:match("^([^:]+):%s*(.*)$")
  if name and name:lower()~="content-type" then h[#h+1]="$null = $request.Headers.TryAddWithoutValidation("..ps_quote(name)..","..ps_quote(value)..")" end
 end
 h[#h+1]="$response = $client.SendAsync($request).GetAwaiter().GetResult()"
 h[#h+1]="$bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()"
 h[#h+1]="[IO.File]::WriteAllBytes("..ps_quote(output_file)..",$bytes)"
 h[#h+1]="$code = [string][int]$response.StatusCode"
 h[#h+1]="} catch { $code = 'TRANSPORT_ERROR: ' + $_.Exception.Message; [IO.File]::WriteAllText("..ps_quote(output_file)..",($_ | Out-String)) } finally {"
 h[#h+1]="if ($client) { $client.Dispose() }"
 h[#h+1]="[IO.File]::WriteAllText("..ps_quote(code_file..".pending")..",$code)"
 h[#h+1]="Move-Item -LiteralPath "..ps_quote(code_file..".pending").." -Destination "..ps_quote(code_file).." -Force"
 if request_file then h[#h+1]="Remove-Item -LiteralPath "..ps_quote(request_file).." -ErrorAction SilentlyContinue" end
 h[#h+1]="Remove-Item -LiteralPath "..ps_quote(script).." -ErrorAction SilentlyContinue"
 h[#h+1]="}"
 local f=io.open(script,"wb"); if not f then return nil end
 f:write("\239\187\191"..table.concat(h,"\r\n")); f:close(); return script
end
local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(p,s) local f=io.open(p,"wb"); if not f then return false end; f:write(s); f:close(); return true end
local function version_parts(v)
 local a,b,c=tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)$")
 if a then return tonumber(a),tonumber(b),tonumber(c) end
 local x,y,t=tostring(v or ""):match("^(%d+)%.(%d+)%-test(%d+)$")
 if x then return tonumber(x),tonumber(y),tonumber(t) end
 return nil,nil,nil
end

local function version_is_newer(remote,localv)
 local a,b,c=version_parts(remote)
 local x,y,z=version_parts(localv)
 if not (a and x) then return false end
 if a~=x then return a>x end
 if b~=y then return b>y end
 return c>z
end

local update_job=nil
local function fetch_update(url,raw)
 local tmp,code=temp_path(".lua"),temp_path(".code")
 local headers={"Cache-Control: no-cache","Pragma: no-cache"}
 if raw then headers[#headers+1]="Accept: application/vnd.github.raw+json" end
 local script
 if IS_WINDOWS then
  script=windows_curl_script(nil,nil,tmp,code,headers,url,60)
  if not script or not ps_launch(script,true) then if script then os.remove(script) end; return nil end
 else
  local cmd="/usr/bin/curl -sS -L --connect-timeout 15 --max-time 60"
  for _,h in ipairs(headers) do cmd=cmd.." -H "..shell_quote(h) end
  cmd=cmd.." -o "..shell_quote(tmp).." -w '%{http_code}' "..shell_quote(url).." > "..shell_quote(code..".pending").."; mv "..shell_quote(code..".pending").." "..shell_quote(code)
  reaper.ExecProcess("/bin/sh -c "..shell_quote(cmd),-2)
 end
 return {rs=tmp,cd=code,script=script,deadline=reaper.time_precise()+75}
end
local function install_update()
 if busy then return end
 busy=true; update_status="Update wird im Hintergrund geprüft …"
 update_job=fetch_update("https://api.github.com/repos/wibem1/Composition-Studio/contents/Composition%20Studio.lua?ref=main&nocache="..os.time(),true)
 if not update_job then busy=false; update_status="Update-Prozess konnte nicht gestartet werden." end
end
local function complete_update(status,fresh)
 local rv=fresh and fresh:match("%-%- @version%s+([%w%.%-]+)") or nil
 if status~="200" or not fresh or #fresh<1000 then
  update_status="Update fehlgeschlagen (HTTP "..tostring(status)..")."
  busy=false
  return
 end
 if not rv or not fresh:find('local SCRIPT_NAME="Composition Studio"',1,true) then
  update_status="Update abgebrochen: heruntergeladene Datei ist ungültig."
  busy=false
  return
 end
 if rv==VERSION then
  update_status="Bereits aktuell: "..VERSION
  busy=false
  return
 end
 if not version_is_newer(rv,VERSION) then
  update_status="Kein neueres Update verfügbar. Lokal: "..VERSION..", GitHub: "..rv
  busy=false
  return
 end

 local compiled,syntax_error=load(fresh,"@Composition Studio update","t")
 if not compiled then
  update_status="Update abgebrochen: Lua-Syntaxfehler: "..tostring(syntax_error)
  busy=false
  return
 end

 local previous=read_file(SCRIPT_PATH)
 local staged=SCRIPT_PATH..".pending"
 if not previous or not write_file(SCRIPT_PATH..".backup",previous) or not write_file(staged,fresh) or read_file(staged)~=fresh then
  os.remove(staged); update_status="Update konnte nicht sicher vorbereitet werden."; busy=false; return
 end
 -- Windows cannot rename over an existing file; retain the original until staging passes.
 local rollback=SCRIPT_PATH..".rollback"
 os.remove(rollback)
 local moved=os.rename(SCRIPT_PATH,rollback)
 local installed=moved and os.rename(staged,SCRIPT_PATH)
 if not installed then
  if moved then os.rename(rollback,SCRIPT_PATH) end
  os.remove(staged); update_status="Update fehlgeschlagen; Rückfallkopie: "..SCRIPT_PATH..".backup"; busy=false; return
 end
 os.remove(rollback)
 update_status="Update auf "..rv.." installiert. Neustart …"
 restarting=true; open=false; busy=false
 reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"1",true)
 reaper.defer(function() local ok,e=pcall(dofile,SCRIPT_PATH); if not ok then reaper.ShowMessageBox(tostring(e),SCRIPT_NAME,0) end end)
end

local function poll_update()
 local j=update_job; if not j then return end
 local status=read_file(j.cd)
 if not status and reaper.time_precise()<j.deadline then return end
 local fresh=read_file(j.rs); os.remove(j.rs); os.remove(j.cd)
 update_job=nil
 if (trim(status)~="200" or not fresh or not fresh:match("%-%- @version%s+")) and not j.fallback then
  update_job=fetch_update(UPDATE_URL.."?version_check="..os.time(),false)
  if update_job then update_job.fallback=true; return end
 end
 complete_update(trim(status)=="" and "TIMEOUT" or trim(status),fresh)
end

local function utf8(cp) if cp<=0x7f then return string.char(cp) elseif cp<=0x7ff then return string.char(0xc0+math.floor(cp/64),0x80+cp%64) elseif cp<=0xffff then return string.char(0xe0+math.floor(cp/4096),0x80+math.floor(cp/64)%64,0x80+cp%64) else return string.char(0xf0+math.floor(cp/262144),0x80+math.floor(cp/4096)%64,0x80+cp%64) end end
local function read_json_string(raw,q) local out,i={},q+1; while i<=#raw do local c=raw:sub(i,i); if c=='"' then return table.concat(out) end; if c=="\\" then i=i+1; local e=raw:sub(i,i); if e=="n" then out[#out+1]="\n" elseif e=="r" then out[#out+1]="\r" elseif e=="t" then out[#out+1]="\t" elseif e=='"' then out[#out+1]='"' elseif e=="\\" then out[#out+1]="\\" elseif e=="u" then local h=raw:sub(i+1,i+4); local cp=tonumber(h,16); if cp then i=i+4; out[#out+1]=utf8(cp) end else out[#out+1]=e end else out[#out+1]=c end; i=i+1 end; return table.concat(out) end
local function response_text(raw) local s,e=raw:find('"type"%s*:%s*"output_text"'); if not s then return nil end; local ts,te=raw:find('"text"%s*:',e+1); if not ts then return nil end; local q=raw:find('"',te+1,true); return q and read_json_string(raw,q) or nil end
local function provider_name() return provider=="openai" and "OpenAI" or provider=="anthropic" and "Anthropic" or "Google" end
local function model_label() for _,m in ipairs(MODELS[provider] or {}) do if m[2]==model then return m[1] end end return model end
local function select_model(pv,id) provider=pv; model=id; reaper.SetExtState(EXT_SECTION,PROVIDER_KEY,provider,true); reaper.SetExtState(EXT_SECTION,MODEL_KEY,model,true) end
local function get_key() local kn=KEY_NAMES[provider]; local k=trim(reaper.GetExtState(EXT_SECTION,kn)); if k~="" then return k end; local ok,v=reaper.GetUserInputs("Studio – KI-Zugang",1,provider_name().." API-Key:,extrawidth=320",""); if not ok then return nil end; k=trim(v); if k~="" then reaper.SetExtState(EXT_SECTION,kn,k,true); return k end end
local function edit_key(pv) local kn=KEY_NAMES[pv]; local old=reaper.GetExtState(EXT_SECTION,kn); local name=pv=="openai" and "OpenAI" or pv=="anthropic" and "Anthropic" or "Google"; local ok,v=reaper.GetUserInputs("Studio – KI-Zugang",1,name.." API-Key:,extrawidth=320",old or ""); if ok then reaper.SetExtState(EXT_SECTION,kn,trim(v),true) end end
local diag_json
local DIAG_STATE_KEY="LastDiagnosisV2"
local function persist_diag()
 local ok,raw=pcall(function() return diag_json() end)
 if ok and raw then reaper.SetExtState(EXT_SECTION,DIAG_STATE_KEY,raw,true) end
end
local DIAG_CACHE_PATH=reaper.GetResourcePath().."/Composition-Studio-Last-Diagnosis.json"
local function diag_set(k,v) last_diag[k]=v; persist_diag(); local raw=diag_json(); if raw then write_file(DIAG_CACHE_PATH,raw) end end
diag_json=function()
 local keys={"version","composition_engine","composition_engine_build","provider","model","work_title","request","context","controller_prompt","controller_answer","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_stop_reason","api_error","api_response_excerpt","update_error"}; local a={"{\n  \"timestamp\": \""..json_escape(os.date("%Y-%m-%dT%H:%M:%S")).."\""}
 for _,k in ipairs(keys) do a[#a+1]=",\n  \""..k.."\": \""..json_escape(last_diag[k] or "").."\"" end; a[#a+1]="\n}\n"; return table.concat(a)
end
local function restore_diag()
 local raw=read_file(DIAG_CACHE_PATH) or reaper.GetExtState(EXT_SECTION,DIAG_STATE_KEY)
 if not raw or raw=="" then return end
 local keys={"version","composition_engine","composition_engine_build","provider","model","work_title","request","context","controller_prompt","controller_answer","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_error","api_response_excerpt","update_error"}
 for _,k in ipairs(keys) do
  local pat='"'..k..'"%s*:%s*"'
  local _,e=raw:find(pat)
  if e then local q=e; local out={}; local esc=false; while q<#raw do q=q+1; local c=raw:sub(q,q); if esc then if c=="n" then out[#out+1]="\n" elseif c=="r" then out[#out+1]="\r" elseif c=="t" then out[#out+1]="\t" else out[#out+1]=c end; esc=false elseif c=="\\" then esc=true elseif c=='"' then break else out[#out+1]=c end end; last_diag[k]=table.concat(out) end
 end
end
restore_diag()
local write_last_midi_to
local ensure_title_then
local export_last_midi
local save_diagnosis
local save_panel=nil
local function begin_save_panel(kind,title,default_name,ext)
 if save_panel then update_status="Ein Speichern-Dialog ist bereits geöffnet."; return end
 local script=temp_path(IS_WINDOWS and ".ps1" or ".applescript"); local out=temp_path(".path"); local done=temp_path(".done")
 if IS_WINDOWS then
  local ps=[[Add-Type -AssemblyName System.Windows.Forms
try {
  $dialog = New-Object System.Windows.Forms.SaveFileDialog
  ]]
  ps=ps.."$dialog.Title = "..ps_quote(title).."\r\n$dialog.FileName = "..ps_quote(default_name).."\r\n"
  ps=ps.."$dialog.Filter = "..ps_quote(string.upper(ext).." (*."..ext..")|*."..ext.."|Alle Dateien (*.*)|*.*").."\r\n"
  ps=ps.."$result = $dialog.ShowDialog()\r\n"
  ps=ps.."if ($result -eq [System.Windows.Forms.DialogResult]::OK) { [System.IO.File]::WriteAllText("..ps_quote(out)..",$dialog.FileName) } else { [System.IO.File]::WriteAllText("..ps_quote(out)..",'') }\r\n"
  ps=ps.."} catch { [System.IO.File]::WriteAllText("..ps_quote(out)..",'ERROR: ' + $_.Exception.Message) } finally { [System.IO.File]::WriteAllText("..ps_quote(done)..",'done') }\r\n"
  if not write_file(script,"\239\187\191"..ps) then update_status="Speichern-Dialog konnte nicht vorbereitet werden."; return end
  if not ps_launch(script,true) then os.remove(script); update_status="Windows-Speicherdialog konnte nicht gestartet werden."; return end
 else
  local function aq(v) return tostring(v or ""):gsub("\\","\\\\"):gsub('"','\\"') end
  local as='try\nset f to choose file name with prompt "'..aq(title)..'" default name "'..aq(default_name)..'"\nreturn POSIX path of f\non error number -128\nreturn ""\nend try\n'
  if not write_file(script,as) then update_status="Speichern-Dialog konnte nicht vorbereitet werden."; return end
  local cmd="(/usr/bin/osascript "..shell_quote(script).." > "..shell_quote(out).." 2>/dev/null; echo done > "..shell_quote(done)..") &"
  os.execute(cmd)
 end
 save_panel={kind=kind,script=script,out=out,done=done,ext=ext,items=(kind=="swam_midi") and swam_last_made or nil}; update_status="Speicherort wählen …"
end

local function finish_save_panel()
 if not save_panel or not read_file(save_panel.done) then return end
 local p=save_panel; save_panel=nil; local fn=trim(read_file(p.out)); os.remove(p.script); os.remove(p.out); os.remove(p.done)
 if fn:match("^ERROR:") then update_status="Windows-Dialog: "..fn; return end
  if fn=="" then update_status="Speichern abgebrochen."; return end
 if not fn:lower():match("%."..p.ext.."$") then fn=fn.."."..p.ext end
 if p.kind=="swam_midi" then write_last_midi_to(fn,p.items); return end
 if p.kind=="diagnosis" then
  local raw=diag_json(); if write_file(fn,raw) then local chk=read_file(fn); if chk and #chk==#raw then persist_diag(); write_file(DIAG_CACHE_PATH,raw); update_status="Diagnose gespeichert: "..fn.." ("..tostring(#raw).." Bytes)" else update_status="Diagnose konnte nach dem Schreiben nicht verifiziert werden: "..fn end else update_status="Diagnose konnte nicht gespeichert werden: "..fn end
 elseif p.kind=="midi" then local ok,msg=write_last_midi_to(fn); update_status=msg end
end
save_diagnosis=function()
 local title=safe_work_title(work_title)
 if title=="" then title="Composition Studio" end
 begin_save_panel("diagnosis","Diagnose speichern",title.." - Diagnose.json","json")
end

local function be16(n) return string.char(math.floor(n/256)%256,n%256) end
local function be32(n) return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256) end
local function vlq(n)
 n=math.max(0,math.floor(n+0.5)); local b={n%128}; n=math.floor(n/128)
 while n>0 do table.insert(b,1,128+n%128); n=math.floor(n/128) end
 local a={}; for _,v in ipairs(b) do a[#a+1]=string.char(v) end; return table.concat(a)
end
local function midi_track_chunk(events,name)
 table.sort(events,function(a,b) if a.tick~=b.tick then return a.tick<b.tick end return a.order<b.order end)
 local out={vlq(0),string.char(0xFF,0x03,#name),name}; local last=0
 for _,e in ipairs(events) do out[#out+1]=vlq(e.tick-last); out[#out+1]=e.data; last=e.tick end
 out[#out+1]=vlq(0)..string.char(0xFF,0x2F,0); local d=table.concat(out); return "MTrk"..be32(#d)..d
end
local function recover_last_made()
 local _,raw=reaper.GetProjExtState(0,EXT_SECTION,"LastMadeGUIDs"); if not raw or raw=="" then return {} end
 local wanted={}; for g in raw:gmatch("[^\r\n]+") do wanted[g]=true end; local found={}
 for i=0,reaper.CountMediaItems(0)-1 do local it=reaper.GetMediaItem(0,i); local ok,g=reaper.GetSetMediaItemInfo_String(it,"GUID","",false); if ok and wanted[g] then found[#found+1]=it end end
 return found
end
write_last_midi_to=function(fn,items_override)
 local valid={}; for _,it in ipairs(items_override or last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then valid=recover_last_made() end
 if #valid==0 then update_status="Noch keine gültige von Composition Studio erzeugte Komposition zum Exportieren."; return end

 local ppq=960; local chunks={}; local map_events={}; local count=reaper.CountTempoTimeSigMarkers(0); if count==0 then local tempo=math.max(1,reaper.Master_GetTempo()); local us=math.floor(60000000/tempo+0.5); map_events[#map_events+1]={tick=0,order=0,data=string.char(0xFF,0x51,0x03,math.floor(us/65536)%256,math.floor(us/256)%256,us%256)}; map_events[#map_events+1]={tick=0,order=1,data=string.char(0xFF,0x58,0x04,4,2,24,8)} else for i=0,count-1 do local ok,timepos,_,_,bpm,num,den=reaper.GetTempoTimeSigMarker(0,i); if ok then local qn=reaper.TimeMap2_timeToQN(0,timepos); local tick=math.max(0,math.floor(qn*ppq+0.5)); local us=math.floor(60000000/math.max(1,bpm)+0.5); local dd=0; local d=math.max(1,den); while d>1 do d=math.floor(d/2); dd=dd+1 end; map_events[#map_events+1]={tick=tick,order=0,data=string.char(0xFF,0x51,0x03,math.floor(us/65536)%256,math.floor(us/256)%256,us%256)}; map_events[#map_events+1]={tick=tick,order=1,data=string.char(0xFF,0x58,0x04,math.max(1,num),dd,24,8)} end end end; chunks[#chunks+1]=midi_track_chunk(map_events,"Tempo & Takt")
 for _,item in ipairs(valid) do
  local take=reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then
   local _,name=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); name=name~="" and name or "MIDI"; local ev={}; local _,nc,cc=reaper.MIDI_CountEvts(take)
   for i=0,(cc or 0)-1 do local ok,_,mut,pp,typ,ch,m2,m3=reaper.MIDI_GetCC(take,i); if ok and not mut then local tm=reaper.MIDI_GetProjTimeFromPPQPos(take,pp); local q=reaper.TimeMap2_timeToQN(0,tm); local tick=math.max(0,math.floor(q*ppq+0.5)); if typ==0xC0 then ev[#ev+1]={tick=tick,order=0,data=string.char(0xC0+(ch or 0),m2 or 0)} elseif typ==0xB0 then ev[#ev+1]={tick=tick,order=0,data=string.char(0xB0+(ch or 0),m2 or 0,m3 or 0)} end end end
   for i=0,(nc or 0)-1 do local ok,_,mut,sn,en,ch,pit,vel=reaper.MIDI_GetNote(take,i); if ok and not mut then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sn); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,en); local ta=math.max(0,math.floor(reaper.TimeMap2_timeToQN(0,st)*ppq+0.5)); local tb=math.max(ta+1,math.floor(reaper.TimeMap2_timeToQN(0,et)*ppq+0.5)); ev[#ev+1]={tick=ta,order=2,data=string.char(0x90+ch,pit,vel)}; ev[#ev+1]={tick=tb,order=1,data=string.char(0x80+ch,pit,0)} end end
   chunks[#chunks+1]=midi_track_chunk(ev,name)
  end
 end
 local smf="MThd"..be32(6)..be16(1)..be16(#chunks)..be16(ppq)..table.concat(chunks); if write_file(fn,smf) then local chk=read_file(fn); if chk and #chk==#smf and chk:sub(1,4)=="MThd" then update_status="MIDI gespeichert: "..fn.." ("..tostring(#valid).." Spur(en), "..tostring(#smf).." Bytes)" else update_status="MIDI-Datei konnte nach dem Schreiben nicht verifiziert werden: "..fn end else update_status="MIDI konnte nicht gespeichert werden: "..fn end
end
local launch
local function swam_source_context()
 local valid={}; for _,it in ipairs(last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then valid=recover_last_made() end
 if #valid==0 then return nil,"Noch keine gültige von Composition Studio erzeugte Komposition für SWAM vorhanden." end
 local rows={}
 for _,item in ipairs(valid) do
  local take=reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then
   local _,name=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); name=name~="" and name or "MIDI"
   rows[#rows+1]="VOICE|"..name
   local _,nc=reaper.MIDI_CountEvts(take)
   for n=0,(nc or 0)-1 do
    local ok,_,mut,sn,en,ch,pit,vel=reaper.MIDI_GetNote(take,n)
    if ok and not mut then
     local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sn); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,en)
     local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et)
     rows[#rows+1]=string.format("N|%s|%.5f|%.5f|%d|%d|%d",name,sq,eq-sq,pit,vel,ch)
    end
   end
  end
 end
 return table.concat(rows,"\\n"),nil
end
local function swam_interpretation_prompt(source)
 return [[Du bist ausschließlich musikalischer Interpret für SWAM Solo Strings. Die Komposition ist fertig und darf nicht umkomponiert werden. Entwickle aus dem musikalischen Entwurf und den vorhandenen Noten eine ausdrucksstarke, natürlich wirkende Streicheraufführung. Denke wie ein sehr guter Geiger bzw. Cellist: Phrasierung, Bogenführung, Ansatz und Loslassen, Vibrato-Verlauf innerhalb längerer Töne, Bogendruck, Klangposition, Legato/Portamento, dynamische Übergänge und sinnvolle Bogenwechsel. Nutze Tremolo, Harmonics, Sordino oder andere Sondertechniken nur, wenn sie musikalisch aus dem Entwurf hervorgehen. Verändere keine Tonhöhen und erfinde keine neuen Noten. Denke noch NICHT in CC-Nummern oder MIDI-Codierung. Schreibe stattdessen eine konkrete Aufführungsanweisung für jede Stimme und ihre Phrasen.]].."\\n\\nFERTIGE KOMPOSITION:\\n"..tostring(last_diag.composition_music or "").."\\n\\nVORHANDENE MIDI-NOTEN:\\n"..source
end
local function swam_translation_prompt(source,performance)
 return [[Du bist ausschließlich technischer SWAM-Performance-Übersetzer. Übertrage die fertige Aufführungsanweisung in Composition-Studios CS/CSCTRL-Format. Komponiere NICHT neu. Alle vorhandenen Tonhöhen und Note-On-Zeitpunkte müssen erhalten bleiben. Notendauern dürfen nur behutsam verändert werden, wenn dies für Legato, Trennung oder Artikulation erforderlich ist. Erzeuge für jede vorhandene Stimme eine neue CS-Zeile und danach die nötigen CSCTRL-Zeilen. Verwende dieses verbindliche Profil "Composition Studio SWAM Strings v1": CC11 Expression, CC1 Vibrato Depth, CC19 Vibrato Rate, CC20 Portamento Time, CC21 Bow Pressure, CC22 Dynamic Transitions, CC23 Bow/Pizz Position, CC24 Bow Lift, CC25 Bow Start, CC26 Bow Noise, CC27 Attack Ramp Speed, CC28 Alternate Fingering, CC29 Harmonics, CC30 Tremolo, CC31 Sordino, CC32 Play Mode, CC33 Staccato Interval Time, CC34 Bowing Sensitivity. Main Volume CC7, Pan CC10, Reverb CC90 und Sustain CC64 nicht für musikalische Expression verwenden. Kontinuierliche Parameter dürfen fein abgestufte Verläufe erhalten; Ereignisparameter nur gezielt setzen. Vibrato soll bei längeren Tönen musikalisch innerhalb des Tons entstehen und sich entwickeln, nicht bloß statisch gesetzt werden. Bow Lift/Bow Start nur an sinnvollen Bogenwechseln. Verwende Sondertechniken nur, wenn die Aufführungsanweisung sie verlangt.
Format:
CS|new|-|NAME SWAM|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CSCTRL|NAME SWAM|startQN|CHANNEL|cc|CONTROLLER|VALUE
Antworte ausschließlich mit CS- und CSCTRL-Zeilen.]].."\\n\\nEXAKTE AUSGANGSNOTEN:\\n"..source.."\\n\\nFERTIGE AUFFÜHRUNGSANWEISUNG:\\n"..performance
end
local function export_swam_midi()
 if busy then return end
 local valid={}; for _,it in ipairs(swam_last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then update_status="Noch keine SWAM-Interpretation zum Exportieren."; return end
 swam_last_made=valid
 local base=work_title~="" and work_title or "Composition Studio"
 begin_save_panel("swam_midi","SWAM-MIDI exportieren",base.." – SWAM.mid","mid")
end
local function begin_swam_interpretation()
 if busy then return end
 local source,e=swam_source_context(); if not source then update_status=e; return end
 local key=get_key(); if not key then update_status="Für die SWAM-Interpretation fehlt der API-Key."; return end
 busy=true; update_status="SWAM-Interpret erstellt Aufführung …"
 launch("swam_interpretation",swam_interpretation_prompt(source),key,{swam_source=source})
end
local function first_text_field(raw) local ts,te=(raw or ""):find('"text"%s*:'); if not ts then return nil end; local q=raw:find('"',te+1,true); return q and read_json_string(raw,q) or nil end
local function enc(s) return (tostring(s or ""):gsub("([^%w%-%._~])",function(c) return string.format("%%%02X",string.byte(c)) end)) end
local function dec(s) return (tostring(s or ""):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end
local function save_history(proj) proj=proj or current_project; if not proj then return end; local rows={}; for _,m in ipairs(history) do rows[#rows+1]=enc(m.role).."\t"..enc(m.text) end; reaper.SetProjExtState(proj,EXT_SECTION,HISTORY_KEY,table.concat(rows,"\n")) end
local function load_history(proj) history={}; if proj then local _,raw=reaper.GetProjExtState(proj,EXT_SECTION,HISTORY_KEY); if raw and raw~="" then for row in raw:gmatch("[^\n]+") do local r,t=row:match("^([^\t]*)\t(.*)$"); if r then history[#history+1]={role=dec(r),text=dec(t)} end end end end; if #history==0 then history={{role="KI",text="Composition Studio ist bereit."}} end; chat_start=1; info_visible=false; history_mode=false end
local function add(role,text) history[#history+1]={role=role,text=text}; save_history() end
local function clear_saved_history() history={{role="KI",text="Composition Studio ist bereit."}}; chat_start=1; info_visible=false; history_mode=false; save_history() end
load_history(current_project)
local function item_guid(item) local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false); return ok and g or "" end
local function track_guid(track) return reaper.GetTrackGUID(track) or "" end
local function selected_tracks() local a={}; for i=0,reaper.CountSelectedTracks(0)-1 do local tr=reaper.GetSelectedTrack(0,i); local _,n=reaper.GetTrackName(tr); a[#a+1]={track=tr,guid=track_guid(tr),name=n~="" and n or "Unbenannte Spur",index=math.floor(reaper.GetMediaTrackInfo_Value(tr,"IP_TRACKNUMBER"))} end; return a end
local function selected_items(with_notes) local a={}; for i=0,reaper.CountSelectedMediaItems(0)-1 do local item=reaper.GetSelectedMediaItem(0,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local tr=reaper.GetMediaItem_Track(item); local _,tn=reaper.GetTrackName(tr); local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH"); local it={item=item,take=take,track=tr,guid=item_guid(item),track_guid=track_guid(tr),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),notes={}}; if with_notes then local _,ncount=reaper.MIDI_CountEvts(take); for n=0,(ncount or 0)-1 do local ok,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(take,n); if ok and not muted then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,s); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,e); local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et); it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch} end end end; a[#a+1]=it end end; return a end

local NOTE_NAMES={"C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"}
local function score_pitch_name(p)
 p=math.max(0,math.min(127,math.floor(p or 60)))
 return NOTE_NAMES[(p%12)+1]..tostring(math.floor(p/12)-1)
end
local function score_selection_signature()
 local parts={}
 for i=0,reaper.CountSelectedMediaItems(0)-1 do
  local item=reaper.GetSelectedMediaItem(0,i)
  local take=item and reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then parts[#parts+1]=item_guid(item) end
 end
 table.sort(parts)
 return table.concat(parts,"|")
end
local function score_capture_selection()
 local items=selected_items(false)
 local notes,kept={},{}
 for _,it in ipairs(items) do
  if it.take and reaper.ValidatePtr2(0,it.take,"MediaItem_Take*") and reaper.TakeIsMIDI(it.take) then
   kept[#kept+1]=it
   local _,ncount=reaper.MIDI_CountEvts(it.take)
   for n=0,(ncount or 0)-1 do
    local ok,_,muted,sp,ep,ch,p,v=reaper.MIDI_GetNote(it.take,n)
    if ok and not muted then
     local st=reaper.MIDI_GetProjTimeFromPPQPos(it.take,sp)
     local et=reaper.MIDI_GetProjTimeFromPPQPos(it.take,ep)
     notes[#notes+1]={take=it.take,item=it.item,item_guid=it.guid,track_guid=it.track_guid,take_name=it.take_name,track_name=it.track_name,note_idx=n,start_ppq=sp,end_ppq=ep,start_qn=reaper.TimeMap2_timeToQN(0,st),duration_qn=reaper.TimeMap2_timeToQN(0,et)-reaper.TimeMap2_timeToQN(0,st),pitch=p,velocity=v,channel=ch}
    end
   end
  end
 end
 table.sort(notes,function(a,b)
  if math.abs(a.start_qn-b.start_qn)>0.000001 then return a.start_qn<b.start_qn end
  if a.item_guid~=b.item_guid then return a.item_guid<b.item_guid end
  return a.pitch<b.pitch
 end)
 for i,n in ipairs(notes) do n.csid=i end
 score_state.items=kept
 score_state.notes=notes
 score_state.selection_signature=score_selection_signature()
 if #notes==0 then score_state.selected=0 else score_state.selected=math.min(math.max(score_state.selected,1),#notes) end
 notation_status=#kept==0 and "Keine ausgewählten MIDI-Items in REAPER." or (tostring(#kept).." MIDI-Item(s) übernommen · "..tostring(#notes).." Noten.")
end
local function score_selected_note()
 if score_state.selected<1 then return nil end
 return score_state.notes[score_state.selected]
end
local function score_refresh_after_edit(ref)
 score_capture_selection()
 if not ref then return end
 for i,n in ipairs(score_state.notes) do
  if n.item_guid==ref.item_guid and math.abs(n.start_ppq-ref.start_ppq)<0.5 and n.channel==ref.channel then
   score_state.selected=i
   if n.pitch==ref.pitch then break end
  end
 end
end
local function score_change_pitch(delta)
 local n=score_selected_note()
 if not n then notation_status="Keine Note ausgewählt."; return end
 local np=math.max(0,math.min(127,n.pitch+delta))
 local ref={item_guid=n.item_guid,start_ppq=n.start_ppq,channel=n.channel,pitch=np}
 reaper.Undo_BeginBlock2(0)
 local ok,sel,mut,sp,ep,ch,_,vel=reaper.MIDI_GetNote(n.take,n.note_idx)
 if ok then reaper.MIDI_SetNote(n.take,n.note_idx,sel,mut,sp,ep,ch,np,vel,true); reaper.MIDI_Sort(n.take) end
 reaper.Undo_EndBlock2(0,"Composition Studio Notation – Tonhöhe ändern",-1)
 reaper.UpdateArrange()
 score_refresh_after_edit(ref)
 notation_status="Tonhöhe geändert: "..score_pitch_name(np).." · REAPER-MIDI aktualisiert."
end
local function score_scale_duration(factor)
 local n=score_selected_note()
 if not n then notation_status="Keine Note ausgewählt."; return end
 local ref={item_guid=n.item_guid,start_ppq=n.start_ppq,channel=n.channel,pitch=n.pitch}
 reaper.Undo_BeginBlock2(0)
 local ok,sel,mut,sp,ep,ch,p,vel=reaper.MIDI_GetNote(n.take,n.note_idx)
 if ok then
  local dur=math.max(1,ep-sp)
  local nd=math.max(1,math.floor(dur*factor+0.5))
  reaper.MIDI_SetNote(n.take,n.note_idx,sel,mut,sp,sp+nd,ch,p,vel,true)
  reaper.MIDI_Sort(n.take)
 end
 reaper.Undo_EndBlock2(0,"Composition Studio Notation – Notendauer ändern",-1)
 reaper.UpdateArrange()
 score_refresh_after_edit(ref)
 notation_status="Notendauer geändert · REAPER-MIDI aktualisiert."
end

local function track_context_items(tracks) local a={}; local seen={}; for _,t in ipairs(tracks) do for i=0,reaper.CountTrackMediaItems(t.track)-1 do local item=reaper.GetTrackMediaItem(t.track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local g=item_guid(item); if not seen[g] then seen[g]=true; local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH"); local it={item=item,take=take,track=t.track,guid=g,track_guid=t.guid,track_name=t.name,take_name=kn~="" and kn or "Unbenanntes MIDI-Item",start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),notes={}}; local _,nc=reaper.MIDI_CountEvts(take); for n=0,(nc or 0)-1 do local ok,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(take,n); if ok and not muted then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,s); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,e); local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et); it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch} end end; a[#a+1]=it end end end end; return a end
local function time_selection_context() local s,e=reaper.GetSet_LoopTimeRange(false,false,0,0,false); if not s or not e or e<=s then return "TIME_SELECTION none" end; local sq=reaper.TimeMap2_timeToQN(0,s); local eq=reaper.TimeMap2_timeToQN(0,e); local _,sm,sb=reaper.TimeMap2_timeToBeats(0,s); local _,em,eb=reaper.TimeMap2_timeToBeats(0,e); return string.format("TIME_SELECTION startQN=%.3f endQN=%.3f startBar=%d startBeat=%.3f endBar=%d endBeat=%.3f",sq,eq,(sm or 0)+1,(sb or 0)+1,(em or 0)+1,(eb or 0)+1) end
local function compact_context(items,tracks,ignore_time) tracks=tracks or selected_tracks(); local l={string.format("Tempo %.2f BPM; selected MIDI items=%d; selected tracks=%d",reaper.Master_GetTempo(),#items,#tracks)}; l[#l+1]=ignore_time and "TIME_SELECTION ignored for free new composition" or time_selection_context(); for i,t in ipairs(tracks) do l[#l+1]=string.format("TRACK %d id=%s name=%s index=%d",i,t.guid,t.name,t.index) end; for i,it in ipairs(items) do l[#l+1]=string.format("ITEM %d id=%s trackId=%s track=%s take=%s rangeQN=%.3f..%.3f",i,it.guid,it.track_guid,it.track_name,it.take_name,it.start_qn,it.end_qn) end; return table.concat(l,"\n") end
local function music_context(items,tracks,ignore_time) local l={compact_context(items,tracks,ignore_time)}; for _,it in ipairs(items) do for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %s %.5f %.5f %d %d %d",it.guid,n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end end; return table.concat(l,"\n") end
local function recent_dialog() local l={}; for i=math.max(1,#history-7),#history do l[#l+1]=history[i].role..": "..history[i].text end; return table.concat(l,"\n") end

local function first_program_changes_on_track(track)
 local pcs={}
 for i=0,reaper.CountTrackMediaItems(track)-1 do local item=reaper.GetTrackMediaItem(track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local _,_,cc=reaper.MIDI_CountEvts(take); for n=0,(cc or 0)-1 do local ok,_,muted,ppq,chanmsg,ch,msg2=reaper.MIDI_GetCC(take,n); if ok and not muted and chanmsg==0xC0 then local tm=reaper.MIDI_GetProjTimeFromPPQPos(take,ppq); local c=(ch or 0)+1; if not pcs[c] or tm<pcs[c].time then pcs[c]={program=msg2,time=tm} end end end end end
 return pcs
end
local function find_halions(track) local out={}; for fx=0,reaper.TrackFX_GetCount(track)-1 do local ok,n=reaper.TrackFX_GetFXName(track,fx,""); if ok and (n or ""):lower():find("halion sonic",1,true) then out[#out+1]=fx end end; return out end
local function halion_program_param(track,fx,ch) local wanted="S"..ch.." Program Change"; for p=0,reaper.TrackFX_GetNumParams(track,fx)-1 do local ok,n=reaper.TrackFX_GetParamName(track,fx,p,""); if ok and n==wanted then return p end end end
local function source_tracks_for_halion(dest) local out,seen={},{}; if reaper.CountTrackMediaItems(dest)>0 then out[#out+1]=dest; seen[dest]=true end; for r=0,reaper.GetTrackNumSends(dest,-1)-1 do local src=reaper.GetTrackSendInfo_Value(dest,-1,r,"P_SRCTRACK"); if src and not seen[src] then out[#out+1]=src; seen[src]=true end end; return out end
local function initialize_halion_track(track) local fxs=find_halions(track); if #fxs==0 then return 0 end; local pcs={}; for _,src in ipairs(source_tracks_for_halion(track)) do local found=first_program_changes_on_track(src); for ch,v in pairs(found) do if not pcs[ch] or v.time<pcs[ch].time then pcs[ch]=v end end end; local changed=0; for _,fx in ipairs(fxs) do for ch=1,16 do local v=pcs[ch]; if v then local p=halion_program_param(track,fx,ch); if p then reaper.TrackFX_SetParamNormalized(track,fx,p,v.program/127.0); changed=changed+1 end end end end; return changed end
local function initialize_halion_project() local tracks,slots=0,0; for i=0,reaper.CountTracks(0)-1 do local tr=reaper.GetTrack(0,i); if #find_halions(tr)>0 then local n=initialize_halion_track(tr); if n>0 then tracks=tracks+1; slots=slots+n end end end; return tracks,slots end


local CONTROLLER=[[Du bist der Controller von Composition Studio in REAPER. Der Benutzer spricht frei; es gibt KEINE Triggerwörter. Interpretiere nur, was eindeutig gemeint ist. Bei Unklarheit FRAGE nach.
Antworte mit GENAU EINER Zeile:
CHAT|Text
ASK|Rückfrage
ACTION|TRANSPOSE|ITEM_GUID|SEMITONES|Beschreibung
ACTION|MOVE_ITEM|ITEM_GUID|DELTA_QN|Beschreibung
ACTION|COPY_ITEM|ITEM_GUID|DELTA_QN|Beschreibung
ACTION|RENAME_TRACK|TRACK_GUID|NEUER_NAME|Beschreibung
ACTION|INIT_HALION|-|-|Beschreibung
NEED_ANALYSIS|Begründung
NEED_MUSIC|Begründung
NEED_NEW|Begründung
Nur angebotene IDs verwenden. Wenn der Benutzer HALion Sonic aus vorhandenen Program Changes initialisieren, vorbereiten oder die Instrumentierung übernehmen lassen will, verwende ACTION|INIT_HALION|-|-|Beschreibung. Diese Aktion setzt die HALion-Programmparameter einmalig und erzeugt keine dauerhaften MIDI-Links. Eine ausgewählte TRACK_GUID kann auch ohne ausgewähltes MIDI-Item das Ziel eines musikalischen Auftrags sein. TIME_SELECTION ist der markierte Zielbereich. Eine vollständige Neukomposition benötigt weder ein vorhandenes MIDI-Item noch eine ausgewählte Spur. Vorhandene REAPER-Auswahl und TIME_SELECTION sind nur Kontext, solange der Benutzer nicht sprachlich auf vorhandenes Material, Auswahl, Spur, Item, markierten Bereich, Fortsetzung oder Bearbeitung Bezug nimmt. Ein klarer eigenständiger Auftrag wie 'Erstelle ein Stück für Violine und Gitarre' ist NEED_NEW. Für Analyse des Notenmaterials: NEED_ANALYSIS. Für Komposition, Variation, Fortsetzung, Ergänzung oder musikalische Bearbeitung mit neuem MIDI: NEED_MUSIC. Für normale Unterhaltung: CHAT.]]
local function parse_action(line,items) line=trim(line or ""); local typ,a,b,desc=line:match("^ACTION|([^|]+)|([^|]+)|([^|]+)|(.+)$"); if not typ then return nil,"Ungültiger ACTION-Aufruf." end; local bi,bt={},{}; for _,it in ipairs(items) do bi[it.guid]=it; bt[it.track_guid]=it.track end; for _,t in ipairs(selected_tracks()) do bt[t.guid]=t.track end; if typ=="INIT_HALION" then return {kind=typ,desc=desc} elseif typ=="TRANSPOSE" then local n=tonumber(b); if not bi[a] or not n or n~=math.floor(n) or n< -127 or n>127 then return nil,"Ungültige Transposition." end; return {kind=typ,item=bi[a],n=n,desc=desc} elseif typ=="MOVE_ITEM" or typ=="COPY_ITEM" then local q=tonumber(b); if not bi[a] or not q then return nil,"Ungültige Item-Verschiebung." end; return {kind=typ,item=bi[a],q=q,desc=desc} elseif typ=="RENAME_TRACK" then if not bt[a] or trim(b)=="" then return nil,"Ungültige Spurbenennung." end; return {kind=typ,track=bt[a],name=trim(b),desc=desc} end; return nil,"Diese Aktion ist nicht freigegeben." end
local function execute_action(a) reaper.Undo_BeginBlock2(0); local ok,err=xpcall(function() if a.kind=="INIT_HALION" then local tr,sl=initialize_halion_project(); a.desc=string.format("HALion Sonic initialisiert: %d Instanzspur(en), %d Slot(s)",tr,sl); diag_set("halion_result",a.desc) elseif a.kind=="TRANSPOSE" then local take=a.item.take; local _,nc=reaper.MIDI_CountEvts(take); for i=0,(nc or 0)-1 do local yes,sel,mut,s,e,ch,p,v=reaper.MIDI_GetNote(take,i); if yes and not mut then local np=p+a.n; if np<0 or np>127 then error("Transposition würde den MIDI-Bereich verlassen.") end; reaper.MIDI_SetNote(take,i,sel,mut,s,e,ch,np,v,true) end end; reaper.MIDI_Sort(take) elseif a.kind=="MOVE_ITEM" then local pos=reaper.GetMediaItemInfo_Value(a.item.item,"D_POSITION"); local qn=reaper.TimeMap2_timeToQN(0,pos)+a.q; if qn<0 then error("Item würde vor Projektbeginn liegen.") end; reaper.SetMediaItemInfo_Value(a.item.item,"D_POSITION",reaper.TimeMap2_QNToTime(0,qn)) elseif a.kind=="COPY_ITEM" then local src=a.item.item; local okc,chunk=reaper.GetItemStateChunk(src,"",false); if not okc then error("Item konnte nicht gelesen werden.") end; local ni=reaper.AddMediaItemToTrack(a.item.track); if not reaper.SetItemStateChunk(ni,chunk,false) then error("Item konnte nicht kopiert werden.") end; local qn=reaper.TimeMap2_timeToQN(0,reaper.GetMediaItemInfo_Value(src,"D_POSITION"))+a.q; if qn<0 then error("Kopie würde vor Projektbeginn liegen.") end; reaper.SetMediaItemInfo_Value(ni,"D_POSITION",reaper.TimeMap2_QNToTime(0,qn)); reaper.SetMediaItemSelected(ni,true) elseif a.kind=="RENAME_TRACK" then reaper.GetSetMediaTrackInfo_String(a.track,"P_NAME",a.name,true) end end,debug.traceback); if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end; reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – "..a.kind,-1); return true end
local function parse_notes(text) local notes={}; for t in (text or ""):gmatch("[^;]+") do local a,b,c,d,e=t:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$"); a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e); if not(a and b and c and d and e) then return nil end; notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e} end; return #notes>0 and notes or nil end
local function create_track(name,index) index=index or reaper.CountTracks(0); reaper.InsertTrackAtIndex(index,true); local t=reaper.GetTrack(0,index); if t then reaper.GetSetMediaTrackInfo_String(t,"P_NAME",name,true) end; return t end
local function existing_program(track) for i=0,reaper.CountTrackMediaItems(track)-1 do local item=reaper.GetTrackMediaItem(track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local _,_,_,cc=reaper.MIDI_CountEvts(take); for n=0,(cc or 0)-1 do local ok,_,muted,_,chanmsg,_,msg2=reaper.MIDI_GetCC(take,n); if ok and not muted and chanmsg==0xC0 then return msg2 end end end end; return nil end
local function program_for_name(name,proposed) local n=(name or ""):lower(); local map={{"violin",40},{"violine",40},{"geige",40},{"viola",41},{"bratsche",41},{"cello",42},{"violoncello",42},{"kontrabass",43},{"double bass",43},{"gitarre",24},{"guitar",24},{"harfe",46},{"harp",46},{"flöte",73},{"floete",73},{"flute",73},{"oboe",68},{"klarinette",71},{"clarinet",71},{"fagott",70},{"bassoon",70},{"trompete",56},{"trumpet",56},{"horn",60},{"posaune",57},{"trombone",57},{"sax",65},{"klavier",0},{"piano",0},{"orgel",19},{"organ",19}}; for _,p in ipairs(map) do if n:find(p[1],1,true) then return p[2] end end; local v=tonumber(proposed); if v and v>=0 and v<=127 then return math.floor(v) end; return 0 end
local function create_midi(track,name,notes,program) local lo,hi=math.huge,-math.huge; for _,n in ipairs(notes) do lo=math.min(lo,n.start_qn); hi=math.max(hi,n.start_qn+n.duration_qn) end; if hi<=lo then return nil end; local item=reaper.CreateNewMIDIItemInProj(track,reaper.TimeMap2_QNToTime(0,lo),reaper.TimeMap2_QNToTime(0,hi),false); local take=item and reaper.GetActiveTake(item); if not take then return nil end; reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",name,true); local ch=math.max(0,math.min(15,(notes[1].channel or 0))); local ppq=reaper.MIDI_GetPPQPosFromProjTime(take,reaper.TimeMap2_QNToTime(0,lo)); local pg=math.max(0,math.min(127,program or 0)); reaper.MIDI_InsertCC(take,false,false,ppq,0xB0,ch,0,0); reaper.MIDI_InsertCC(take,false,false,ppq,0xB0,ch,32,0); reaper.MIDI_InsertCC(take,false,false,ppq,0xC0,ch,pg,0); for _,n in ipairs(notes) do local s=reaper.MIDI_GetPPQPosFromProjTime(take,reaper.TimeMap2_QNToTime(0,n.start_qn)); local e=reaper.MIDI_GetPPQPosFromProjTime(take,reaper.TimeMap2_QNToTime(0,n.start_qn+n.duration_qn)); reaper.MIDI_InsertNote(take,false,false,s,e,n.channel,n.pitch,n.velocity,true) end; reaper.MIDI_Sort(take); return item end
local function apply_composition(text,items,tracks,force_single_piano) local src,targets={},{ }; for _,it in ipairs(items) do src[it.guid]=it end; for _,t in ipairs(tracks or {}) do targets[t.guid]=t.track end; local jobs={}; local musical_map={}; local controls={}; for line in text:gmatch("[^\r\n]+") do line=trim(line); local mt,q,bpm=line:match("^CSMETA|(tempo)|([^|]+)|([^|]+)$"); local ms,mq,num,den=line:match("^CSMETA|(timesig)|([^|]+)|([^|]+)|([^|]+)$"); if mt then q,bpm=tonumber(q),tonumber(bpm); if not q or not bpm or q<0 or bpm<=0 then return nil,"Ungültige Tempoangabe." end; musical_map[#musical_map+1]={kind="tempo",qn=q,bpm=bpm} elseif ms then mq,num,den=tonumber(mq),tonumber(num),tonumber(den); if not mq or not num or not den or mq<0 or num<1 or den<1 then return nil,"Ungültige Taktartangabe." end; musical_map[#musical_map+1]={kind="timesig",qn=mq,num=math.floor(num),den=math.floor(den)} elseif line:match("^CSCTRL|") then local name,cq,ch,kind,rest=line:match("^CSCTRL|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.+)$"); cq,ch=tonumber(cq),tonumber(ch); if not name or not cq or not ch or cq<0 or ch<0 or ch>15 then return nil,"Ungültiges Ausdrucksereignis." end; if kind=="cc" then local cc,val=rest:match("^(%d+)|(%d+)$"); cc,val=tonumber(cc),tonumber(val); if not cc or not val or cc>127 or val>127 then return nil,"Ungültiges CC-Ausdrucksereignis." end; controls[#controls+1]={name=trim(name),qn=cq,ch=ch,kind="cc",a=cc,b=val} elseif kind=="program" then local pg=tonumber(rest); if not pg or pg<0 or pg>127 then return nil,"Ungültiger Program Change." end; controls[#controls+1]={name=trim(name),qn=cq,ch=ch,kind="program",a=math.floor(pg)} else return nil,"Unbekanntes Ausdrucksereignis." end else local k,g,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$"); if not k then return nil,"Unerwartete Kompositionsantwort." end; if k=="unchanged" then if not src[g] then return nil,"Unbekannte Quelle." end elseif k=="revised" or k=="target" or k=="track" or k=="new" then local name,pg,nt=rest:match("^([^|]+)|(%d+)|(.+)$"); local notes=parse_notes(nt); local program=tonumber(pg); if not name or not notes or not program or program<0 or program>127 then return nil,"Ungültige Kompositionsdaten." end; if (k=="revised" or k=="target") and not src[g] then return nil,"Unbekannte Quelle." end; if k=="track" and not targets[g] then return nil,"Unbekannte Zielspur." end; if k=="new" and g~="-" then return nil,"Ungültige neue Spur." end; local merged=nil; for _,j in ipairs(jobs) do if j.kind==k and j.guid==g and j.name==trim(name) then merged=j; break end end; if merged then for _,note in ipairs(notes) do merged.notes[#merged.notes+1]=note end else jobs[#jobs+1]={kind=k,guid=g,name=trim(name),program=program_for_name(name,program),notes=notes} end else return nil,"Unbekannter Ergebnistyp." end end end;
 if force_single_piano then
  -- The original AI names have no authority to determine REAPER track identity.
  local all={}
  for _,j in ipairs(jobs) do
   if j.kind~="new" then return nil,"Klavier-Zusammenführung enthält eine Bearbeitungsaktion." end
   for _,note in ipairs(j.notes) do all[#all+1]=note end
  end
  if #all==0 then return nil,"Keine Klaviernoten vorhanden." end
  table.sort(all,function(a,b) if a.start_qn~=b.start_qn then return a.start_qn<b.start_qn end return a.pitch<b.pitch end)
  jobs={{kind="new",guid="-",name="Klavier",program=0,notes=all}}
  for _,ctl in ipairs(controls) do ctl.name="Klavier" end
 end
 reaper.Undo_BeginBlock2(0); local made={}; local ok,err=xpcall(function() if #musical_map>0 then for i=reaper.CountTempoTimeSigMarkers(0)-1,0,-1 do reaper.DeleteTempoTimeSigMarker(0,i) end; table.sort(musical_map,function(a,b) return a.qn<b.qn end); local cur_bpm=reaper.Master_GetTempo(); local cur_num,cur_den=4,4; for _,m in ipairs(musical_map) do if m.kind=="tempo" then cur_bpm=m.bpm else cur_num,cur_den=m.num,m.den end; local tm=reaper.TimeMap2_QNToTime(0,m.qn); reaper.SetTempoTimeSigMarker(0,-1,tm,-1,-1,cur_bpm,cur_num,cur_den,false) end end; local takes_by_name={}; for _,j in ipairs(jobs) do local tr; if j.kind=="revised" then local no=math.floor(reaper.GetMediaTrackInfo_Value(src[j.guid].track,"IP_TRACKNUMBER")); tr=create_track(j.name.." [Variante]",no) elseif j.kind=="target" then tr=src[j.guid].track elseif j.kind=="track" then tr=targets[j.guid] else tr=create_track(j.name) end; local inherited=(j.kind~="new") and existing_program(tr) or nil; local it=create_midi(tr,j.name,j.notes,inherited or j.program); if not it then error("MIDI konnte nicht erzeugt werden") end; made[#made+1]=it; local tk=reaper.GetActiveTake(it); if tk then takes_by_name[j.name]=tk end end; for _,c in ipairs(controls) do local tk=takes_by_name[c.name]; if tk then local ppq=reaper.MIDI_GetPPQPosFromProjTime(tk,reaper.TimeMap2_QNToTime(0,c.qn)); if c.kind=="cc" then reaper.MIDI_InsertCC(tk,false,false,ppq,0xB0,c.ch,c.a,c.b) else reaper.MIDI_InsertCC(tk,false,false,ppq,0xC0,c.ch,c.a,0) end; reaper.MIDI_Sort(tk) end end end,debug.traceback); if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagen",-1); reaper.Undo_DoUndo2(0); return nil,err end; reaper.UpdateArrange(); reaper.Undo_EndBlock2(0,"Composition Studio – KI-Komposition",-1); return made end
export_last_midi=function()
 local made=last_made; if #made==0 then made=recover_last_made() end
 local valid=0; for _,it in ipairs(made) do if reaper.ValidatePtr2(0,it,"MediaItem*") then valid=valid+1 end end
 if valid==0 then update_status="Noch keine gültige von Composition Studio erzeugte MIDI-Komposition zum Exportieren."; return end
 if ensure_title_then("midi") then return end; begin_save_panel("midi","MIDI exportieren",safe_work_title(work_title)..".mid","mid")
end
local function analysis_prompt(request,items,tracks) return [[Du analysierst das konkret übergebene MIDI-Material. Antworte musikalisch präzise als normaler Text. Erfinde nichts. Erzeuge kein MIDI und keine CS-Zeilen.]].."\nAUFTRAG:\n"..request.."\nMUSIK:\n"..music_context(items,tracks,false) end
local function composition_prompt(request,items,tracks,is_new)
 if is_new then
  return [[Komponiere jetzt das verlangte Stück vollständig. Erzeuge die Musik selbst – keinen Entwurf, keinen Formplan, kein Konzept, keine Klangbeschreibung und keine Erläuterung darüber, wie das Stück später komponiert werden könnte. Triff die musikalischen Entscheidungen unmittelbar in der Komposition: konkrete Stimmen, Tonhöhen, Dauern, Rhythmus, Harmonik, Artikulation, Dynamik und Verlauf. Die Komposition muss so vollständig und eindeutig notiert sein, dass eine nachfolgende technische Instanz sie ohne eigene musikalische Entscheidungen lediglich übertragen kann. Gib der fertigen Komposition einen kurzen Werktitel und, soweit musikalisch bestimmbar, Tonart und Tempo an. Denke nicht an MIDI-Codierung, QN-Werte, CS-Zeilen oder das technische Zielformat. Keine Analyse und keine Beschreibung der Arbeitsweise.]].."\n\nAUFTRAG:\n"..request
 end
 return [[Du komponierst Musik in Composition Studio. Nutze das konkret übergebene vorhandene Material als musikalischen Kontext und erfülle den freien Auftrag eigenständig; füge keine unnötigen Regeln hinzu. TIME_SELECTION ist nur bei ausdrücklichem Bezug auf den markierten Bereich ein Zielbereich. Eine ausgewählte TRACK_GUID kann auch ohne ausgewähltes MIDI-Item direkt Ziel sein. Jedes neu erzeugte MIDI-Item MUSS einen passenden General-MIDI-Program-Change (0-127) erhalten.
Antworte ausschließlich:
CS|unchanged|SOURCE_GUID
CS|target|SOURCE_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|track|TRACK_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|revised|SOURCE_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...]].."\nAUFTRAG:\n"..request.."\nMUSIK:\n"..music_context(items,tracks,false)
end
local function midi_translation_prompt(request,draft)
 return [[Du bist jetzt ausschließlich Notations- und MIDI-Übersetzer. Übertrage die folgende bereits fertige Komposition so vollständig und werkgetreu wie möglich in Composition-Studios MIDI-Daten. Komponiere NICHT neu, vereinfache NICHT, regularisiere NICHT den Rhythmus und ersetze keine ungewöhnlichen musikalischen Entscheidungen durch Standards. Bewahre insbesondere rhythmische Vielfalt, Pausen, Stimmführung, Phrasierung, Dynamik und Artikulation der Komposition.
Übertrage alle im Entwurf ausdrücklich vorgesehenen Tempo- und Taktartwechsel mit CSMETA. Erfinde keine Wechsel.
CSMETA|tempo|startQN|BPM
CSMETA|timesig|startQN|ZAEHLER|NENNER
Artikulation und Dynamik müssen möglichst werkgetreu in MIDI erhalten bleiben: legato durch nahezu volle oder leicht überlappende Notendauern, staccato durch deutlich verkürzte Dauern, tenuto durch nahezu volle Dauer, Akzente/marcato durch passende Velocity. Crescendo und Diminuendo dürfen zusätzlich mit CC11 Expression übertragen werden. Ausdrücklich notierte instrumentale Spielweisen dürfen durch MIDI-Controller oder Program Changes umgesetzt werden; erfinde keine Spielweisen.
Erzeuge für jedes Instrument genau eine Zeile:
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
Zusätzlich sind bei Bedarf erlaubt:
CSCTRL|NAME|startQN|CHANNEL|cc|CONTROLLER|VALUE
CSCTRL|NAME|startQN|CHANNEL|program|PROGRAM
NAME muss exakt dem NAME der CS-Zeile entsprechen. CHANNEL 0-15; CONTROLLER, VALUE und PROGRAM 0-127. PROGRAM der CS-Zeile ist General MIDI 0-127. startQN und durationQN dürfen beliebige sinnvolle Dezimalwerte haben. Antworte ausschließlich mit CSMETA-, CSCTRL- und CS-Zeilen.]].."\n\nFERTIGE KOMPOSITION:\n"..draft
end

-- Long works are translated in short independently validated sections.
local function numbered_measure_count(draft)
 local highest=0
 for n in tostring(draft or ""):gmatch("[Tt]%.%s*(%d+)") do highest=math.max(highest,tonumber(n) or 0) end
 return highest
end
local function chunk_prompt(draft,first_bar,last_bar)
 -- Send only the target bars: repeating the entire composition was unnecessarily slow.
 local header={}
 local found={}
 local current=nil
 for line in (tostring(draft or "").."\n"):gmatch("([^\n]*)\n") do
  local bar=tonumber(line:match("[Tt]%.%s*(%d+)"))
  if bar then current=bar end
  if current and current>=first_bar and current<=last_bar then found[#found+1]=line
  elseif not current and #header<20 then header[#header+1]=line end
 end
 local base_qn=(first_bar-1)*4
 return [[Übertrage den folgenden vollständigen musikalischen Abschnitt in REAPER-MIDI-Daten.
Antworte ausschließlich mit vollständigen Datenzeilen:
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CSMETA|tempo|startQN|BPM
CSMETA|timesig|startQN|ZAEHLER|NENNER
CSCTRL|NAME|startQN|CHANNEL|cc|CONTROLLER|VALUE
Alle startQN sind ABSOLUT ab Stückbeginn, nicht relativ zum Abschnitt.
Für 4/4 beginnt dieser Abschnitt bei QN ]]..base_qn..[[. Andere Taktarten entsprechend berücksichtigen.
Übertrage exakt alle Noten, Pausen, Akkorde und Dauern der Takte ]]..first_bar..[[ bis ]]..last_bar..[[, ohne Noten zu erfinden oder auszulassen. Gib jede MIDI-Note mit fünf numerischen Werten an. Gib nur diese Takte aus. Für Klavier nutze konsequent NAME=Klavier für beide Hände und MIDI-Kanal 0 (oder 1 für die linke Hand). Die Ausgabe muss vollständig sein.
STÜCKINFORMATION:
]]..table.concat(header,"\n").."\nTAKTE:\n"..table.concat(found,"\n")
end

local function check_translation_chunk(s)
 local found=false
 for line in tostring(s or ""):gmatch("[^\r\n]+") do
  line=trim(line)
  if line:match("^CS|") then
   local kind,guid,rest=line:match("^CS|([^|]+)|([^|]+)|(.+)$")
   if not kind then return false,"Unvollständiger CS-Kopf" end
   if kind=="new" or kind=="track" or kind=="target" or kind=="revised" then
    local name,program,notes=rest:match("^([^|]+)|(%d+)|(.+)$")
    if not name or not program or not parse_notes(notes) then return false,"Unvollständige oder ungültige Notenliste" end
    found=true
   elseif kind~="unchanged" then return false,"Unbekannter CS-Typ" end
  elseif not line:match("^CSMETA|") and not line:match("^CSCTRL|") then
   return false,"Zusätzlicher Text statt Daten"
  end
 end
 return found,nil
end
local function start_translation_chunk(data,key)
 local first_bar=data.chunk_first
 local last_bar=math.min(data.chunk_total,first_bar+6)
 local prompt=chunk_prompt(data.draft,first_bar,last_bar)
 diag_set("translation_prompt",prompt)
 update_status="Notenübertragung: Takte "..first_bar.."–"..last_bar.." von "..data.chunk_total
 return launch("translation_chunk",prompt,key,data)
end

local job=nil
local function ai_command(prompt,key)
 local base=temp_path(); local rq,rs,cd=base..".json",base..".out",base..".code"; local body,url,headers,win_headers
 if provider=="openai" then body='{"model":"'..json_escape(model)..'","input":"'..json_escape(prompt)..'"}'; url="https://api.openai.com/v1/responses"; win_headers={"Authorization: Bearer "..key,"Content-Type: application/json"}
 elseif provider=="anthropic" then body='{"model":"'..json_escape(model)..'","max_tokens":16000,"messages":[{"role":"user","content":"'..json_escape(prompt)..'"}]}'; url="https://api.anthropic.com/v1/messages"; win_headers={"x-api-key: "..key,"anthropic-version: 2023-06-01","Content-Type: application/json"}
 else body='{"contents":[{"parts":[{"text":"'..json_escape(prompt)..'"}]}]}'; url="https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent?key="..key; win_headers={"Content-Type: application/json"} end
 if not write_file(rq,body) then return nil,"Anfrage konnte nicht geschrieben werden: "..rq end
 if IS_WINDOWS then
  local script=windows_curl_script(nil,rq,rs,cd,win_headers,url,180)
  if not script then return nil,"PowerShell-Aufruf konnte nicht vorbereitet werden." end
  if not ps_launch(script,true) then os.remove(script); os.remove(rq); return nil,"Windows-Hintergrundprozess konnte nicht gestartet werden." end
 else
  headers=""; for _,h in ipairs(win_headers) do headers=headers.." -H "..shell_quote(h) end
  local cmd="/usr/bin/curl -sS --max-time 180 -o "..shell_quote(rs).." -w '%{http_code}' "..headers.." --data-binary @"..shell_quote(rq).." "..shell_quote(url).." > "..shell_quote(cd).." 2>/dev/null &"
  os.execute(cmd)
 end
 return {rq=rq,rs=rs,cd=cd,provider=provider,deadline=reaper.time_precise()+200},nil
end

local function ai_poll(a)
 local status=read_file(a.cd)
 if not status or trim(status)=="" then
  if reaper.time_precise()<a.deadline then return nil,nil,false end
  diag_set("api_error","Zeitlimit / Hintergrundprozess ohne Statusdatei")
  return nil,"KI-Zeitlimit erreicht; siehe Diagnose und CompositionStudioTemp.",true
 end
 status=trim(status)
 local raw=read_file(a.rs)
 -- Don't retain access credentials: API responses do not include submitted keys.
 diag_set("api_status",status); diag_set("api_stop_reason",raw and (raw:match('"stop_reason"%s*:%s*"([^"]+)"') or raw:match('"finishReason"%s*:%s*"([^"]+)"') or raw:match('"finish_reason"%s*:%s*"([^"]+)"')) or "")
 if status~="200" or not raw then
  local excerpt=(raw or ""):sub(1,1500)
  diag_set("api_response_excerpt",excerpt)
  diag_set("api_error","HTTP/Transport: "..status)
  os.remove(a.rq); os.remove(a.rs); os.remove(a.cd)
  return nil,"KI-Aufruf fehlgeschlagen ("..status.."): "..excerpt:sub(1,350),true
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
launch=function(stage,prompt,key,data) local a,e=ai_command(prompt,key); if not a then add("KI",e); busy=false; job=nil; return false end; job={stage=stage,ai=a,key=key,data=data or {},project=reaper.EnumProjects(-1,"")}; return true end

-- Local LilyPond-to-MIDI translator for unambiguous absolute-pitch piano notation.
-- Deliberately rejects unsupported syntax rather than silently losing notes.
local function lily_extract_staffs(src)
 local result,pos={},1
 while true do
  local s,e=src:find("\\new%s+Staff%s*%b\"\"",pos)
  if not s then s,e=src:find("\\new%s+Staff",pos) end
  if not s then break end
  local a=src:find("{",e+1,true); if not a then return nil,"Staff ohne Notenblock" end
  local depth,b=0,nil
  for i=a,#src do
   local ch=src:sub(i,i)
   if ch=="{" then depth=depth+1 elseif ch=="}" then depth=depth-1; if depth==0 then b=i; break end end
  end
  if not b then return nil,"Unvollständiger Staff-Block" end
  result[#result+1]=src:sub(a+1,b-1)
  pos=b+1
 end
 if #result==0 then return nil,"Keine \\new Staff-Blöcke gefunden" end
 return result
end
local function lily_parse_staff(src,channel)
 if src:find("\\relative",1,true) then return nil,"Relative Tonhöhen sind nicht zugelassen; \\absolute verwenden." end
 src=src:gsub("%%[^\n]*"," "):gsub("\\absolute%s*{"," "):gsub("[{}|]"," ")
 src=src:gsub('\\clef%s+"?[%w]+"?'," ")
 src=src:gsub("\\key%s+[%w']+%s+\\[a-zA-Z]+"," ")
 src=src:gsub("\\time%s+%d+/%d+"," ")
 src=src:gsub("\\tempo%s+[^=\n]+=%s*%d+"," ")
 src=src:gsub("\\bar%s+\"[^\"]*\""," ")
 src=src:gsub("\\(voiceOne|voiceTwo|oneVoice)"," ")
 src=src:gsub("\\(p|pp|ppp|mp|mf|f|ff|fff|<|>|!)"," ")
 src=src:gsub("[-_^][%.%-+>]"," ")
 local notes,pos,lastdur={},0,1
 local semis={c=0,d=2,e=4,f=5,g=7,a=9,b=11}
 for tok in src:gmatch("%S+") do
  if tok:sub(1,1)=="\\" then
   if not (tok=="\\absolute" or tok=="\\break" or tok=="\\pageBreak" or tok=="\\major" or tok=="\\minor" or tok=="\\numericTimeSignature") then
    return nil,"Nicht unterstützter LilyPond-Befehl: "..tok
   end
  elseif tok=="~" or tok=="(" or tok==")" or tok=="[" or tok=="]" then
   -- Slurs and ties have no separate MIDI note here; ties must be resolved explicitly.
   if tok=="~" then return nil,"Bindebögen über Notengrenzen werden noch nicht unterstützt." end
  else
   local root,alter,oct,dur,dots=tok:match("^([a-g])(isis|eses|is|es|)?([',]*)(%d*)(%.?)$")
   local rest,rdur,rdots=tok:match("^([rs])(%d*)(%.?)$")
   if not root and not rest then return nil,"Unbekannter Notenausdruck: "..tok end
   local dn=tonumber(root and dur or rdur) or lastdur
   if dn<=0 or dn>128 then return nil,"Ungültiger Notenwert" end
   lastdur=dn
   local length=4/dn
   if (root and dots or rdots)=="." then length=length*1.5 end
   if root then
    local alt=({is=1,isis=2,es=-1,eses=-2})[alter] or 0
    local octave=0
    for ch in oct:gmatch(".") do octave=octave+(ch=="'" and 1 or -1) end
    -- LilyPond c' is MIDI 60, LilyPond c is MIDI 48.
    local pitch=48+12*octave+semis[root]+alt
    if pitch<0 or pitch>127 then return nil,"Tonhöhe außerhalb MIDI 0–127" end
    notes[#notes+1]={start_qn=pos,duration_qn=length,pitch=pitch,velocity=80,channel=channel}
   end
   pos=pos+length
  end
 end
 if #notes==0 then return nil,"Stimme ohne Noten" end
 return notes,pos
end
local function lily_to_cs(src)
 local staffs,err=lily_extract_staffs(src); if not staffs then return nil,err end
 local all,maxdur={},nil
 for i,staff in ipairs(staffs) do
  local notes,duration=lily_parse_staff(staff,math.min(i-1,15))
  if not notes then return nil,"Staff "..i..": "..duration end
  if maxdur and math.abs(duration-maxdur)>0.001 then return nil,"Stimmen haben unterschiedliche Längen." end
  maxdur=duration
  for _,n in ipairs(notes) do all[#all+1]=string.format("%.6g,%.6g,%d,%d,%d",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end
 end
 local num,den=src:match("\\time%s+(%d+)%s*/%s*(%d+)")
 num,den=tonumber(num) or 4,tonumber(den) or 4
 local bpm=tonumber(src:match("\\tempo%s+[^\n=]-=%s*(%d+)")) or 90
 local measure=4*num/den
 if maxdur/measure-math.floor(maxdur/measure+0.0001)>0.001 then return nil,"Stück endet nicht an einer Taktgrenze." end
 return "CSMETA|tempo|0|"..bpm.."\nCSMETA|timesig|0|"..num.."|"..den.."\nCS|new|-|Klavier|0|"..table.concat(all,";"),math.floor(maxdur/measure+0.0001),#all
end
local function lily_composition_prompt(request)
 return [[Komponiere direkt das vollständige Musikstück als LilyPond-Partitur, KEINEN Entwurf.
Gib ausschließlich ausführbaren LilyPond-Code zurück (ohne Markdown-Codezaun).
Verwende für ein Klavierstück genau zwei \new Staff-Blöcke im \score, rechte und linke Hand.
Jede Stimme muss \absolute verwenden; benutze ausschließlich absolute LilyPond-Tonhöhen
(c' ist das mittlere C), Noten c d e f g a b, is/es-Vorzeichen, Oktavstriche,
Dauern 1,2,4,8,16 mit optionalem Punkt sowie Pausen r und einzelne Taktstriche |.
Schreibe JEDE Tonhöhe und JEDE Dauer explizit. Verwende keine \relative-Angaben,
keine Variablen, Wiederholungsbefehle, Triolen, Akkorde, Bindebögen oder
verschachtelte Stimmen. Halte die beiden Staves taktsynchron.
Ein Beispiel des erwarteten Aufbaus:
\version "2.24.3"
\score { <<
\new Staff { \absolute { \clef treble \time 4/4 \tempo 4 = 84 c'4 d'4 e'4 f'4 | } }
\new Staff { \absolute { \clef bass \time 4/4 c4 g4 c4 g4 | } }
>> }
Entwickle die musikalische Gestalt frei; vermeide mechanische Begleitmuster.
Keine Erklärungen und keine technischen MIDI-Zeilen.
AUFTRAG:
]]..request
end

local function begin_process(request)
 last_diag={version=VERSION,composition_engine=COMPOSITION_ENGINE_NAME.." "..COMPOSITION_ENGINE_VERSION,composition_engine_build=tostring(COMPOSITION_ENGINE_BUILD),provider=provider,model=model,request=request}; persist_diag(); write_file(DIAG_CACHE_PATH,diag_json()); local key=get_key(); if not key then add("KI","Kein API-Key für "..provider_name().." verfügbar."); busy=false; return end
 local items=selected_items(false); local tracks=selected_tracks(); diag_set("context",compact_context(items,tracks,false)); local prompt=CONTROLLER.."\n\nBISHERIGER DIALOG:\n"..recent_dialog().."\n\nAKTUELLER AUFTRAG:\n"..request.."\n\nKOMPAKTER REAPER-KONTEXT:\n"..compact_context(items,tracks,false); diag_set("controller_prompt",prompt); launch("controller",prompt,key,{request=request,items=items,tracks=tracks})
end

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
local function poll_job()
 if not job then return end; if reaper.EnumProjects(-1,"")~=job.project then job=nil; busy=false; update_status="KI-Auftrag wegen Projektwechsel verworfen."; return end; local text,e,done=ai_poll(job.ai); if not done then return end; local stage,data,key=job.stage,job.data,job.key; job=nil
 if not text then add("KI",e); busy=false; return end; text=trim(text)
 if stage=="lily_composition" then
  diag_set("composition_music",text)
  local midi,bars,notes=lily_to_cs(text)
  if not midi then
   diag_set("apply_result","LilyPond-Parser: "..tostring(bars))
   add("KI","LilyPond konnte nicht vollständig gelesen werden: "..tostring(bars)..". Keine Noten übertragen.")
   busy=false; return
  end
  diag_set("composition_answer",midi)
  local made,ae=apply_composition(midi,{}, {},true)
  diag_set("apply_result",made and ("created_items="..#made.."; measures="..bars.."; notes="..notes) or ("ERROR: "..tostring(ae)))
  if not made then add("KI","MIDI konnte nicht erstellt werden: "..tostring(ae)); busy=false; return end
  last_made=made
  local ids={}; for _,it in ipairs(made) do ids[#ids+1]=item_guid(it) end
  reaper.SetProjExtState(0,EXT_SECTION,"LastMadeGUIDs",table.concat(ids,"\n"))
  add("KI","LilyPond direkt übertragen: "..bars.." Takte, "..notes.." Noten, eine Klavierspur. Keine weitere KI-Übersetzung.")
  busy=false; return
 end
 if stage=="work_title" then
  local t=safe_work_title(text:gsub("^[Tt][Ii][Tt][Ee][Ll]%s*:%s*","")); if t=="" then update_status="Kein brauchbarer Werktitel erhalten."; busy=false; return end
  work_title=t; reaper.SetProjExtState(0,EXT_SECTION,TITLE_KEY,work_title); diag_set("work_title",work_title); busy=false
  if data.save_kind=="midi" then export_last_midi() elseif data.save_kind=="diagnosis" then save_diagnosis() end; return
 end
 if stage=="controller" then
  diag_set("controller_answer",text); local chat=text:match("^CHAT|(.*)$"); if chat then add("KI",trim(chat)); busy=false; return end; local ask=text:match("^ASK|(.*)$"); if ask then add("KI",trim(ask)); busy=false; return end
  local awhy=text:match("^NEED_ANALYSIS|(.*)$"); if awhy then local full=selected_items(true); if #full==0 and #data.tracks>0 then full=track_context_items(data.tracks) end; if #full==0 then add("KI","Für die Analyse ist kein MIDI-Material ausgewählt."); busy=false; return end; launch("analysis",analysis_prompt(data.request,full,data.tracks),key,data); return end
  local newwhy=text:match("^NEED_NEW|(.*)$"); local why=text:match("^NEED_MUSIC|(.*)$"); if newwhy or why then local full=newwhy and {} or selected_items(true); local tracks=newwhy and {} or data.tracks; if #full==0 and #tracks>0 then full=track_context_items(tracks) end; local cp=composition_prompt(data.request,full,tracks,newwhy~=nil); diag_set("composition_prompt",cp); data.full=full; data.music_tracks=tracks; data.is_new=newwhy~=nil; if newwhy and tostring(data.request or ""):lower():find("klavier",1,true) then
    local lp=lily_composition_prompt(data.request); diag_set("composition_prompt",lp)
    launch("lily_composition",lp,key,data)
   else launch(newwhy and "composition_music" or "composition",cp,key,data) end; return end
  if text:match("^ACTION|") then local a,pe=parse_action(text,data.items); if not a then add("KI","Ich führe nichts aus: "..pe); busy=false; return end; local ok,ae=execute_action(a); if not ok then add("KI","Die Aktion wurde nicht ausgeführt: "..tostring(ae)); else add("KI",trim(a.desc).." – erledigt. REAPER Undo kann die Änderung rückgängig machen.") end; busy=false; return end
  add("KI","Ich konnte den Auftrag nicht eindeutig einem sicheren Vorgang zuordnen und habe nichts verändert."); busy=false; return
 elseif stage=="swam_interpretation" then
  data.swam_performance=text; update_status="SWAM-Interpret wird technisch übersetzt …"; launch("swam_translation",swam_translation_prompt(data.swam_source,text),key,data); return
 elseif stage=="swam_translation" then
  local made,ae=apply_composition(text,{},{}); if not made then add("KI","SWAM-Interpretation konnte nicht angewendet werden: "..tostring(ae)); busy=false; return end
  swam_last_made=made; add("KI","SWAM-Interpretation erzeugt: "..tostring(#made).." neue Stimme(n). Die ursprüngliche Komposition blieb unverändert."); update_status="SWAM-Interpretation fertig – Original unverändert."; busy=false; return
 elseif stage=="analysis" then add("KI",text); busy=false; return
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
  stage="composition"
 end
 if stage=="composition" then
  diag_set("composition_answer",text); local made,ae=apply_composition(text,data.full,data.music_tracks,data.chunk_piano); diag_set("apply_result",made and ("created_items="..tostring(#made)) or ("ERROR: "..tostring(ae))); if not made then add("KI","Die musikalische Antwort konnte nicht sicher angewendet werden: "..tostring(ae)); busy=false; return end; local htr,hsl=initialize_halion_project(); diag_set("halion_result",string.format("auto_initialized_tracks=%d slots=%d",htr,hsl)); data.comp=text; data.made=made; last_made=made; local gs={}; for _,it in ipairs(made) do gs[#gs+1]=item_guid(it) end; reaper.SetProjExtState(0,EXT_SECTION,"LastMadeGUIDs",table.concat(gs,"\n")); persist_diag(); write_file(DIAG_CACHE_PATH,diag_json()); launch("summary",summary_prompt(data.request,text,made),key,data); return
 elseif stage=="summary" then add("KI",text); busy=false; return end
end
local function submit() local r=trim(input); if r=="" or busy then return end; input=""; info_visible=false; history_mode=false; add("Du",r); busy=true; begin_process(r) end
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

local function url_encode_path(path)
 return tostring(path or ""):gsub("([^%w%-%._~/])",function(c) return string.format("%%%02X",string.byte(c)) end)
end
local function scoreflow_pitch_key(p)
 local names={"c","c#","d","eb","e","f","f#","g","ab","a","bb","b"}
 p=math.max(0,math.min(127,math.floor(p or 60)))
 return names[(p%12)+1].."/"..tostring(math.floor(p/12)-1)
end
local SCOREFLOW_DURS={
 {4.0,"w",0},{3.0,"h",1},{2.0,"h",0},{1.5,"q",1},{1.0,"q",0},
 {0.75,"8",1},{0.5,"8",0},{0.375,"16",1},{0.25,"16",0},{0.125,"32",0}
}
local SCOREFLOW_REST_DURS={
 {4.0,"w",0},{2.0,"h",0},{1.0,"q",0},{0.5,"8",0},{0.25,"16",0},{0.125,"32",0}
}
local function scoreflow_quant(v,grid)
 grid=grid or 0.25
 return math.floor((tonumber(v) or 0)/grid+0.5)*grid
end
local function scoreflow_grid(notes)
 local shortest=math.huge
 for _,n in ipairs(notes or {}) do
  if n.duration_qn and n.duration_qn>0 then shortest=math.min(shortest,n.duration_qn) end
 end
 if shortest<0.19 then return 0.125 end
 return 0.25
end
local function scoreflow_nearest_duration(qn,grid)
 qn=math.max(grid or 0.25,tonumber(qn) or 1)
 local best=SCOREFLOW_DURS[#SCOREFLOW_DURS]; local bd=math.huge
 for _,d in ipairs(SCOREFLOW_DURS) do
  if d[1]+1e-8 >= (grid or 0.25) then
   local e=math.abs(qn-d[1])
   if e<bd then best=d; bd=e end
  end
 end
 return best[2],best[3],best[1]
end
local function scoreflow_note_json(keys,qn,is_rest,csid,grid)
 local dur,dots=scoreflow_nearest_duration(qn,grid)
 local kk={}
 for _,k in ipairs(keys or {}) do kk[#kk+1]='"'..json_escape(k)..'"' end
 return '{"keys":['..table.concat(kk,",")..'],"duration":"'..dur..'","dots":'..tostring(dots)..',"rest":'..(is_rest and "true" or "false")..(csid and (',"csid":'..tostring(csid)) or "")..'}'
end
local function scoreflow_append_rests(out,gap,grid)
 gap=scoreflow_quant(math.max(0,tonumber(gap) or 0),grid)
 local guard=0
 while gap>grid/2 and guard<64 do
  guard=guard+1
  local chosen=nil
  for _,d in ipairs(SCOREFLOW_REST_DURS) do
   if d[1]>=grid-1e-8 and d[1]<=gap+1e-8 then chosen=d; break end
  end
  chosen=chosen or {grid,grid<=0.125 and "32" or "16",0}
  out[#out+1]='{"keys":[],"duration":"'..chosen[2]..'","dots":0,"rest":true}'
  gap=scoreflow_quant(gap-chosen[1],grid)
 end
end
local function scoreflow_staff_mode(notes,items)
 local lo,hi,sum,cnt=127,0,0,0
 for _,x in ipairs(notes or {}) do
  local p=x.pitch or 60
  lo=math.min(lo,p); hi=math.max(hi,p); sum=sum+p; cnt=cnt+1
 end
 local avg=(cnt>0) and (sum/cnt) or 60

 -- Musical register wins over potentially stale track/take/plugin names.
 -- Clear violin/treble range:
 if cnt>0 and lo>=55 and avg>=67 then return "treble" end
 -- Clear bass/cello range:
 if cnt>0 and hi<=67 and avg<=55 then return "bass" end

 local names={}
 for _,it in ipairs(items or score_state.items or {}) do
  names[#names+1]=string.lower(tostring(it.track_name or "").." "..tostring(it.take_name or ""))
 end
 local n=table.concat(names," ")

 -- Piano/keyboard remains explicit because wide range is expected.
 if n:find("klavier",1,true) or n:find("piano",1,true) or n:find("keyboard",1,true) then return "piano" end

 -- Instrument names are only secondary hints and must be compatible with range.
 if (n:find("violin",1,true) or n:find("violine",1,true) or n:find("flöte",1,true) or n:find("flute",1,true)
     or n:find("klarinette",1,true) or n:find("clarinet",1,true) or n:find("oboe",1,true) or n:find("viola",1,true))
     and (cnt==0 or avg>=58) then return "treble" end
 if (n:find("cello",1,true) or n:find("violoncello",1,true) or n:find("kontrabass",1,true)
     or n:find("double bass",1,true) or n:find("fagott",1,true))
     and (cnt==0 or avg<=61) then return "bass" end

 -- Generic fallback from pitch distribution.
 if lo>=52 and hi-lo<36 then return "treble" end
 if hi<=69 and hi-lo<36 then return "bass" end
 return "piano"
end

local function scoreflow_part_label(part_items,part_notes,part_index,name_counts)
 local raw=(part_items[1] and part_items[1].track_name) or ""
 raw=tostring(raw or "")
 local lower=string.lower(raw)
 local lo,hi,sum,cnt=127,0,0,0
 for _,x in ipairs(part_notes or {}) do
  local p=x.pitch or 60; lo=math.min(lo,p); hi=math.max(hi,p); sum=sum+p; cnt=cnt+1
 end
 local avg=(cnt>0) and sum/cnt or 60

 -- Don't expose a clearly contradictory stale SWAM/plugin-style label.
 local suspicious=false
 if lower:find("cello",1,true) and avg>=64 then suspicious=true end
 if lower:find("bass",1,true) and avg>=67 then suspicious=true end
 if lower=="" then suspicious=true end

 if suspicious then
  return "Part "..tostring(part_index)
 end

 local c=(name_counts and name_counts[raw]) or 1
 if c>1 then return raw.." · "..tostring(part_index) end
 return raw
end
local function scoreflow_voice_json(notes,mstart,mend,staff,mode,grid)
 local ev={}
 for _,n in ipairs(notes) do
  local which
  if mode=="treble" then which="treble"
  elseif mode=="bass" then which="bass"
  else which=(n.pitch>=60) and "treble" or "bass" end
  local qs=scoreflow_quant(n.start_qn,grid)
  if which==staff and qs>=mstart-0.0001 and qs<mend-0.0001 then
   ev[#ev+1]={src=n,start=qs,dur=math.max(grid,scoreflow_quant(n.duration_qn,grid)),pitch=n.pitch}
  end
 end
 table.sort(ev,function(a,b)
  if math.abs(a.start-b.start)>0.0001 then return a.start<b.start end
  return a.pitch<b.pitch
 end)
 local groups={}
 for _,n in ipairs(ev) do
  local g=groups[#groups]
  if not g or math.abs(g.start-n.start)>grid/4 then
   g={start=n.start,notes={}}; groups[#groups+1]=g
  end
  g.notes[#g.notes+1]=n
 end
 local out={}
 local cursor=mstart
 for gi,g in ipairs(groups) do
  if g.start>cursor+grid/2 then
   scoreflow_append_rests(out,g.start-cursor,grid)
   cursor=g.start
  end
  if g.start>=cursor-grid/2 then
   local keys={}; local rawdur=grid
   for _,n in ipairs(g.notes) do
    keys[#keys+1]=scoreflow_pitch_key(n.pitch)
    rawdur=math.max(rawdur,n.dur)
   end
   local nextStart=(groups[gi+1] and groups[gi+1].start) or mend
   local slot=math.max(grid,scoreflow_quant(nextStart-g.start,grid))
   local dur=rawdur
   -- MIDI gate length is performance articulation, not necessarily notation.
   -- For short notes that clearly occupy the next onset slot, notate the slot
   -- instead of creating tiny values plus rests.
   if slot<=1.0+1e-8 and rawdur<slot*0.72 then dur=slot
   elseif rawdur>slot then dur=slot
   end
   dur=math.min(dur,mend-g.start)
   local _,_,repr=scoreflow_nearest_duration(dur,grid)
   out[#out+1]=scoreflow_note_json(keys,dur,false,g.notes[1] and g.notes[1].src.csid or nil,grid)
   cursor=math.max(cursor,g.start+repr)
  end
 end
 if cursor<mend-grid/2 then scoreflow_append_rests(out,mend-cursor,grid) end
 return "["..table.concat(out,",").."]"
end
local function scoreflow_part_json(part_notes,part_items,m0,m1,part_index,name_counts)
 local grid=scoreflow_grid(part_notes)
 local mode=scoreflow_staff_mode(part_notes,part_items)
 local measures={}
 local prev_ts=nil
 for mi=m0,m1 do
  local _,ms,me,num,den=reaper.TimeMap_GetMeasureInfo(0,mi)
  ms=tonumber(ms) or (mi*4); me=tonumber(me) or (ms+4)
  num=tonumber(num) or 4; den=tonumber(den) or 4
  local ts=tostring(num).."/"..tostring(den)
  local extra=""
  if prev_ts and ts~=prev_ts then extra=',"_ts":"'..ts..'"' end
  prev_ts=ts
  local tre=scoreflow_voice_json(part_notes,ms,me,"treble",mode,grid)
  local bas=scoreflow_voice_json(part_notes,ms,me,"bass",mode,grid)
  measures[#measures+1]='{"treble":'..tre..',"bass":'..bas..extra..'}'
 end
 local staffMode=(mode=="treble" and "single-treble") or (mode=="bass" and "single-bass") or "grand"
 local name=scoreflow_part_label(part_items,part_notes,part_index,name_counts)
 return '{"name":"'..json_escape(name)..'","staffMode":"'..staffMode..'","measures":['..table.concat(measures,",")..']}'
end
local function scoreflow_score_json()
 local notes=score_state.notes or {}
 if #notes==0 then return nil,"Keine Noten in der aktuellen REAPER-Auswahl." end

 local minq,maxq=notes[1].start_qn,notes[1].start_qn+notes[1].duration_qn
 for _,n in ipairs(notes) do minq=math.min(minq,n.start_qn); maxq=math.max(maxq,n.start_qn+n.duration_qn) end
 local m0=select(1,reaper.TimeMap_QNToMeasures(0,minq))
 local m1=select(1,reaper.TimeMap_QNToMeasures(0,math.max(minq,maxq-1e-7)))
 m0=math.max(0,tonumber(m0) or 0); m1=math.max(m0,tonumber(m1) or m0)

 local _,_,_,first_num,first_den,first_tempo=reaper.TimeMap_GetMeasureInfo(0,m0)
 first_num=tonumber(first_num) or 4; first_den=tonumber(first_den) or 4
 first_tempo=tonumber(first_tempo) or reaper.Master_GetTempo()
 local timesig=tostring(first_num).."/"..tostring(first_den)

 local byTrack,order={},{}
 for _,it in ipairs(score_state.items or {}) do
  local g=it.track_guid or it.track_name
  if not byTrack[g] then byTrack[g]={notes={},items={}}; order[#order+1]=g end
  byTrack[g].items[#byTrack[g].items+1]=it
 end
 for _,n in ipairs(notes) do
  local g=n.track_guid or n.track_name
  if not byTrack[g] then byTrack[g]={notes={},items={}}; order[#order+1]=g end
  byTrack[g].notes[#byTrack[g].notes+1]=n
 end

 if #order<=1 then
  local p=byTrack[order[1]]
  local mode=scoreflow_staff_mode(p.notes,p.items)
  local grid=scoreflow_grid(p.notes)
  local measures={}; local prev_ts=nil
  for mi=m0,m1 do
   local _,ms,me,num,den=reaper.TimeMap_GetMeasureInfo(0,mi)
   ms=tonumber(ms) or (mi*4); me=tonumber(me) or (ms+4)
   num=tonumber(num) or 4; den=tonumber(den) or 4
   local ts=tostring(num).."/"..tostring(den); local extra=""
   if prev_ts and ts~=prev_ts then extra=',"_ts":"'..ts..'"' end
   prev_ts=ts
   local tre=scoreflow_voice_json(p.notes,ms,me,"treble",mode,grid)
   local bas=scoreflow_voice_json(p.notes,ms,me,"bass",mode,grid)
   measures[#measures+1]='{"treble":'..tre..',"bass":'..bas..extra..'}'
  end
  local staffMode=(mode=="treble" and "single-treble") or (mode=="bass" and "single-bass") or "grand"
  return '{"title":"Composition Studio","instrument":"piano","staffMode":"'..staffMode..'","timeSignature":"'..timesig..'","keySignature":"C","tempo":'..string.format("%.2f",first_tempo)..',"measures":['..table.concat(measures,",")..'],"cursor":{"measure":-1,"voice":"","index":-1}}'
 end

 local name_counts={}
 for _,g in ipairs(order) do
  local p=byTrack[g]
  local nm=(p.items[1] and p.items[1].track_name) or ""
  name_counts[nm]=(name_counts[nm] or 0)+1
 end
 local parts={}
 local pi=0
 for _,g in ipairs(order) do
  local p=byTrack[g]
  if #p.notes>0 then
   pi=pi+1
   parts[#parts+1]=scoreflow_part_json(p.notes,p.items,m0,m1,pi,name_counts)
  end
 end
 return '{"title":"Composition Studio","instrument":"ensemble","timeSignature":"'..timesig..'","keySignature":"C","tempo":'..string.format("%.2f",first_tempo)..',"parts":['..table.concat(parts,",")..'],"cursor":{"measure":-1,"voice":"","index":-1}}'
end

local function xml_escape(v)
 return tostring(v or ""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
end
local function vrv_pitch(p)
 local names={
  {"c",nil},{"c","s"},{"d",nil},{"d","s"},{"e",nil},{"f",nil},
  {"f","s"},{"g",nil},{"g","s"},{"a",nil},{"a","s"},{"b",nil}
 }
 p=math.max(0,math.min(127,math.floor(p or 60)))
 local x=names[(p%12)+1]
 return x[1],math.floor(p/12)-1,x[2]
end
local VRV_DURS={
 {4.0,"1",0},{3.0,"2",1},{2.0,"2",0},{1.5,"4",1},{1.0,"4",0},
 {0.75,"8",1},{0.5,"8",0},{0.375,"16",1},{0.25,"16",0},{0.125,"32",0}
}
local function vrv_nearest_duration(qn,grid)
 qn=math.max(grid or 0.25,tonumber(qn) or 1)
 local best=VRV_DURS[#VRV_DURS]; local bd=math.huge
 for _,d in ipairs(VRV_DURS) do
  if d[1]+1e-8 >= (grid or 0.25) then
   local e=math.abs(qn-d[1])
   if e<bd then best=d; bd=e end
  end
 end
 return best[2],best[3],best[1]
end
local function vrv_rest_entries(out,gap,grid,startpos)
 gap=scoreflow_quant(math.max(0,tonumber(gap) or 0),grid)
 local pos=tonumber(startpos) or 0
 local guard=0
 while gap>grid/2 and guard<64 do
  guard=guard+1
  local chosen=nil
  for _,d in ipairs(VRV_DURS) do
   if d[3]==0 and d[1]>=grid-1e-8 and d[1]<=gap+1e-8 then chosen=d; break end
  end
  chosen=chosen or {grid,grid<=0.125 and "32" or "16",0}
  out[#out+1]={xml='<rest dur="'..chosen[2]..'"/>',start=pos,dur=chosen[1],beamable=false}
  pos=pos+chosen[1]
  gap=scoreflow_quant(gap-chosen[1],grid)
 end
 return pos
end

local function vrv_beam_entries(entries,mstart,beatSpan)
 beatSpan=tonumber(beatSpan) or 1.0
 local out={}
 local run={}
 local runBeat=nil
 local function flush()
  if #run>=2 then
   local xs={}
   for _,e in ipairs(run) do xs[#xs+1]=e.xml end
   out[#out+1]="<beam>"..table.concat(xs).."</beam>"
  else
   for _,e in ipairs(run) do out[#out+1]=e.xml end
  end
  run={}; runBeat=nil
 end
 for _,e in ipairs(entries or {}) do
  local beat=math.floor(((e.start or mstart)-mstart)/beatSpan+1e-7)
  if e.beamable then
   if #run>0 and beat~=runBeat then flush() end
   runBeat=beat
   run[#run+1]=e
  else
   if #run>0 then flush() end
   out[#out+1]=e.xml
  end
 end
 if #run>0 then flush() end
 return table.concat(out)
end

local function vrv_layer_xml(notes,mstart,mend,mode,staff_kind,grid,beatSpan)
 local ev={}
 for _,n in ipairs(notes or {}) do
  local use=true
  if mode=="piano" then
   use=(staff_kind=="treble" and n.pitch>=60) or (staff_kind=="bass" and n.pitch<60)
  end
  if use then
   local qs=scoreflow_quant(n.start_qn,grid)
   if qs>=mstart-0.0001 and qs<mend-0.0001 then
    ev[#ev+1]={src=n,start=qs,dur=math.max(grid,scoreflow_quant(n.duration_qn,grid)),pitch=n.pitch}
   end
  end
 end
 table.sort(ev,function(a,b)
  if math.abs(a.start-b.start)>0.0001 then return a.start<b.start end
  return a.pitch<b.pitch
 end)
 local groups={}
 for _,n in ipairs(ev) do
  local g=groups[#groups]
  if not g or math.abs(g.start-n.start)>grid/4 then
   g={start=n.start,notes={}}; groups[#groups+1]=g
  end
  g.notes[#g.notes+1]=n
 end
 local entries={}
 local cursor=mstart
 for gi,g in ipairs(groups) do
  if g.start>cursor+grid/2 then
   cursor=vrv_rest_entries(entries,g.start-cursor,grid,cursor)
  end
  if g.start>=cursor-grid/2 then
   local rawdur=grid
   for _,n in ipairs(g.notes) do rawdur=math.max(rawdur,n.dur) end
   local nextStart=(groups[gi+1] and groups[gi+1].start) or mend
   local slot=math.max(grid,scoreflow_quant(nextStart-g.start,grid))
   local dur=rawdur
   if slot<=1.0+1e-8 and rawdur<slot*0.72 then dur=slot
   elseif rawdur>slot then dur=slot end
   dur=math.min(dur,mend-g.start)
   local d,dots,repr=vrv_nearest_duration(dur,grid)
   local dotattr=dots>0 and (' dots="'..tostring(dots)..'"') or ""
   local xml
   if #g.notes==1 then
    local n=g.notes[1]
    local pname,oct,accid=vrv_pitch(n.pitch)
    local acc=accid and (' accid="'..accid..'"') or ""
    xml='<note xml:id="csn'..tostring(n.src.csid)..'" pname="'..pname..'" oct="'..tostring(oct)..'" dur="'..d..'"'..dotattr..acc..'/>'
   else
    local chord={'<chord dur="'..d..'"'..dotattr..'>'}
    for _,n in ipairs(g.notes) do
     local pname,oct,accid=vrv_pitch(n.pitch)
     local acc=accid and (' accid="'..accid..'"') or ""
     chord[#chord+1]='<note xml:id="csn'..tostring(n.src.csid)..'" pname="'..pname..'" oct="'..tostring(oct)..'"'..acc..'/>'
    end
    chord[#chord+1]='</chord>'
    xml=table.concat(chord)
   end
   -- Beam eighths and shorter metrically, never across the current beat group.
   entries[#entries+1]={xml=xml,start=g.start,dur=repr,beamable=(repr<=0.5+1e-8)}
   cursor=math.max(cursor,g.start+repr)
  end
 end
 if cursor<mend-grid/2 then vrv_rest_entries(entries,mend-cursor,grid,cursor) end
 if #entries==0 then return '<mRest/>' end
 return vrv_beam_entries(entries,mstart,beatSpan or 1.0)
end
local function verovio_score_mei()
 local notes=score_state.notes or {}
 if #notes==0 then return nil,"Keine Noten in der aktuellen REAPER-Auswahl." end

 local minq,maxq=notes[1].start_qn,notes[1].start_qn+notes[1].duration_qn
 for _,n in ipairs(notes) do minq=math.min(minq,n.start_qn); maxq=math.max(maxq,n.start_qn+n.duration_qn) end
 local m0=select(1,reaper.TimeMap_QNToMeasures(0,minq))
 local m1=select(1,reaper.TimeMap_QNToMeasures(0,math.max(minq,maxq-1e-7)))
 m0=math.max(0,tonumber(m0) or 0); m1=math.max(m0,tonumber(m1) or m0)

 local byTrack,order={},{}
 for _,it in ipairs(score_state.items or {}) do
  local g=it.track_guid or it.track_name
  if not byTrack[g] then byTrack[g]={notes={},items={}}; order[#order+1]=g end
  byTrack[g].items[#byTrack[g].items+1]=it
 end
 for _,n in ipairs(notes) do
  local g=n.track_guid or n.track_name
  if not byTrack[g] then byTrack[g]={notes={},items={}}; order[#order+1]=g end
  byTrack[g].notes[#byTrack[g].notes+1]=n
 end

 local staves={}
 local staffNo=0
 local name_counts={}
 for _,g in ipairs(order) do
  local p=byTrack[g]; local nm=(p.items[1] and p.items[1].track_name) or ""
  name_counts[nm]=(name_counts[nm] or 0)+1
 end
 local pi=0
 for _,g in ipairs(order) do
  local p=byTrack[g]
  if #p.notes>0 then
   pi=pi+1
   local mode=scoreflow_staff_mode(p.notes,p.items)
   local label=scoreflow_part_label(p.items,p.notes,pi,name_counts)
   local grid=scoreflow_grid(p.notes)
   if mode=="piano" then
    staffNo=staffNo+1; local t=staffNo
    staffNo=staffNo+1; local b=staffNo
    staves[#staves+1]={part=p,mode=mode,kind="piano",label=label,grid=grid,treble=t,bass=b}
   else
    staffNo=staffNo+1
    staves[#staves+1]={part=p,mode=mode,kind="single",label=label,grid=grid,staff=staffNo}
   end
  end
 end

 local _,_,_,first_num,first_den=reaper.TimeMap_GetMeasureInfo(0,m0)
 first_num=tonumber(first_num) or 4; first_den=tonumber(first_den) or 4

 local head={}
 head[#head+1]='<?xml version="1.0" encoding="UTF-8"?>'
 head[#head+1]='<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.1">'
 head[#head+1]='<meiHead><fileDesc><titleStmt><title>Composition Studio</title></titleStmt><pubStmt/></fileDesc></meiHead>'
 head[#head+1]='<music><body><mdiv><score>'
 head[#head+1]='<scoreDef meter.count="'..tostring(first_num)..'" meter.unit="'..tostring(first_den)..'"><staffGrp>'
 for _,sp in ipairs(staves) do
  if sp.kind=="piano" then
   head[#head+1]='<staffGrp symbol="brace" bar.thru="true">'
   head[#head+1]='<staffDef n="'..sp.treble..'" lines="5" clef.shape="G" clef.line="2" label="'..xml_escape(sp.label)..'"/>'
   head[#head+1]='<staffDef n="'..sp.bass..'" lines="5" clef.shape="F" clef.line="4"/>'
   head[#head+1]='</staffGrp>'
  else
   local shape,line=sp.mode=="bass" and "F" or "G",sp.mode=="bass" and 4 or 2
   head[#head+1]='<staffDef n="'..sp.staff..'" lines="5" clef.shape="'..shape..'" clef.line="'..line..'" label="'..xml_escape(sp.label)..'"/>'
  end
 end
 head[#head+1]='</staffGrp></scoreDef><section>'

 local prev_num,prev_den=first_num,first_den
 for mi=m0,m1 do
  local _,ms,me,num,den=reaper.TimeMap_GetMeasureInfo(0,mi)
  ms=tonumber(ms) or mi*4; me=tonumber(me) or ms+4
  num=tonumber(num) or prev_num; den=tonumber(den) or prev_den
  local beatSpan=(den==8 and num>3 and num%3==0) and 1.5 or (4.0/den)
  if mi>m0 and (num~=prev_num or den~=prev_den) then
   head[#head+1]='<scoreDef meter.count="'..tostring(num)..'" meter.unit="'..tostring(den)..'"/>'
  end
  prev_num,prev_den=num,den
  head[#head+1]='<measure n="'..tostring(mi-m0+1)..'">'
  for _,sp in ipairs(staves) do
   if sp.kind=="piano" then
    head[#head+1]='<staff n="'..sp.treble..'"><layer n="1">'..vrv_layer_xml(sp.part.notes,ms,me,"piano","treble",sp.grid,beatSpan)..'</layer></staff>'
    head[#head+1]='<staff n="'..sp.bass..'"><layer n="1">'..vrv_layer_xml(sp.part.notes,ms,me,"piano","bass",sp.grid,beatSpan)..'</layer></staff>'
   else
    local k=sp.mode=="bass" and "bass" or "treble"
    head[#head+1]='<staff n="'..sp.staff..'"><layer n="1">'..vrv_layer_xml(sp.part.notes,ms,me,sp.mode,k,sp.grid,beatSpan)..'</layer></staff>'
   end
  end
  head[#head+1]='</measure>'
 end
 head[#head+1]='</section></score></mdiv></body></music></mei>'
 return table.concat(head)
end

local function verovio_host_html(mei)
 local encoded='"'..json_escape(mei)..'"'
 return [[<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Composition Studio – Notation</title>
<style>
html,body{margin:0;padding:0;background:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#111}
#top{position:sticky;top:0;z-index:20;background:#f5f5f5;border-bottom:1px solid #bbb;padding:7px 10px;font-size:13px;display:flex;flex-direction:column;gap:6px}
.cs-row{display:flex;gap:7px;align-items:center;flex-wrap:wrap} #top button{font-size:14px;padding:5px 13px;min-width:42px}
#cs-status{margin-left:8px;color:#444}.cs-label{color:#555}
#notation-container{position:relative;padding:10px 14px 28px 14px;background:#fff;min-height:300px}
#notation-container svg{display:block;max-width:100%;height:auto}
#selection-layer{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none}
#drag-preview{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none;z-index:25}
#drag-preview svg{position:absolute;left:0;top:0;width:100%;height:100%;overflow:visible}
.cs-sel{position:absolute;background:rgba(0,102,204,.16);border:2px solid rgba(0,102,204,.75);border-radius:4px;box-sizing:border-box}
.cs-ghost-guide{position:absolute;border-left:1px dashed rgba(0,102,204,.65);border-top:1px dashed rgba(0,102,204,.65);pointer-events:none}
#drag-box{position:absolute;border:1px dashed #0066cc;background:rgba(0,102,204,.08);pointer-events:none;display:none;z-index:30}
#error{padding:16px;color:#b00020}
</style></head><body>
<div id="top">
<div class="cs-row"><button onclick="csTransport('start')">|◀</button><button onclick="csTransport('play')">▶</button><button onclick="csTransport('pause')">Ⅱ</button><button onclick="csTransport('stop')">■</button><span class="cs-label">REAPER Player</span></div>
<div class="cs-row"><button onclick="csCmd('pitch',-1)">−1 Halbton</button><button onclick="csCmd('pitch',1)">+1 Halbton</button><button onclick="csCmd('duration',0.5)">½ Dauer</button><button onclick="csCmd('duration',2)">2× Dauer</button><span id="cs-status">Verovio wird geladen …</span></div>
</div>
<div id="notation-container"><div id="selection-layer"></div><div id="drag-preview"></div><div id="drag-box"></div></div>
<script>
window.csSelectedIds=[];
function csBridgeReady(){return !!(window.compositionStudioBridge&&window.compositionStudioBridge.postMessage);}
function csSend(obj){try{if(csBridgeReady()){window.compositionStudioBridge.postMessage(JSON.stringify(obj));return true;}}catch(e){}return false;}
function csSetStatus(t){const e=document.getElementById('cs-status');if(e)e.textContent=t;}
function csTransport(action){if(!csSend({type:'transport',action}))csSetStatus('Bridge fehlt');}
function csCmd(kind,value){const ids=window.csSelectedIds||[];if(!ids.length){csSetStatus('Zuerst Note(n) markieren');return;}if(!csSend({type:'command',csids:ids.join(','),kind,value}))csSetStatus('Bridge fehlt');}
</script>
<script type="module">
import createVerovioModule from 'https://cdn.jsdelivr.net/npm/verovio@6.3.0/dist/verovio-module.mjs';
import { VerovioToolkit } from 'https://cdn.jsdelivr.net/npm/verovio@6.3.0/dist/verovio.mjs';

let mei=]]..encoded..[[;
let toolkit=null,drag=null;
const container=document.getElementById('notation-container');
const layer=document.getElementById('selection-layer');
const preview=document.getElementById('drag-preview');
const box=document.getElementById('drag-box');

function idFromEl(el){const g=el&&el.closest?el.closest('[id^="csn"]'):null;if(!g)return null;const m=g.id.match(/^csn(\d+)$/);return m?Number(m[1]):null;}
function noteEl(id){return document.getElementById('csn'+id);}
function refreshSelection(){
 layer.innerHTML='';
 const cr=container.getBoundingClientRect();
 for(const id of window.csSelectedIds||[]){
  const el=noteEl(id); if(!el)continue;
  const r=el.getBoundingClientRect(); const d=document.createElement('div'); d.className='cs-sel';
  d.style.left=(r.left-cr.left+container.scrollLeft-3)+'px';d.style.top=(r.top-cr.top+container.scrollTop-3)+'px';
  d.style.width=(r.width+6)+'px';d.style.height=(r.height+6)+'px';layer.appendChild(d);
 }
 csSetStatus((window.csSelectedIds||[]).length+' Note(n) markiert · '+(csBridgeReady()?'Bridge aktiv':'Bridge fehlt'));
}
function allNoteIdsInRect(rect){
 const out=[];
 for(const el of container.querySelectorAll('[id^="csn"]')){
  const m=el.id.match(/^csn(\d+)$/);if(!m)continue;const r=el.getBoundingClientRect();
  if(!(r.right<rect.left||r.left>rect.right||r.bottom<rect.top||r.top>rect.bottom))out.push(Number(m[1]));
 }
 return out;
}
function beginMovePreview(){
 preview.innerHTML='';
 const cr=container.getBoundingClientRect();
 const ns='http://www.w3.org/2000/svg';
 const ov=document.createElementNS(ns,'svg');
 ov.setAttribute('width',String(container.scrollWidth));
 ov.setAttribute('height',String(container.scrollHeight));
 ov.setAttribute('viewBox','0 0 '+container.scrollWidth+' '+container.scrollHeight);
 const grp=document.createElementNS(ns,'g');
 grp.setAttribute('id','cs-ghost-group');
 grp.setAttribute('opacity','0.78');
 grp.style.filter='drop-shadow(0 0 1px rgba(0,102,204,.9))';
 ov.appendChild(grp);

 let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
 for(const id of window.csSelectedIds||[]){
  const el=noteEl(id); if(!el)continue;
  const r=el.getBoundingClientRect();
  minX=Math.min(minX,r.left-cr.left+container.scrollLeft);
  minY=Math.min(minY,r.top-cr.top+container.scrollTop);
  maxX=Math.max(maxX,r.right-cr.left+container.scrollLeft);
  maxY=Math.max(maxY,r.bottom-cr.top+container.scrollTop);

  const clone=el.cloneNode(true);
  clone.removeAttribute('id');
  const svg=el.ownerSVGElement;
  if(svg){
   const srect=svg.getBoundingClientRect();
   const tx=srect.left-cr.left+container.scrollLeft;
   const ty=srect.top-cr.top+container.scrollTop;
   const holder=document.createElementNS(ns,'g');
   holder.setAttribute('transform','translate('+tx+','+ty+')');
   holder.appendChild(clone);
   grp.appendChild(holder);
  }
 }
 preview.appendChild(ov);

 const guide=document.createElement('div');
 guide.className='cs-ghost-guide';
 guide.id='cs-ghost-guide';
 if(isFinite(minX)){
  guide.style.left=minX+'px';
  guide.style.top=minY+'px';
  guide.style.width=Math.max(12,maxX-minX)+'px';
  guide.style.height=Math.max(12,maxY-minY)+'px';
 }
 preview.appendChild(guide);
 preview.dataset.baseX=isFinite(minX)?String(minX):'0';
 preview.dataset.baseY=isFinite(minY)?String(minY):'0';
}
function previewMove(dx,dy){
 const q=dragQuant(dx,dy);
 const snapDx=q.dq*28;
 const snapDy=-q.dp*5;
 const grp=document.getElementById('cs-ghost-group');
 if(grp)grp.setAttribute('transform','translate('+snapDx+','+snapDy+')');
 const guide=document.getElementById('cs-ghost-guide');
 if(guide)guide.style.transform='translate('+snapDx+'px,'+snapDy+'px)';
 return q;
}
function clearPreview(){
 preview.innerHTML='';
}
function dragQuant(dx,dy){
 const dp=Math.round(-dy/5);
 const dq=Math.round((dx/28)/0.25)*0.25;
 return {dp,dq};
}
function bindInteraction(){
 container.onpointerdown=(e)=>{
  if(e.button!==0)return;
  const id=idFromEl(e.target);
  drag={id,startX:e.clientX,startY:e.clientY,moved:false,mode:id?'move':'select'};
  if(id){
   if(!(window.csSelectedIds||[]).includes(id))window.csSelectedIds=[id];
   refreshSelection();
   beginMovePreview();
  }else{
   box.style.display='block';box.style.left=(e.clientX-container.getBoundingClientRect().left)+'px';box.style.top=(e.clientY-container.getBoundingClientRect().top)+'px';box.style.width='0';box.style.height='0';
  }
  try{container.setPointerCapture(e.pointerId);}catch(_){}
 };
 container.onpointermove=(e)=>{
  if(!drag)return;const dx=e.clientX-drag.startX,dy=e.clientY-drag.startY;if(Math.abs(dx)>4||Math.abs(dy)>4)drag.moved=true;
  if(drag.mode==='select'&&drag.moved){
   const cr=container.getBoundingClientRect(),x0=drag.startX-cr.left,y0=drag.startY-cr.top,x=e.clientX-cr.left,y=e.clientY-cr.top;
   box.style.left=Math.min(x0,x)+'px';box.style.top=Math.min(y0,y)+'px';box.style.width=Math.abs(x-x0)+'px';box.style.height=Math.abs(y-y0)+'px';
  }else if(drag.mode==='move'&&drag.moved){
   const q=previewMove(dx,dy);
   const key=q.dp+':'+q.dq;
   if(drag.lastQ!==key){
    drag.lastQ=key;
    csSetStatus('Ziel: '+(q.dp>=0?'+':'')+q.dp+' HT · '+(q.dq>=0?'+':'')+q.dq+' Viertel');
   }
  }
 };
 container.onpointerup=(e)=>{
  if(!drag)return;
  const d=drag;drag=null;box.style.display='none';
  if(d.mode==='move'){
   if(d.moved){
    const dx=e.clientX-d.startX,dy=e.clientY-d.startY;
    const q=dragQuant(dx,dy);
    if(q.dp!==0||q.dq!==0){
     if(!csSend({type:'move',csids:(window.csSelectedIds||[]).join(','),dpitch:q.dp,dqn:q.dq}))clearPreview();
    }else clearPreview();
   }else if(d.id){
    clearPreview();
    window.csSelectedIds=[d.id];refreshSelection();csSend({type:'select',csids:String(d.id)});
   }
  }else{
   if(d.moved){
    const rect={left:Math.min(d.startX,e.clientX),right:Math.max(d.startX,e.clientX),top:Math.min(d.startY,e.clientY),bottom:Math.max(d.startY,e.clientY)};
    window.csSelectedIds=allNoteIdsInRect(rect);refreshSelection();if(window.csSelectedIds.length)csSend({type:'select',csids:window.csSelectedIds.join(',')});
   }else{
    window.csSelectedIds=[];refreshSelection();
   }
  }
 };
 container.onpointercancel=()=>{
  if(drag&&drag.mode==='move')clearPreview();
  drag=null;box.style.display='none';
 };
}
function renderCurrent(){
 if(!toolkit)return;
 clearPreview();
 toolkit.loadData(mei);
 toolkit.setOptions({pageWidth:2800,pageHeight:5000,scale:42,adjustPageHeight:true,breaks:'auto',header:'none',footer:'none',spacingStaff:8,spacingSystem:12,justifyVertically:false});
 const pages=toolkit.getPageCount();let html='';
 for(let p=1;p<=pages;p++)html+=toolkit.renderToSVG(p,{});
 const old=container.querySelectorAll('svg,.vrv-page');old.forEach(x=>x.remove());
 const wrap=document.createElement('div');wrap.className='vrv-page';wrap.innerHTML=html;container.insertBefore(wrap,layer);
 bindInteraction();refreshSelection();
}
window.csUpdateMEI=function(next){mei=next;renderCurrent();};
try{
 const mod=await createVerovioModule();
 toolkit=new VerovioToolkit(mod);
 renderCurrent();
 csSetStatus('Verovio · '+(csBridgeReady()?'Bridge aktiv':'Bridge fehlt')+' · Note(n) markieren');
}catch(e){
 document.body.insertAdjacentHTML('beforeend','<div id="error">Verovio-Fehler: '+String(e)+'</div>');
}
</script></body></html>]]
end

local function scoreflow_host_html(score_json)
 local base="https://cdn.jsdelivr.net/gh/IlyaSkorik/scoreflow@"..SCOREFLOW_COMMIT.."/assets/www/"
 return [[<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Composition Studio – Notation</title>
<script src="]]..base..[[js/vexflow.js"></script>
<style>
html,body{margin:0;padding:0;background:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#111}
#top{position:sticky;top:0;z-index:10;background:#f5f5f5;border-bottom:1px solid #bbb;padding:7px 10px;font-size:13px;display:flex;flex-direction:column;gap:6px;align-items:stretch} .cs-row{display:flex;gap:7px;align-items:center;flex-wrap:wrap} #top button{font-size:14px;padding:5px 13px;min-width:42px} .cs-label{color:#555;margin-left:4px} #cs-status{margin-left:8px;color:#444}
#notation-container{position:relative;width:100%;box-sizing:border-box;padding:8px;background:#fff}
#notation-container svg{display:block}
#playhead{position:absolute;top:8px;width:2px;background:#1687d9;opacity:0;pointer-events:none}
.note-sel{position:absolute;background:rgba(0,102,204,.18);border-radius:3px;pointer-events:none}
#engine-error{padding:16px;color:#c62828}
#print-root{position:fixed;left:-10000px;top:0}
</style></head><body>
<div id="top">
<div class="cs-row cs-player">
<button onclick="csTransport('start')">|◀</button>
<button onclick="csTransport('play')">▶</button>
<button onclick="csTransport('pause')">Ⅱ</button>
<button onclick="csTransport('stop')">■</button>
<span class="cs-label">REAPER Player</span>
</div>
<div class="cs-row cs-edit">
<button onclick="csCmd('pitch',-1)">−1 Halbton</button>
<button onclick="csCmd('pitch',1)">+1 Halbton</button>
<button onclick="csCmd('duration',0.5)">½ Dauer</button>
<button onclick="csCmd('duration',2)">2× Dauer</button>
<span id="cs-status">Note im Notenbild anklicken</span>
</div>
</div>
<div id="notation-container"><div id="playhead"></div></div><div id="print-root"></div>
<script>
window.csSelectedIds=[];
function csBridgeReady(){return !!(window.compositionStudioBridge&&window.compositionStudioBridge.postMessage);}
function csSend(obj){
 try{
  if(csBridgeReady()){window.compositionStudioBridge.postMessage(JSON.stringify(obj));return true;}
 }catch(e){}
 return false;
}
function csSetStatus(t){const el=document.getElementById('cs-status');if(el)el.textContent=t;}
function csTransport(action){
 if(!csSend({type:'transport',action:action})) csSetStatus('WebView-Bridge fehlt – Player erreicht REAPER nicht');
}
function csCmd(kind,value){
 const ids=window.csSelectedIds||[];
 if(!ids.length){csSetStatus('Zuerst Note(n) markieren');return;}
 if(!csSend({type:'command',csids:ids.join(','),kind:kind,value:value})){
   csSetStatus('WebView-Bridge fehlt – Bearbeitung erreicht REAPER nicht');
 }else{
   csSetStatus(ids.length+' Note(n) · Befehl an REAPER gesendet');
 }
}
window.flutter_inappwebview={callHandler:function(name,data){
 if(name==='onNoteTap'&&data){
  try{
   const sc=window.csScore;
   const n=(sc&&sc.parts&&data.part!=null)
    ? sc.parts[data.part].measures[data.measure][data.voice][data.index]
    : (sc&&sc.measures&&sc.measures[data.measure]&&sc.measures[data.measure][data.voice]&&sc.measures[data.measure][data.voice][data.index]);
   if(n&&n.csid&&window.csSelectSingle){window.csSelectSingle(n.csid);}
  }catch(e){}
 }
 return Promise.resolve(null);
}};
</script>
<script type="module">
import { render } from 'https://cdn.jsdelivr.net/gh/wibem1/Composition-Studio@73dfcb307c6448ba5e19fc851262627808fd0c07/web/scoreflow-cs-render.js';
import { state } from ']]..base..[[js/utils/state.js';
let score=]]..score_json..[[;
window.csScore=score;
setTimeout(function(){
 if(csBridgeReady()) csSetStatus('Bridge aktiv · Note(n) markieren');
 else csSetStatus('Bridge fehlt · Markieren geht, Bearbeiten nicht');
},0);

function noteByHit(h){
 try{
  if(score.parts&&h.p!=null) return score.parts[h.p].measures[h.m][h.v][h.i];
  return score.measures[h.m][h.v][h.i];
 }catch(e){return null;}
}
function ensureLayer(){
 let l=document.getElementById('cs-selection-layer');
 if(!l){
  l=document.createElement('div'); l.id='cs-selection-layer';
  l.style.position='absolute'; l.style.left='0'; l.style.top='0';
  l.style.right='0'; l.style.bottom='0'; l.style.pointerEvents='none';
  document.getElementById('notation-container').appendChild(l);
 }
 return l;
}
function drawSelected(ids){
 const set=new Set((ids||[]).map(Number)); const layer=ensureLayer(); layer.innerHTML='';
 for(const h of state.noteHits||[]){
  const n=noteByHit(h); if(!n||!n.csid||!set.has(Number(n.csid))) continue;
  const d=document.createElement('div');
  d.style.position='absolute'; d.style.left=(8+h.x-4)+'px'; d.style.top=(8+h.y-4)+'px';
  d.style.width=(h.w+8)+'px'; d.style.height=(h.h+8)+'px';
  d.style.background='rgba(0,102,204,.22)'; d.style.border='2px solid rgba(0,102,204,.75)';
  d.style.borderRadius='4px'; d.style.boxSizing='border-box';
  layer.appendChild(d);
 }
 const st=document.getElementById('cs-status');
 if(st){
  const suffix=csBridgeReady()?' · Bridge aktiv':' · Bridge fehlt';
  st.textContent=(set.size===1?'1 Note markiert':(set.size+' Noten markiert'))+suffix;
 }
}
window.csSelectSingle=function(id){
 window.csSelectedIds=[Number(id)]; drawSelected(window.csSelectedIds);
 csSend({type:'select',csids:String(id)});
};

function hitAt(px,py){
 let best=null,bestD=Infinity;
 for(const h of state.noteHits||[]){
  const cx=h.x+h.w/2, cy=h.y+h.h/2, dx=px-cx, dy=py-cy, d=dx*dx+dy*dy;
  if(d<bestD){bestD=d;best=h;}
 }
 return best&&bestD<=90*90?best:null;
}
function idsInRect(x1,y1,x2,y2){
 const loX=Math.min(x1,x2), hiX=Math.max(x1,x2), loY=Math.min(y1,y2), hiY=Math.max(y1,y2), out=[];
 for(const h of state.noteHits||[]){
  const cx=h.x+h.w/2, cy=h.y+h.h/2;
  if(cx>=loX&&cx<=hiX&&cy>=loY&&cy<=hiY){
   const n=noteByHit(h); if(n&&n.csid&&!out.includes(Number(n.csid))) out.push(Number(n.csid));
  }
 }
 return out;
}
function directHit(px,py){
 for(const h of state.noteHits||[]){
  if(px>=h.x-6&&px<=h.x+h.w+6&&py>=h.y-8&&py<=h.y+h.h+8) return h;
 }
 return null;
}
function dragDeltas(hit,dx,dy){
 let qn=0;
 try{
  const g=state.lastLayout&&state.lastLayout.geom&&state.lastLayout.geom[hit.m];
  if(g&&g.w>40){
   const usable=Math.max(40,g.w-55);
   qn=Math.round((dx/usable)*16)/4;
  }
 }catch(e){}
 const dpitch=Math.round(-dy/6);
 return {dpitch:dpitch,dqn:qn};
}
function installSelection(){
 const c=document.getElementById('notation-container'); if(!c||c.dataset.csSelection==='1') return;
 c.dataset.csSelection='1';
 let down=false,sx=0,sy=0,drag=false,box=null,suppressNextClick=false,mode='select',startHit=null;
 c.addEventListener('click',e=>{
  if(suppressNextClick){
   suppressNextClick=false;
   e.preventDefault();
   e.stopImmediatePropagation();
  }
 },true);
 c.addEventListener('pointerdown',e=>{
  if(e.button!==0)return; const svg=c.querySelector('svg'); if(!svg)return;
  const r=svg.getBoundingClientRect(); sx=e.clientX-r.left; sy=e.clientY-r.top; down=true; drag=false;
  startHit=directHit(sx,sy);
  mode=startHit?'move':'select';
  if(mode==='move'){
   const n=noteByHit(startHit);
   if(n&&n.csid){
    const id=Number(n.csid);
    if(!(window.csSelectedIds||[]).includes(id)){
      window.csSelectedIds=[id]; drawSelected(window.csSelectedIds);
      csSend({type:'select',csids:String(id)});
    }
   }
   csSetStatus((window.csSelectedIds||[]).length+' Note(n) · ziehen zum Verschieben');
  }else{
   box=document.createElement('div'); box.style.position='absolute'; box.style.pointerEvents='none';
   box.style.border='1px dashed #0066cc'; box.style.background='rgba(0,102,204,.08)';
   box.style.left=(8+sx)+'px'; box.style.top=(8+sy)+'px'; box.style.display='none';
   c.appendChild(box);
  }
  c.setPointerCapture&&c.setPointerCapture(e.pointerId);
 },true);
 c.addEventListener('pointermove',e=>{
  if(!down)return; const svg=c.querySelector('svg'); if(!svg)return;
  const r=svg.getBoundingClientRect(); const x=e.clientX-r.left,y=e.clientY-r.top;
  if(Math.abs(x-sx)>5||Math.abs(y-sy)>5)drag=true;
  if(!drag)return;
  if(mode==='select'&&box){
   box.style.display='block';box.style.left=(8+Math.min(sx,x))+'px';box.style.top=(8+Math.min(sy,y))+'px';
   box.style.width=Math.abs(x-sx)+'px';box.style.height=Math.abs(y-sy)+'px';
  }else if(mode==='move'&&startHit){
   const d=dragDeltas(startHit,x-sx,y-sy);
   csSetStatus('Verschieben: '+(d.dpitch>=0?'+':'')+d.dpitch+' HT · '+(d.dqn>=0?'+':'')+d.dqn+' Viertel');
  }
 },true);
 c.addEventListener('pointerup',e=>{
  if(!down)return; down=false; const svg=c.querySelector('svg'); if(!svg)return;
  const r=svg.getBoundingClientRect(); const x=e.clientX-r.left,y=e.clientY-r.top;
  if(box){box.remove();box=null;}
  if(mode==='move'&&startHit){
   if(drag){
    suppressNextClick=true;
    const d=dragDeltas(startHit,x-sx,y-sy);
    if(d.dpitch!==0||Math.abs(d.dqn)>0.0001){
     const ids=window.csSelectedIds||[];
     if(!csSend({type:'move',csids:ids.join(','),dpitch:d.dpitch,dqn:d.dqn})) csSetStatus('Bridge fehlt – Verschieben nicht übertragen');
    }else csSetStatus('Keine Verschiebung');
   }
   startHit=null; return;
  }
  let ids=[];
  if(drag){
   suppressNextClick=true;
   ids=idsInRect(sx,sy,x,y);
  } else {
   const h=hitAt(x,y); if(h){const n=noteByHit(h);if(n&&n.csid)ids=[Number(n.csid)];}
  }
  if(ids.length){
   window.csSelectedIds=ids; drawSelected(ids);
   if(!csSend({type:'select',csids:ids.join(',')})) csSetStatus(ids.length+' Note(n) markiert · Bridge fehlt');
  } else if(drag){
   window.csSelectedIds=[]; drawSelected([]);
   csSetStatus('Keine Note im Auswahlrechteck');
  }
 },true);
}
window.csUpdateScore=function(nextScore){
 try{
  score=nextScore;
  window.csScore=score;
  render(score);
  installSelection();
  drawSelected(window.csSelectedIds||[]);
  return true;
 }catch(e){
  csSetStatus('Renderfehler: '+String(e));
  return false;
 }
};
try{
 render(score);
 installSelection();
}catch(e){
 document.body.insertAdjacentHTML('beforeend','<div id="engine-error">Rendererfehler: '+String(e)+'</div>');
}
</script></body></html>]]
end
local function notation_open_webview()
 score_capture_selection()
 local mei,err=verovio_score_mei()
 if not mei then notation_status=err or "Keine Partiturdaten."; return false end
 if type(reaper.WEBVIEW_Navigate)~="function" then
  notation_status="Für die Notation fehlt die REAPER-Erweiterung reaper_webview."
  notation_window_open=true
  return false
 end
 local html=verovio_host_html(mei)
 if not write_file(SCOREFLOW_HOST_PATH,html) then
  notation_status="Notations-Hostdatei konnte nicht geschrieben werden."
  notation_window_open=true
  return false
 end
 local url="file://"..url_encode_path(SCOREFLOW_HOST_PATH).."?v="..tostring(os.time())
 local opts='{"SetTitle":"Composition Studio – Notation","InstanceId":"wv_composition_studio_notation","ShowPanel":"always","BasicCtxMenu":true}'
 local ok,e=pcall(reaper.WEBVIEW_Navigate,url,opts)
 if not ok then
  notation_status="WebView konnte nicht geöffnet werden: "..tostring(e)
  notation_window_open=true
  return false
 end
 notation_status="Verovio-Partitur geöffnet."
 notation_window_open=false
 return true
end

local function score_bridge_rerender()
 local mei=verovio_score_mei()
 if mei and type(reaper.WEBVIEW_Eval)=="function" then
  local js='window.csUpdateMEI("'..json_escape(mei)..'");'
  local ok=pcall(reaper.WEBVIEW_Eval,"wv_composition_studio_notation",js)
  if ok then return end
 end
 if type(reaper.WEBVIEW_Navigate)=="function" then notation_open_webview() end
end
local function score_bridge_parse_ids(csv)
 local ids={}
 for x in tostring(csv or ""):gmatch("%d+") do
  local n=tonumber(x)
  if n and score_state.notes[n] then ids[#ids+1]=n end
 end
 return ids
end
local function score_bridge_apply_command(ids,kind,value)
 ids=ids or {}
 if #ids==0 then notation_status="Notation: keine gültige Auswahl aus WebView."; return end
 reaper.Undo_BeginBlock2(0)
 local touched={}
 for _,csid in ipairs(ids) do
  local n=score_state.notes[csid]
  if n and reaper.ValidatePtr2(0,n.take,"MediaItem_Take*") then
   local ok,sel,mut,sp,ep,ch,p,vel=reaper.MIDI_GetNote(n.take,n.note_idx)
   if ok then
    if kind=="pitch" then
     local np=math.max(0,math.min(127,p+(tonumber(value) or 0)))
     reaper.MIDI_SetNote(n.take,n.note_idx,sel,mut,sp,ep,ch,np,vel,true)
    elseif kind=="duration" then
     local dur=math.max(1,ep-sp)
     local nd=math.max(1,math.floor(dur*(tonumber(value) or 1)+0.5))
     reaper.MIDI_SetNote(n.take,n.note_idx,sel,mut,sp,sp+nd,ch,p,vel,true)
    end
    touched[n.take]=true
   end
  end
 end
 for tk in pairs(touched) do reaper.MIDI_Sort(tk) end
 reaper.Undo_EndBlock2(0,"Composition Studio Notation – Auswahl bearbeiten",-1)
 reaper.UpdateArrange()
 score_capture_selection()
 notation_status=tostring(#ids).." Note(n) bearbeitet."
 score_bridge_rerender()
end
local function score_bridge_move(ids,dpitch,dqn)
 ids=ids or {}; dpitch=tonumber(dpitch) or 0; dqn=tonumber(dqn) or 0
 if #ids==0 then return end
 reaper.Undo_BeginBlock2(0)
 local touched={}
 for _,csid in ipairs(ids) do
  local n=score_state.notes[csid]
  if n and reaper.ValidatePtr2(0,n.take,"MediaItem_Take*") then
   local ok,sel,mut,sp,ep,ch,pitch,vel=reaper.MIDI_GetNote(n.take,n.note_idx)
   if ok then
    local newPitch=math.max(0,math.min(127,pitch+dpitch))
    local st=reaper.MIDI_GetProjTimeFromPPQPos(n.take,sp)
    local q0=reaper.TimeMap2_timeToQN(0,st)
    local t1=reaper.TimeMap2_QNToTime(0,q0+dqn)
    local newSp=reaper.MIDI_GetPPQPosFromProjTime(n.take,t1)
    local shift=newSp-sp
    reaper.MIDI_SetNote(n.take,n.note_idx,sel,mut,sp+shift,ep+shift,ch,newPitch,vel,true)
    touched[n.take]=true
   end
  end
 end
 for tk in pairs(touched) do reaper.MIDI_Sort(tk) end
 reaper.Undo_EndBlock2(0,"Composition Studio Notation – Noten verschieben",-1)
 reaper.UpdateArrange()
 score_capture_selection()
 score_bridge_rerender()
end
local function score_bridge_transport(action)
 if action=="play" then
  reaper.OnPlayButton()
 elseif action=="pause" then
  reaper.OnPauseButton()
 elseif action=="stop" then
  reaper.OnStopButton()
 elseif action=="start" then
  local q=nil
  for _,n in ipairs(score_state.notes or {}) do q=q and math.min(q,n.start_qn) or n.start_qn end
  if q then reaper.SetEditCurPos(reaper.TimeMap2_QNToTime(0,q),true,false) end
 end
end
local function score_bridge_poll()
 local seq=reaper.GetExtState("CompositionStudio","ScoreBridgeSeq") or ""
 if seq=="" or seq==score_bridge_seq then return end
 score_bridge_seq=seq
 local msg=reaper.GetExtState("CompositionStudio","ScoreBridgeMessage") or ""
 local typ=msg:match('"type"%s*:%s*"([^"]+)"')
 local csv=msg:match('"csids"%s*:%s*"([^"]*)"') or msg:match('"csid"%s*:%s*(%d+)')
 local ids=score_bridge_parse_ids(csv)
 if typ=="select" and #ids>0 then
  score_state.selected=ids[1]
 elseif typ=="command" and #ids>0 then
  local kind=msg:match('"kind"%s*:%s*"([^"]+)"')
  local value=tonumber(msg:match('"value"%s*:%s*([%-]?[%d%.]+)'))
  score_bridge_apply_command(ids,kind,value)
 elseif typ=="move" and #ids>0 then
  local dpitch=tonumber(msg:match('"dpitch"%s*:%s*([%-]?[%d%.]+)')) or 0
  local dqn=tonumber(msg:match('"dqn"%s*:%s*([%-]?[%d%.]+)')) or 0
  score_bridge_move(ids,dpitch,dqn)
 elseif typ=="transport" then
  local action=msg:match('"action"%s*:%s*"([^"]+)"')
  score_bridge_transport(action)
 end
end

local function info_text() return "AKTUELLER STAND\n\nComposition Studio "..VERSION.." arbeitet direkt in REAPER.\n"..COMPOSITION_ENGINE_NAME.." "..COMPOSITION_ENGINE_VERSION.." · Build "..tostring(COMPOSITION_ENGINE_BUILD)..".\n\nWAS IST NEU? – "..VERSION.."\n\n• Notation Studio wurde vollständig aus Composition Studio entfernt.\n• Kein Menüpunkt, kein Button, kein Installer und kein KI-Dienst für Notation Studio mehr.\n• Notation Studio ist ein vollständig eigenständiges ReaScript und wird separat über REAPER gestartet.\n\nComposition Studio enthält damit wieder nur seine eigenen Funktionen." end
local function draw_history() if info_visible then reaper.ImGui_TextWrapped(ctx,info_text()); return end; local flags=0; if type(reaper.ImGui_InputTextFlags_ReadOnly)=="function" then flags=flags|reaper.ImGui_InputTextFlags_ReadOnly() end; if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then flags=flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end; local avail=select(1,reaper.ImGui_GetContentRegionAvail(ctx)); local limit=math.max(18,math.floor((avail-24)/9.5)); for i=chat_start,#history do local m=history[i]; reaper.ImGui_Text(ctx,m.role..":"); local text=wrap_text(m.text or "",limit); local lines=1; for _ in text:gmatch("\n") do lines=lines+1 end; local height=math.max(48,math.min(260,lines*22+12)); reaper.ImGui_InputTextMultiline(ctx,"##chatmsg"..i,text,-1,height,flags); text_context_menu("##chat_context"..i,text,false); reaper.ImGui_Spacing(ctx) end; if history_mode then reaper.ImGui_Separator(ctx); if reaper.ImGui_Button(ctx,"Verlauf löschen") then clear_saved_history() end end end
local function remember_closed() save_history(); reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"0",true) end
local function check_project_change() local p=reaper.EnumProjects(-1,""); if p~=current_project then save_history(current_project); current_project=p; load_history(current_project) end end
local auto_update_at=nil -- manuelles Update verhindert unerwartete Rückkehr zur alten GitHub-Version
local function loop() if auto_update_at and reaper.time_precise()>=auto_update_at and not busy then auto_update_at=nil; install_update() end; poll_update(); poll_job(); finish_save_panel(); score_bridge_poll(); if not open then if not restarting then remember_closed() end; return end; check_project_change(); reaper.ImGui_SetNextWindowSize(ctx,360,620,reaper.ImGui_Cond_FirstUseEver()); local visible; visible,open=reaper.ImGui_Begin(ctx,"Studio v"..VERSION.."###CompositionStudioMain",open); if visible then local pushed=push_font(); local items=selected_items(false); local tracks=selected_tracks(); reaper.ImGui_Text(ctx,"Studio v"..VERSION); reaper.ImGui_SameLine(ctx); if reaper.ImGui_Button(ctx,"...") then reaper.ImGui_OpenPopup(ctx,"##studio_menu") end; if reaper.ImGui_BeginPopup(ctx,"##studio_menu") then if reaper.ImGui_MenuItem(ctx,"Info") then info_visible=true; history_mode=false end; if reaper.ImGui_MenuItem(ctx,"SWAM interpretieren") then begin_swam_interpretation() end; if reaper.ImGui_MenuItem(ctx,"MIDI exportieren …") then export_last_midi() end; if reaper.ImGui_MenuItem(ctx,"SWAM-MIDI exportieren …") then export_swam_midi() end; if reaper.ImGui_MenuItem(ctx,"Diagnose speichern …") then save_diagnosis() end; if reaper.ImGui_MenuItem(ctx,"Update") then install_update() end; reaper.ImGui_Separator(ctx); if reaper.ImGui_MenuItem(ctx,"OpenAI API-Key ...") then edit_key("openai") end; if reaper.ImGui_MenuItem(ctx,"Anthropic API-Key ...") then edit_key("anthropic") end; if reaper.ImGui_MenuItem(ctx,"Google API-Key ...") then edit_key("google") end; reaper.ImGui_EndPopup(ctx) end; if reaper.ImGui_Button(ctx,model_label().." v") then reaper.ImGui_OpenPopup(ctx,"##model_menu") end; if reaper.ImGui_BeginPopup(ctx,"##model_menu") then for _,pv in ipairs({"openai","anthropic","google"}) do local title=pv=="openai" and "OpenAI" or pv=="anthropic" and "Anthropic" or "Google"; reaper.ImGui_Text(ctx,title); for _,m in ipairs(MODELS[pv]) do if reaper.ImGui_MenuItem(ctx,m[1],nil,provider==pv and model==m[2]) then select_model(pv,m[2]) end end; if pv~="google" then reaper.ImGui_Separator(ctx) end end; reaper.ImGui_EndPopup(ctx) end; reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx,string.format("%d MIDI | %d Spur(en)",#items,#tracks)); if update_status~="" then reaper.ImGui_TextWrapped(ctx,update_status) end; if busy and job then local pushed_color=false; if type(reaper.ImGui_PushStyleColor)=="function" and type(reaper.ImGui_Col_Text)=="function" then reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x35C759FF); pushed_color=true end; reaper.ImGui_Text(ctx,job.stage=="work_title" and "KI findet einen Werktitel …" or job.stage=="composition_music" and "KI komponiert …" or job.stage=="composition" and "MIDI wird erzeugt …" or job.stage=="summary" and "KI beschreibt das Stück …" or "KI arbeitet …"); if pushed_color then reaper.ImGui_PopStyleColor(ctx) end end; reaper.ImGui_Separator(ctx); local w,h=reaper.ImGui_GetContentRegionAvail(ctx); local ih,bh=112,32; local ch=math.max(120,h-ih-bh*2-84); if reaper.ImGui_BeginChild(ctx,"##chat",w,ch,reaper.ImGui_ChildFlags_Borders()) then draw_history(); reaper.ImGui_EndChild(ctx) end; reaper.ImGui_Spacing(ctx); local input_flags=0; if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then input_flags=input_flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end; local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##request",input,w,ih,input_flags); if changed then input=v end; input=text_context_menu("##request_context",input,true); reaper.ImGui_Spacing(ctx); local gap=6; local bw=math.max(110,(w-gap)/2); if reaper.ImGui_Button(ctx,busy and "Warten…" or "Senden",bw,bh) and not busy then submit() end; reaper.ImGui_SameLine(ctx,0,gap); if reaper.ImGui_Button(ctx,"Verlauf",bw,bh) then chat_start=1; info_visible=false; history_mode=true end; if reaper.ImGui_Button(ctx,"Chat leeren",bw,bh) then chat_start=#history+1; info_visible=false; history_mode=false end; reaper.ImGui_SameLine(ctx,0,gap); if reaper.ImGui_Button(ctx,"Schließen",bw,bh) then open=false end; pop_font(pushed); reaper.ImGui_End(ctx) end; if open then reaper.defer(loop) elseif not restarting then remember_closed() end end
loop()