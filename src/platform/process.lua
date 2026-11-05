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
 h[#h+1]="$null = $request.Headers.TryAddWithoutValidation('User-Agent','CompositionStudio/1.0.58')"
 for _,v in ipairs(method_headers) do
  local name,value=v:match("^([^:]+):%s*(.*)$")
  if name and name:lower()~="content-type" then h[#h+1]="$null = $request.Headers.TryAddWithoutValidation("..ps_quote(name)..","..ps_quote(value)..")" end
 end
 h[#h+1]="$response = $client.SendAsync($request).GetAwaiter().GetResult()"
 h[#h+1]="$bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()"
 h[#h+1]="[IO.File]::WriteAllBytes("..ps_quote(output_file)..",$bytes)"
 h[#h+1]="$code = [string][int]$response.StatusCode"
 h[#h+1]="} catch {"
 h[#h+1]="$cause = $_.Exception; $timedOut = $false"
 h[#h+1]="while ($cause) { if ($cause -is [System.OperationCanceledException] -or $cause -is [System.TimeoutException]) { $timedOut = $true }; $cause = $cause.InnerException }"
 h[#h+1]="if ($timedOut) { $code = 'TIMEOUT'; [IO.File]::WriteAllText("..ps_quote(output_file)..",'Zeitlimit nach "..tostring(timeout or 180).." Sekunden erreicht.') } else { $code = 'TRANSPORT_ERROR'; [IO.File]::WriteAllText("..ps_quote(output_file)..",($_ | Out-String)) }"
 h[#h+1]="} finally {"
 h[#h+1]="if ($client) { $client.Dispose() }"
 h[#h+1]="[IO.File]::WriteAllText("..ps_quote(code_file..".pending")..",$code)"
 h[#h+1]="Move-Item -LiteralPath "..ps_quote(code_file..".pending").." -Destination "..ps_quote(code_file).." -Force"
 if request_file then h[#h+1]="Remove-Item -LiteralPath "..ps_quote(request_file).." -ErrorAction SilentlyContinue" end
 h[#h+1]="Remove-Item -LiteralPath "..ps_quote(script).." -ErrorAction SilentlyContinue"
 h[#h+1]="}"
 local f=io.open(script,"wb"); if not f then return nil end
 f:write("\239\187\191"..table.concat(h,"\r\n")); f:close(); return script
end
-- ExecProcess parses arguments itself; keep shell syntax inside a script file.
local function unix_launch_script(command)
 local script=temp_path(".sh")
 local f,err=io.open(script,"wb")
 if not f then return nil,err end
 local wrote=f:write("#!/bin/sh\n"..command.."\nrm -f "..shell_quote(script).."\n")
 local closed=f:close()
 if not wrote or not closed then os.remove(script);return nil,"Startdatei konnte nicht geschrieben werden." end
 local ok,result=pcall(reaper.ExecProcess,'/bin/sh "'..script:gsub('"','\\"')..'"',-2)
 if not ok or result==nil then os.remove(script);return nil,"Hintergrundprozess konnte nicht gestartet werden." end
 return script
end
