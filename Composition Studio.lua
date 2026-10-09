-- @description Composition Studio
-- @version 1.0.57
-- @author Klangwerke
-- @about Dockable AI chat, controlled REAPER actions and MIDI composition.

local SCRIPT_NAME="Composition Studio"
local VERSION="1.0.57"
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
local open,input,busy=true,"",false; local last_made={}; local swam_last_made={}; local last_diag={}; local restarting=false; local update_status=""; local history={}; local chat_start=1; local info_visible=false; local history_mode=false; local current_project=reaper.EnumProjects(-1,""); local font=nil
if type(reaper.ImGui_CreateFont)=="function" then local ok,f=pcall(reaper.ImGui_CreateFont,"sans-serif"); if ok then font=f end end
if font and type(reaper.ImGui_Attach)=="function" then pcall(reaper.ImGui_Attach,ctx,font) end
local FONT_SIZE_KEY="InterfaceFontSize"
local font_size=tonumber(reaper.GetExtState(EXT_SECTION,FONT_SIZE_KEY)) or 14
font_size=math.max(10,math.min(26,font_size))
local function set_font_size(n)
 font_size=math.max(10,math.min(26,n))
 reaper.SetExtState(EXT_SECTION,FONT_SIZE_KEY,tostring(font_size),true)
end
local function push_font() if not font then return false end; return pcall(reaper.ImGui_PushFont,ctx,font,font_size) end
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
 h[#h+1]="$null = $request.Headers.TryAddWithoutValidation('User-Agent','CompositionStudio/1.0.57')"
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
 local keys={"version","composition_engine","composition_engine_build","provider","model","work_title","request","context","controller_prompt","controller_answer","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_stop_reason","api_error","api_response_excerpt","update_error","lilypond_log"}; local a={"{\n  \"timestamp\": \""..json_escape(os.date("%Y-%m-%dT%H:%M:%S")).."\""}
 for _,k in ipairs(keys) do a[#a+1]=",\n  \""..k.."\": \""..json_escape(last_diag[k] or "").."\"" end; a[#a+1]="\n}\n"; return table.concat(a)
end
local function restore_diag()
 local raw=read_file(DIAG_CACHE_PATH) or reaper.GetExtState(EXT_SECTION,DIAG_STATE_KEY)
 if not raw or raw=="" then return end
 local keys={"version","composition_engine","composition_engine_build","provider","model","work_title","request","context","controller_prompt","controller_answer","composition_prompt","composition_music","translation_prompt","composition_answer","apply_result","halion_result","api_status","api_error","api_response_excerpt","update_error","lilypond_log"}
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
local function existing_program(track) if not track or not reaper.ValidatePtr2(0,track,"MediaTrack*") then return nil end; for i=0,reaper.CountTrackMediaItems(track)-1 do local item=reaper.GetTrackMediaItem(track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local _,_,_,cc=reaper.MIDI_CountEvts(take); for n=0,(cc or 0)-1 do local ok,_,muted,_,chanmsg,_,msg2=reaper.MIDI_GetCC(take,n); if ok and not muted and chanmsg==0xC0 then return msg2 end end end end; return nil end
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

-- Local token-cost estimates, never provider invoices. Rates checked 2026-10-09.
local costs={}
do
 local function fields(raw)
  raw=trim(raw); local out={}
  if raw:sub(1,1)~="{" or raw:sub(-1)~="}" then return out end
  local i=2
  while i<#raw do
   while raw:sub(i,i):match("[%s,]") do i=i+1 end
   if raw:sub(i,i)~='"' then break end
   local key=read_json_string(raw,i); i=i+1
   while i<=#raw do local c=raw:sub(i,i); if c=="\\" then i=i+2 elseif c=='"' then i=i+1; break else i=i+1 end end
   while raw:sub(i,i):match("%s") do i=i+1 end
   if raw:sub(i,i)~=":" then break end
   i=i+1; while raw:sub(i,i):match("%s") do i=i+1 end
   local first,depth,quoted=i,0,false
   while i<=#raw do
    local c=raw:sub(i,i)
    if quoted then if c=="\\" then i=i+1 elseif c=='"' then quoted=false end
    elseif c=='"' then quoted=true
    elseif c=="{" or c=="[" then depth=depth+1
    elseif c=="}" or c=="]" then if depth==0 then break end; depth=depth-1
    elseif c=="," and depth==0 then break end
    i=i+1
   end
   if quoted or depth~=0 then return {} end
   out[key]=trim(raw:sub(first,i-1))
   if raw:sub(i,i)=="}" then break end
  end
  return out
 end
 function costs.usage(pv,raw)
  local top=fields(raw); local u=fields(top[pv=="google" and "usageMetadata" or "usage"])
  local bad=false
  local function count(obj,key,required)
   local v=obj[key]
   if (not v or v=="null") and not required then return 0 end
   local n=v and v:match("^%d+$") and tonumber(v)
   if not n or n>9007199254740991 then bad=true; return 0 end
   return n
  end
  local n={input=0,output=0,cached=0,write5=0,write1=0}
  if pv=="google" then
   n.input=count(u,"promptTokenCount",true)
   n.output=count(u,"candidatesTokenCount",true)+count(u,"thoughtsTokenCount")
   n.cached=count(u,"cachedContentTokenCount")
  else
   n.input=count(u,"input_tokens",true); n.output=count(u,"output_tokens",true)
   if pv=="openai" then
    local details=fields(u.input_tokens_details)
    n.cached=count(details,"cached_tokens"); n.write5=count(details,"cache_write_tokens")
   elseif pv=="anthropic" then
    n.cached=count(u,"cache_read_input_tokens")
    local writes=count(u,"cache_creation_input_tokens")
    local cache=fields(u.cache_creation)
    n.write1=count(cache,"ephemeral_1h_input_tokens")
    n.write5=cache.ephemeral_5m_input_tokens and count(cache,"ephemeral_5m_input_tokens") or writes-n.write1
    if n.write5+n.write1~=writes then bad=true end
    n.input=n.input+n.cached+writes
   else bad=true end
  end
  if n.cached+n.write5+n.write1>n.input or n.write5<0 then bad=true end
  return not bad and n or nil
 end
 -- input, output, cached reads, 5m writes, 1h writes; USD per million tokens.
 local rates={
  ["openai/gpt-5.6-sol"]={4,20,0.4,5,5,limit=272000,expires="2026-11-21"},
  ["openai/gpt-5.6-terra"]={2,12,0.2,2.5,2.5,limit=272000},
  ["openai/gpt-5.6-luna"]={0.2,1.2,0.02,0.25,0.25,limit=272000},
  ["anthropic/claude-fable-5"]={10,50,1,12.5,20},
  ["anthropic/claude-sonnet-5"]={2,10,0.2,2.5,4},
  ["anthropic/claude-opus-5"]={5,25,0.5,6.25,10},
  ["google/gemini-3.8-flash"]={0.75,3.75,0.075,0,0,expires="2026-12-31"},
 }
 local function rate_values(raw)
  if type(raw)~="string" or select(2,raw:gsub(",",""))~=4 then return nil end
  local a={}
  for v in (raw or ""):gmatch("[^,]+") do
   local n=tonumber((trim(v))); if not n or n<0 or n==math.huge or n~=n then return nil end
   a[#a+1]=n
  end
  return #a==5 and a or nil
 end
 function costs.rate(pv,id)
  local custom=rate_values(reaper.GetExtState(EXT_SECTION,"CostRateV1:"..pv.."/"..id))
  if custom then return custom end
  local r=rates[pv.."/"..id]
  if not r or r.expires and os.date("%Y-%m-%d")>r.expires then
   if pv=="google" and id=="gemini-3.8-flash" then return {1.5,7.5,0.15,0,0} end
   return nil
  end
  return r
 end
 function costs.price(n,r)
  if not n or not r then return nil end
  local scale=r.limit and n.input>r.limit and 2 or 1
  return ((n.input-n.cached-n.write5-n.write1)*r[1]*scale+n.cached*r[3]*scale+
   n.write5*r[4]*scale+n.write1*r[5]*scale+n.output*r[2]*(scale==2 and 1.5 or 1))/1000000
 end
 local keys={"calls","input","output","usd","unknown"}
 local function summary(raw)
  local a=rate_values(raw)
  return {calls=a and a[1] or 0,input=a and a[2] or 0,output=a and a[3] or 0,usd=a and a[4] or 0,unknown=a and a[5] or 0}
 end
 costs.total=summary(reaper.GetExtState(EXT_SECTION,"CostTotalV1"))
 costs.order=summary(reaper.GetExtState(EXT_SECTION,"CostOrderV1"))
 costs.since=reaper.GetExtState(EXT_SECTION,"CostSinceV1")
 if costs.since=="" then costs.since=os.date("%Y-%m-%d"); reaper.SetExtState(EXT_SECTION,"CostSinceV1",costs.since,true) end
 local function persist()
  for key,s in pairs({CostTotalV1=costs.total,CostOrderV1=costs.order}) do
   local values={}; for _,k in ipairs(keys) do values[#values+1]=string.format("%.12g",s[k]) end
   reaper.SetExtState(EXT_SECTION,key,table.concat(values,","),true)
  end
 end
 function costs.begin() costs.order=summary(""); persist() end
 function costs.start(a)
  a.cost_order=costs.order; a.cost_rate=costs.rate(a.provider,a.model)
  for _,s in ipairs({costs.total,a.cost_order}) do s.calls=s.calls+1; s.unknown=s.unknown+1 end
  persist()
 end
 function costs.record(a,raw)
  if a.cost_recorded then return end; a.cost_recorded=true
  local n=costs.usage(a.provider,raw); local usd=costs.price(n,a.cost_rate)
  for _,s in ipairs({costs.total,a.cost_order}) do
   if n then s.input=s.input+n.input; s.output=s.output+n.output end
   if usd then s.usd=s.usd+usd; s.unknown=math.max(0,s.unknown-1) end
  end
  persist()
 end
 function costs.text(s)
  return string.format("~ %.4f USD · %d Aufrufe · %d ein / %d aus",s.usd,s.calls,s.input,s.output)..
   (s.unknown>0 and (" · "..s.unknown.." ohne vollständige Kostenangabe") or "")
 end
 function costs.amount(s)
  return string.format("~ %.4f USD · %d Aufrufe",s.usd,s.calls)..(s.unknown>0 and " · unvollständig" or "")
 end
 function costs.edit_rate()
  if busy then update_status="Preise bitte nach Abschluss des Auftrags ändern."; return end
  local r=costs.rate(provider,model); local values={}
  for i=1,5 do values[i]=r and tostring(r[i]) or "" end
  local ok,raw=reaper.GetUserInputs("Kosten – "..model.." (USD je 1 Mio. Token)",5,
   "Eingabe:,Ausgabe inkl. Denken:,Cache lesen:,Cache schreiben 5m:,Cache schreiben 1h:,extrawidth=250",table.concat(values,","))
  if not ok then return end
  if not rate_values(raw) then update_status="Preise nicht gespeichert: fünf nichtnegative Zahlen mit Dezimalpunkt eingeben."; return end
  reaper.SetExtState(EXT_SECTION,"CostRateV1:"..provider.."/"..model,raw,true)
  update_status="Eigene Preise für "..model.." gespeichert. Bisherige Kosten bleiben unverändert."
 end
 function costs.show()
  local r=costs.rate(provider,model)
  local tariff=r and string.format("Aktuelles Modell %s: Eingabe %.4g / Ausgabe %.4g / Cache %.4g USD je 1 Mio. Token.",model,r[1],r[2],r[3]) or
   ("Für "..model.." fehlt ein bestätigter Preis. Im Menü »Kostenpreise einstellen« hinterlegen.")
  reaper.ShowMessageBox("Letzter / laufender Auftrag:\n"..costs.text(costs.order).."\n\nGesamt seit "..costs.since..":\n"..costs.text(costs.total)..
   "\n\n"..tariff.."\n\nSchätzungen für Aufrufe aus Composition Studio, keine Anbieterrechnung. Standardtarife: Stand 09.10.2026; eigene Preise im Menü. Google-Free-Tier kann mit Preisen 0 eingestellt werden. Fehlende Verbrauchsdaten bleiben als unvollständig markiert. Frühere Aufrufe vor dieser Version sind nicht enthalten.",SCRIPT_NAME.." – Kosten",0)
 end
end
-- End cost accounting.
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
 local a={rq=rq,rs=rs,cd=cd,provider=provider,model=model,deadline=reaper.time_precise()+200}
 costs.start(a)
 return a,nil
end

local function ai_poll(a)
 local status=read_file(a.cd)
 if not status or trim(status)=="" then
  if reaper.time_precise()<a.deadline then return nil,nil,false end
  costs.record(a,read_file(a.rs))
  diag_set("api_error","Zeitlimit / Hintergrundprozess ohne Statusdatei")
  return nil,"KI-Zeitlimit erreicht; siehe Diagnose und CompositionStudioTemp.",true
 end
 status=trim(status)
 local raw=read_file(a.rs)
 costs.record(a,raw)
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
launch=function(stage,prompt,key,data) if stage=="controller" or stage=="swam_interpretation" or stage=="work_title" then costs.begin() end; local a,e=ai_command(prompt,key); if not a then add("KI",e); busy=false; job=nil; return false end; job={stage=stage,ai=a,key=key,data=data or {},project=reaper.EnumProjects(-1,"")}; return true end

-- The official LilyPond compiler handles the musical semantics.
local LILYPOND_PATH_KEY="LilyPondExe"
local function lily_exe()
 local p=trim(reaper.GetExtState(EXT_SECTION,LILYPOND_PATH_KEY))
 if p~="" and reaper.file_exists(p) then return p end
 local home=os.getenv("USERPROFILE") or ""
 local expected=home.."/Downloads/lilypond-2.26.0-mingw-x86_64/lilypond-2.26.0/bin/lilypond.exe"
 if reaper.file_exists(expected) then
  reaper.SetExtState(EXT_SECTION,LILYPOND_PATH_KEY,expected,true)
  return expected
 end
 return nil
end
local function set_lily_exe()
 local old=reaper.GetExtState(EXT_SECTION,LILYPOND_PATH_KEY) or ""
 local ok,p=reaper.GetUserInputs("LilyPond",1,"Pfad zu lilypond.exe:",old)
 if not ok then return end
 p=trim(p):gsub('^"',''):gsub('"$','')
 if not reaper.file_exists(p) then update_status="LilyPond nicht gefunden: "..p; return end
 reaper.SetExtState(EXT_SECTION,LILYPOND_PATH_KEY,p,true)
 update_status="LilyPond-Pfad gespeichert."
end
local function midi_score(src)
 src=trim(src)
 local fence=string.rep(string.char(96),3)
 if src:sub(1,3)==fence then
  src=src:gsub("^[^\n]*\n",""):gsub("\n[^\n]*$","")
 end
 local beginning=src:find("\\score",1,true)
 if not beginning then return nil,"Kein LilyPond-score-Block vorhanden." end
 local opening=src:find("{",beginning+6,true)
 if not opening then return nil,"LilyPond-score-Block unvollständig." end
 local depth,closing=0,nil
 for i=opening,#src do
  local ch=src:sub(i,i)
  if ch=="{" then depth=depth+1 elseif ch=="}" then depth=depth-1; if depth==0 then closing=i; break end end
 end
 if not closing then return nil,"LilyPond: schließende score-Klammer fehlt." end
 if not src:sub(opening,closing):find("\\midi",1,true) then
  src=src:sub(1,closing-1).."\n\\midi { }\n"..src:sub(closing)
 end
 return src
end

-- A continuation is a new passage appended after the latest selected MIDI item.
local function continuation_bars(request)
 local r=tostring(request or ""):lower():gsub("%s+"," ")
 if not (r:find("weitere",1,true) or r:find("fortsetz",1,true) or r:find("anhäng",1,true)) then return nil end
 local n=tonumber(r:match("(%d+)%s*takt"))
 if n and n>=1 and n<=128 then return n end
 return nil
end
local function continuation_prompt(request,items,tracks,count,at)
 return [[Komponiere die musikalische Fortsetzung des vorhandenen Werks: GENAU ]]..count..[[ NEUE Takte.
Schreibe nur diese neuen ]]..count..[[ Takte als vollständige LilyPond-Partitur mit \score { ... }.
Die App setzt sie nach dem Ende des bisher vorhandenen Werks bei Viertelposition ]]..at..[[ ein.
Du darfst vorhandene Takte nicht nochmals ausgeben. Keine MIDI-QN-Codierung.
Nutze die übergebenen Originalnoten als musikalischen Kontext und entwickle
eine wirkliche Variation mit neuer melodischer Gestalt, verändertem Rhythmus
und einer dazugehörigen eigenständigen Begleitung. Keine reine Oktavierung,
keine bloße Transposition, keine starre Viertelkette.
Für ein Klavierstück notiere rechte und linke Hand in separaten Staves.
LilyPond muss ausführbar sein; nur Quellcode, keine Erläuterung.

AUFTRAG:
]]..request.."\n\nVORHANDENE MUSIK:\n"..music_context(items,tracks,false)
end

local function lily_compile_import(source,insert_qn,expected_bars)
 -- ExecProcess returns one string: exit code, newline, captured output.
 local function process_result(raw)
  if type(raw)~="string" then return nil,"Prozess konnte nicht ausgeführt werden." end
  local first,output=raw:match("^([^\n]*)\n(.*)$")
  first=first or raw; output=output or ""
  local code=trim(first):match("^([%-]?%d+)$")
  if not code then return nil,"Ungültige Prozessantwort: "..raw:sub(-1200) end
  return tonumber(code),output
 end
 if not IS_WINDOWS then return nil,"LilyPond-MIDI-Integration derzeit für Windows." end
 local exe=lily_exe()
 if not exe then return nil,"LilyPond-Pfad nicht gefunden. Menü ... → LilyPond-Pfad einstellen." end
 local src,err=midi_score(source)
 if not src then return nil,err end
 local input=temp_path(".ly")
 local base=input:sub(1,-4)
 if not write_file(input,src) then return nil,"LilyPond-Datei konnte nicht gespeichert werden." end
 local command=shell_quote(exe)..' -dno-print-pages -dmidi-extension=mid -o '..shell_quote(base)..' '..shell_quote(input)
 local result,output=process_result(reaper.ExecProcess(command,120000))
 diag_set("lilypond_log",tostring(output or ""):sub(-12000))
 if result~=0 then return nil,"LilyPond Fehler "..tostring(result)..": "..tostring(output or ""):sub(-1200) end
 local midi=base..".mid"
 if not reaper.file_exists(midi) then return nil,"LilyPond hat keine MIDI-Datei erzeugt." end
 local prior=reaper.CountTracks(0)
 local existing={}
 for ix=0,prior-1 do existing[reaper.GetTrack(0,ix)]=true end
 local cursor=reaper.GetCursorPosition()
 reaper.Undo_BeginBlock2(0)
 local at=insert_qn and reaper.TimeMap2_QNToTime(0,insert_qn) or 0
 reaper.SetEditCurPos(at,false,false)
 local n=reaper.InsertMedia(midi,1)
 reaper.SetEditCurPos(cursor,false,false)
 local tracks=reaper.CountTracks(0)-prior
 local imported={}
 -- InsertMedia may insert after the selected track, rather than at project end.
 for ix=0,reaper.CountTracks(0)-1 do
  local tr=reaper.GetTrack(0,ix)
  if not existing[tr] then imported[#imported+1]=tr end
 end
 local made,ids={},{}
 for _,tr in ipairs(imported) do
  for j=0,reaper.CountTrackMediaItems(tr)-1 do
   local it=reaper.GetTrackMediaItem(tr,j)
   local tk=it and reaper.GetActiveTake(it)
   if tk and reaper.TakeIsMIDI(tk) then made[#made+1]=it; ids[#ids+1]=item_guid(it) end
  end
 end
 if tracks<=0 or #made==0 then
  reaper.Undo_EndBlock2(0,"Composition Studio – MIDI-Import fehlgeschlagen",-1)
  if #imported>0 then reaper.Undo_DoUndo2(0) end
  return nil,"MIDI-Datei erzeugt, aber REAPER-Import fehlgeschlagen ("..tostring(n)..")."
 end
 if expected_bars then
  local num,den=reaper.TimeMap_GetTimeSigAtTime(0,at)
  num=tonumber(num) or 4; den=tonumber(den) or 4
  local expected_qn=expected_bars*4*num/den
  local highest=insert_qn
  local total_items=0
  local earliest=math.huge
  for _,tr in ipairs(imported) do
   for j=0,reaper.CountTrackMediaItems(tr)-1 do
    local item=reaper.GetTrackMediaItem(tr,j)
    local take=reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
     total_items=total_items+1
     local st=reaper.GetMediaItemInfo_Value(item,"D_POSITION")
     local en=st+reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
     earliest=math.min(earliest,reaper.TimeMap2_timeToQN(0,st))
     highest=math.max(highest,reaper.TimeMap2_timeToQN(0,en))
    end
   end
  end
  local valid=tracks>0 and total_items>0 and math.abs(earliest-insert_qn)<0.05 and math.abs(highest-(insert_qn+expected_qn))<0.05
  reaper.Undo_EndBlock2(0,"Composition Studio – MIDI-Fortsetzung",-1)
  if not valid then
   reaper.Undo_DoUndo2(0)
   return nil,"Fortsetzung nicht übernommen: importierte MIDI-Länge oder Startposition stimmt nicht mit "..expected_bars.." Takten überein (Soll-QN "..string.format("%.2f",expected_qn)..", Ist-QN "..string.format("%.2f",highest-insert_qn)..")."
  end
 else
  reaper.Undo_EndBlock2(0,"Composition Studio – LilyPond MIDI",-1)
 end
 last_made=made
 reaper.SetProjExtState(0,EXT_SECTION,"LastMadeGUIDs",table.concat(ids,"\n"))
 reaper.UpdateArrange()
 return tracks
end
local function lily_composition_prompt(request)
 return [[Komponiere das vollständige verlangte Musikstück als LilyPond-Partitur.
Gib ausschließlich gültigen LilyPond-Quellcode zurück. Keine Entwürfe oder Erläuterungen.
Komponiere musikalisch frei: Akkorde, Phrasierung, Stimmen, Triolen, Bindungen,
Dynamik, Artikulationen und Tempoänderungen sind erlaubt, soweit sinnvoll.
Notiere das vollständige Werk mit einem \score { ... }-Block.
Der MIDI-Block wird von der App ergänzt. Keine Markdown-Codezäune.
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
 if stage=="lily_continuation" then
  diag_set("composition_music",text)
  update_status="LilyPond übersetzt Fortsetzung nach MIDI …"
  local tracks,why=lily_compile_import(text,data.extension_start,data.extension_bars)
  diag_set("apply_result",tracks and ("LilyPond Fortsetzung: "..tracks.." Spuren; startQN="..data.extension_start.."; bars="..data.extension_bars) or ("ERROR: "..tostring(why)))
  if not tracks then add("KI","Die Fortsetzung wurde nicht übernommen: "..tostring(why)) else add("KI","Fortsetzung mit "..data.extension_bars.." Takten ab QN "..data.extension_start.." eingefügt. Das Original bleibt erhalten.") end
  busy=false; return
 end
 if stage=="lily_composition" then
  diag_set("composition_music",text)
  update_status="LilyPond übersetzt nach MIDI …"
  local tracks,why=lily_compile_import(text)
  diag_set("apply_result",tracks and ("LilyPond MIDI: "..tracks.." Spuren") or ("ERROR: "..tostring(why)))
  if not tracks then add("KI","LilyPond: "..tostring(why)) else add("KI","Vollständige LilyPond-MIDI-Datei importiert: "..tracks.." Spur(en).") end
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
  local newwhy=text:match("^NEED_NEW|(.*)$"); local why=text:match("^NEED_MUSIC|(.*)$"); if newwhy or why then local full=newwhy and {} or selected_items(true); local tracks=newwhy and {} or data.tracks; if #full==0 and #tracks>0 then full=track_context_items(tracks) end; local cp=composition_prompt(data.request,full,tracks,newwhy~=nil); diag_set("composition_prompt",cp); data.full=full; data.music_tracks=tracks; data.is_new=newwhy~=nil; local ext=why and continuation_bars(data.request) or nil
  if ext then
   if #full==0 then add("KI","Für die Fortsetzung muss das vorhandene MIDI-Stück ausgewählt sein."); busy=false; return end
   local endpoint=0; for _,it in ipairs(full) do endpoint=math.max(endpoint,it.end_qn or 0) end
   if endpoint<=0 then add("KI","Kein gültiges Ende der vorhandenen Komposition gefunden."); busy=false; return end
   data.extension_start=endpoint; data.extension_bars=ext
   diag_set("continuation_start_qn",tostring(endpoint)); diag_set("continuation_bars",tostring(ext))
   local lp=continuation_prompt(data.request,full,tracks,ext,endpoint)
   diag_set("composition_prompt",lp)
   launch("lily_continuation",lp,key,data)
  elseif newwhy and tostring(data.request or ""):lower():find("klavier",1,true) then
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

local function info_text()
 return "Composition Studio "..VERSION.."\n"..COMPOSITION_ENGINE_NAME.." "..COMPOSITION_ENGINE_VERSION.." · Build "..tostring(COMPOSITION_ENGINE_BUILD)..
 "\n\nNEU IN "..VERSION.."\n\n• Kostenanzeige pro Auftrag und insgesamt; Details und eigene Preise im Menü.\n• LilyPond-Exitcodes werden korrekt ausgewertet; der Import prüft echte MIDI-Items.\n• Ungenutzte ScoreFlow-/Verovio-Prototypen und die alte WebView-Bridge wurden entfernt.\n• Neue Klavierstücke und Fortsetzungen werden durch LilyPond in REAPER-MIDI übertragen. Der Pfad ist im Menü einstellbar.\n\nGeprüft unter Windows mit REAPER 7.82 und LilyPond 2.26.0: Kompilierung, MIDI-Import und Fortsetzungsprüfung."
end
local function draw_history() if info_visible then reaper.ImGui_TextWrapped(ctx,info_text()); return end; local flags=0; if type(reaper.ImGui_InputTextFlags_ReadOnly)=="function" then flags=flags|reaper.ImGui_InputTextFlags_ReadOnly() end; if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then flags=flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end; local avail=select(1,reaper.ImGui_GetContentRegionAvail(ctx)); local limit=math.max(18,math.floor((avail-24)/9.5)); for i=chat_start,#history do local m=history[i]; reaper.ImGui_Text(ctx,m.role..":"); local text=wrap_text(m.text or "",limit); local lines=1; for _ in text:gmatch("\n") do lines=lines+1 end; local height=math.max(math.floor(48*font_size/14),math.min(math.floor(260*font_size/14),lines*math.floor(font_size*1.57)+math.floor(12*font_size/14))); reaper.ImGui_InputTextMultiline(ctx,"##chatmsg"..i,text,-1,height,flags); text_context_menu("##chat_context"..i,text,false); reaper.ImGui_Spacing(ctx) end; if history_mode then reaper.ImGui_Separator(ctx); if reaper.ImGui_Button(ctx,"Verlauf löschen") then clear_saved_history() end end end
local function remember_closed() save_history(); reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"0",true) end
local function check_project_change() local p=reaper.EnumProjects(-1,""); if p~=current_project then save_history(current_project); current_project=p; load_history(current_project) end end
local function loop() poll_update(); poll_job(); finish_save_panel(); if not open then if not restarting then remember_closed() end; return end; check_project_change(); reaper.ImGui_SetNextWindowSize(ctx,360,620,reaper.ImGui_Cond_FirstUseEver()); local visible; visible,open=reaper.ImGui_Begin(ctx,"Studio v"..VERSION.."###CompositionStudioMain",open); if visible then local pushed=push_font(); local items=selected_items(false); local tracks=selected_tracks(); reaper.ImGui_Text(ctx,"Studio v"..VERSION); reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A-") then set_font_size(font_size-1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"A+") then set_font_size(font_size+1) end
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"...") then reaper.ImGui_OpenPopup(ctx,"##studio_menu") end; if reaper.ImGui_BeginPopup(ctx,"##studio_menu") then if reaper.ImGui_MenuItem(ctx,"Info") then info_visible=true; history_mode=false end; if reaper.ImGui_MenuItem(ctx,"Kostenübersicht") then costs.show() end; if reaper.ImGui_MenuItem(ctx,"Kostenpreise einstellen ...") then costs.edit_rate() end;
if reaper.ImGui_MenuItem(ctx,"Schrift kleiner (A-)") then set_font_size(font_size-1) end
if reaper.ImGui_MenuItem(ctx,"Schrift größer (A+)") then set_font_size(font_size+1) end
if reaper.ImGui_MenuItem(ctx,"Schrift Standard (14)") then set_font_size(14) end; if reaper.ImGui_MenuItem(ctx,"SWAM interpretieren") then begin_swam_interpretation() end; if reaper.ImGui_MenuItem(ctx,"MIDI exportieren …") then export_last_midi() end; if reaper.ImGui_MenuItem(ctx,"SWAM-MIDI exportieren …") then export_swam_midi() end; if reaper.ImGui_MenuItem(ctx,"Diagnose speichern …") then save_diagnosis() end; if reaper.ImGui_MenuItem(ctx,"LilyPond-Pfad einstellen ...") then set_lily_exe() end; if reaper.ImGui_MenuItem(ctx,"Update") then install_update() end; reaper.ImGui_Separator(ctx); if reaper.ImGui_MenuItem(ctx,"OpenAI API-Key ...") then edit_key("openai") end; if reaper.ImGui_MenuItem(ctx,"Anthropic API-Key ...") then edit_key("anthropic") end; if reaper.ImGui_MenuItem(ctx,"Google API-Key ...") then edit_key("google") end; reaper.ImGui_EndPopup(ctx) end; if reaper.ImGui_Button(ctx,model_label().." v") then reaper.ImGui_OpenPopup(ctx,"##model_menu") end; if reaper.ImGui_BeginPopup(ctx,"##model_menu") then for _,pv in ipairs({"openai","anthropic","google"}) do local title=pv=="openai" and "OpenAI" or pv=="anthropic" and "Anthropic" or "Google"; reaper.ImGui_Text(ctx,title); for _,m in ipairs(MODELS[pv]) do if reaper.ImGui_MenuItem(ctx,m[1],nil,provider==pv and model==m[2]) then select_model(pv,m[2]) end end; if pv~="google" then reaper.ImGui_Separator(ctx) end end; reaper.ImGui_EndPopup(ctx) end; reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx,string.format("%d MIDI | %d Spur(en)",#items,#tracks)); reaper.ImGui_TextWrapped(ctx,"Auftrag: "..costs.amount(costs.order)); reaper.ImGui_TextWrapped(ctx,"Gesamt: "..costs.amount(costs.total)); if update_status~="" then reaper.ImGui_TextWrapped(ctx,update_status) end; if busy and job then local pushed_color=false; if type(reaper.ImGui_PushStyleColor)=="function" and type(reaper.ImGui_Col_Text)=="function" then reaper.ImGui_PushStyleColor(ctx,reaper.ImGui_Col_Text(),0x35C759FF); pushed_color=true end; reaper.ImGui_Text(ctx,job.stage=="work_title" and "KI findet einen Werktitel …" or job.stage=="composition_music" and "KI komponiert …" or job.stage=="composition" and "MIDI wird erzeugt …" or job.stage=="summary" and "KI beschreibt das Stück …" or "KI arbeitet …"); if pushed_color then reaper.ImGui_PopStyleColor(ctx) end end; reaper.ImGui_Separator(ctx); local w,h=reaper.ImGui_GetContentRegionAvail(ctx); local scale=font_size/14; local ih=math.floor(112*scale+0.5); local bh=math.floor(34*scale+0.5); local ch=math.max(120,h-ih-bh*2-math.floor(84*scale+0.5)); if reaper.ImGui_BeginChild(ctx,"##chat",w,ch,reaper.ImGui_ChildFlags_Borders()) then draw_history(); reaper.ImGui_EndChild(ctx) end; reaper.ImGui_Spacing(ctx); local input_flags=0; if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll)=="function" then input_flags=input_flags|reaper.ImGui_InputTextFlags_NoHorizontalScroll() end; local changed,v=reaper.ImGui_InputTextMultiline(ctx,"##request",input,w,ih,input_flags); if changed then input=v end; input=text_context_menu("##request_context",input,true); reaper.ImGui_Spacing(ctx); local gap=math.max(4,math.floor(6*scale)); local bw=math.max(80,(w-gap)/2); if reaper.ImGui_Button(ctx,busy and "Warten…" or "Senden",bw,bh) and not busy then submit() end; reaper.ImGui_SameLine(ctx,0,gap); if reaper.ImGui_Button(ctx,"Verlauf",bw,bh) then chat_start=1; info_visible=false; history_mode=true end; if reaper.ImGui_Button(ctx,"Chat leeren",bw,bh) then chat_start=#history+1; info_visible=false; history_mode=false end; reaper.ImGui_SameLine(ctx,0,gap); if reaper.ImGui_Button(ctx,"Schließen",bw,bh) then open=false end; pop_font(pushed); reaper.ImGui_End(ctx) end; if open then reaper.defer(loop) elseif not restarting then remember_closed() end end
loop()
