local update_job=nil
local function fetch_update(url,raw)
 local tmp,code=temp_path(".lua"),temp_path(".code")
 local headers={"Cache-Control: no-cache","Pragma: no-cache"}
 if raw then headers[#headers+1]="Accept: application/vnd.github.raw+json" end
 local script
 if IS_WINDOWS then
  script=windows_curl_script(nil,nil,tmp,code,headers,url,20)
  if not script or not ps_launch(script,true) then if script then os.remove(script) end; return nil end
 else
  local cmd="/usr/bin/curl -sS -L --connect-timeout 10 --max-time 20"
  for _,h in ipairs(headers) do cmd=cmd.." -H "..shell_quote(h) end
  cmd=cmd.." -o "..shell_quote(tmp).." -w '%{http_code}' "..shell_quote(url).." > "..shell_quote(code..".pending").."; mv "..shell_quote(code..".pending").." "..shell_quote(code)
  script=unix_launch_script(cmd)
  if not script then return nil end
 end
 return {rs=tmp,cd=code,script=script,deadline=reaper.time_precise()+30}
end
local function install_update()
 if busy then
  reaper.ShowMessageBox(update_job and "Das Update läuft bereits. Bitte auf die Abschlussmeldung warten." or "Es läuft noch ein Auftrag. Bitte dessen Abschluss abwarten oder das Studio schließen und erneut öffnen.",SCRIPT_NAME.." – Update",0)
  return
 end
 busy=true; update_status="Update wird geladen …"
 update_job=fetch_update(UPDATE_URL.."?version_check="..os.time(),false)
 if not update_job then
  busy=false;update_status="Update-Prozess konnte nicht gestartet werden."
  reaper.ShowMessageBox(update_status,SCRIPT_NAME.." – Update",0)
 end
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
 reaper.defer(function()
  local ok,e=pcall(dofile,SCRIPT_PATH)
  if not ok then
   -- Keep the failed build for diagnosis and restore the verified original bytes.
   local failed=SCRIPT_PATH..".failed-update"
   os.remove(failed)
   local restored=false
   if write_file(staged,previous) and read_file(staged)==previous and os.rename(SCRIPT_PATH,failed) then
    restored=os.rename(staged,SCRIPT_PATH) and true or false
    if not restored then os.rename(failed,SCRIPT_PATH) end
   end
   reaper.SetExtState(EXT_SECTION,WINDOW_STATE_KEY,"0",true)
   reaper.ShowMessageBox("Die neue Version konnte nicht starten: "..tostring(e)..
    (restored and "\nDie vorherige Version wurde wiederhergestellt. Bitte das Skript erneut starten." or "\nSicherung: "..SCRIPT_PATH..".backup"),SCRIPT_NAME,0)
  end
 end)
end

local function poll_update()
 local j=update_job; if not j then return end
 local status=read_file(j.cd)
 if not status and reaper.time_precise()<j.deadline then return end
 local fresh=read_file(j.rs); os.remove(j.rs); os.remove(j.cd)
 update_job=nil
 if (trim(status)~="200" or not fresh or not fresh:match("%-%- @version%s+")) and not j.fallback then
  update_job=fetch_update("https://api.github.com/repos/wibem1/Composition-Studio/contents/Composition%20Studio.lua?ref=main&nocache="..os.time(),true)
  if update_job then update_job.fallback=true; return end
 end
 complete_update(trim(status)=="" and "TIMEOUT" or trim(status),fresh)
 if not restarting then reaper.ShowMessageBox(update_status,SCRIPT_NAME.." – Update",0) end
end

