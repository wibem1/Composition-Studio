-- @description Native Notation Studio - Zoomfaktor einstellen
-- @version 0.1.0-test
-- @author Klangwerke
-- @about Horizontal notation zoom only; no AI request and no MIDI changes.
local ok,why=xpcall(function()
 local source=debug.getinfo(1,"S").source
 local directory=source:match("^@(.+[\\/])") or ""
 local environment=setmetatable({NATIVE_NOTATION_MODULE=true},{__index=_G})
 environment._G=environment
 local module=assert(loadfile(directory.."Native-Notation-Studio.lua","t",environment),"Native-Notation-Studio.lua muss im selben Ordner liegen.")()
 module.zoom_dialog()
end,debug.traceback)
if not ok then reaper.ShowMessageBox(tostring(why),"Native Notation Studio - Zoom",0) end
