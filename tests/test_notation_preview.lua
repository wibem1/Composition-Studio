-- Offline test of the separate preview starter. No network/REAPER required.
local starter="tests/preview/Notation Studio Lesbarkeit Teststarter.lua"
local base=os.tmpname().."-preview-tests"
os.remove(base)
assert(os.execute('mkdir -p "'..base..'"'))

local function check_case(name,platform,network_ok)
 local root=base.."/"..name
 assert(os.execute('mkdir -p "'..root..'/Scripts"'))
 local original=root..'/Scripts/Notation Studio.lua'
 local f=assert(io.open(original,"wb"));f:write("ORIGINAL");f:close()
 local calls,alerts,executed={}, {}, 0
 _G.reaper={}
 function reaper.GetOS() return platform end
 function reaper.GetResourcePath() return root end
 function reaper.RecursiveCreateDirectory() return 1 end
 function reaper.ShowMessageBox(s) alerts[#alerts+1]=s end
 function reaper.ExecProcess(cmd)
  calls[#calls+1]=cmd
  local tmp=cmd:match('%-o%s+"([^"]+)"')
  assert(tmp and tmp:find(".part",1,true))
  if not network_ok then return "22\nNETWORK_ERROR" end
  local package='-- @description Notation Studio\n-- @version 0.1.24-test.1\n-- '..string.rep("x",21000)..'\nreaper.preview_did_run()\n'
  local o=assert(io.open(tmp,"wb"));o:write(package);o:close()
  return "0\n"
 end
 function reaper.preview_did_run() executed=executed+1 end
 assert(loadfile(starter))()
 local o=assert(io.open(original,"rb"));assert(o:read("*a")=="ORIGINAL","main install modified");o:close()
 if network_ok then
  assert(#calls==1 and executed==1 and #alerts==0,"preview launch failed")
  assert(calls[1]:find("curl.exe",1,true) or calls[1]:find("/usr/bin/curl",1,true),"curl missing")
  local sep=platform:find("Win") and "\\" or "/"
  local dest=root..sep.."Scripts"..sep.."Notation Studio Lesbarkeit Preview a916b226.lua"
  local p=assert(io.open(dest,"rb"));assert(#p:read("*a")>20000);p:close()
 else
  assert(#calls==1 and executed==0 and #alerts==1,"download error not handled")
 end
 print("PASS "..name)
end
check_case("mac","OSX64",true)
check_case("windows","Win64",true)
check_case("network_error","OSX64",false)
print("OK: separate preview tests, no installed file modified")
