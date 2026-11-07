-- @description Native Notation Studio - Zoom automatisch anpassen
-- @version 0.1.0-test
-- @author Klangwerke
-- @about No dialog, no API call, no MIDI changes. Horizontal and vertical notation view.
local R=reaper
local function run()
 local source=debug.getinfo(1,"S").source
 local directory=source:match("^@(.+[\\/])") or ""
 local environment=setmetatable({NATIVE_NOTATION_MODULE=true},{__index=_G})
 environment._G=environment
 local module=assert(loadfile(directory.."Native-Notation-Studio.lua","t",environment),
   "Native-Notation-Studio.lua muss im selben Ordner liegen.")()
 local rows,editor=module.selected(true)
 assert(editor and #rows>0,"Bitte den MIDI-/Notationseditor mit sichtbaren MIDI-Tracks oeffnen.")
 local section=assert(R.SectionFromUniqueID(32060),"MIDI-Aktionsbereich fehlt.")
 local zoomIn,zoomOut
 for i=0,19999 do
  local id,label=R.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=(label or ""):lower()
  if label=="view: zoom in vertically" then zoomIn=id end
  if label=="view: zoom out vertically" then zoomOut=id end
 end
 -- Width/height from js_ReaScriptAPI when present; conservative fallback otherwise.
 local width,height=1100,700
 if R.JS_Window_GetClientSize then
  local ok,w,h=pcall(R.JS_Window_GetClientSize,editor)
  if ok and type(w)=="number" and type(h)=="number" and w>300 and h>250 then
   width,height=w,h
  end
 end
 local tracks,notes={},0
 local startQN=math.huge
 for _,row in ipairs(rows) do
  tracks[R.GetMediaItem_Track(row.item)]=true
  for _,note in ipairs(row.notes) do
   notes=notes+1
   if note.start_qn<startQN then startQN=note.start_qn end
  end
 end
 local count=0
 for _ in pairs(tracks) do count=count+1 end
 -- Focus on approximately four measures, not the entire often lengthy piece.
 local barQN=4
 if startQN<math.huge then
  local _,a,b=R.TimeMap_QNToMeasures(R.EnumProjects(-1,""),startQN)
  if type(a)=="number" and type(b)=="number" and b>a then barQN=b-a end
 end
 local targetQN=math.max(1,4*barQN)
 local usableWidth=math.max(360,width-210)
 local pxPerQN=usableWidth/targetQN
 -- Read actual timebase before converting horizontal scale.
 local unit=R.MIDIEditor_GetSetting_int(editor,"timebase_unit")
 assert(unit==0 or unit==1,"Unbekannte Zoom-Zeitbasis.")
 if unit==0 then
  local project=R.EnumProjects(-1,"")
  local cursor=R.GetCursorPositionEx(project)
  local bpm=R.TimeMap2_GetDividedBpmAtTime(project,cursor)
  assert(type(bpm)=="number" and bpm>0,"Kein gueltiges Tempo.")
  pxPerQN=pxPerQN*bpm/60
 end
 local old=R.MIDIEditor_GetSetting_int(editor,"pixels_per_timebase_unit")
 assert(old and old>=0,"Zoom konnte nicht gelesen werden.")
 local target=math.floor(pxPerQN*1024+0.5)
 assert(R.MIDIEditor_SetSetting_int(editor,"pixels_per_timebase_unit",target),
  "Horizontaler Zoom konnte nicht gesetzt werden.")
 if R.MIDIEditor_GetSetting_int(editor,"pixels_per_timebase_unit")~=target then
  R.MIDIEditor_SetSetting_int(editor,"pixels_per_timebase_unit",old)
  error("Horizontaler Zoom wurde nicht uebernommen.")
 end
 -- REAPER exposes no direct notation staff-height setting. Use its native
 -- vertical zoom commands when available; reset to a repeatable baseline.
 if zoomOut and zoomIn then
  local systems=math.max(1,count)
  local targetHeight=math.min(145,math.max(65,(height-145)/systems))
  local steps=math.max(0,math.min(13,math.floor((targetHeight-55)/11+0.5)))
  for i=1,18 do if not R.MIDIEditor_OnCommand(editor,zoomOut) then break end end
  for i=1,steps do if not R.MIDIEditor_OnCommand(editor,zoomIn) then break end end
 end
end
local ok,why=xpcall(run,debug.traceback)
if not ok then R.ShowMessageBox(tostring(why),"Native Notation Studio - Zoom",0) end
