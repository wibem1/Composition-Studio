-- @description Native Notation Studio - Notenansicht optimieren (offline)
-- @version 0.1.0-test
-- @author Klangwerke
-- @about No API, no MIDI note writing. Display quantization, spacing, safe optional horizontal zoom.
-- Vertical notation zoom and track clef editing excluded until validated.
local R=reaper
local function require_action(section,names)
 for i=0,19999 do
  local id,label=R.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=(label or ''):lower():gsub('^%s+',''):gsub('%s+$','')
  for _,name in ipairs(names) do if label==name then return id end end
 end
 error('REAPER-Aktion nicht gefunden: '..table.concat(names,' / '))
end
local function run()
 local project=R.EnumProjects(-1,'')
 local editor=assert(R.MIDIEditor_GetActive(),'Bitte den REAPER-MIDI-/Notationseditor oeffnen.')
 assert(R.MIDIEditor_GetMode(editor)~=-1,'MIDI-Editor ist geschlossen.')
 local takes,seen={},{}
 local firstQN=nil
 for i=0,65535 do
  local take=R.MIDIEditor_EnumTakes(editor,i,false)
  if not take then break end
  if not seen[take] and R.TakeIsMIDI(take) then
   seen[take]=true;takes[#takes+1]=take
   local item=assert(R.GetMediaItemTake_Item(take))
   local itemQN=R.TimeMap2_timeToQN(project,R.GetMediaItemInfo_Value(item,'D_POSITION'))
   if not firstQN or itemQN<firstQN then firstQN=itemQN end
  end
 end
 assert(#takes>0,'Keine sichtbaren MIDI-Takes gefunden.')
 local section=assert(R.SectionFromUniqueID(32060),'MIDI-Aktionsbereich nicht verfuegbar.')
 -- Resolve actions before changing anything. Do not call MIDI-data quantization.
 local notation=require_action(section,{'view: mode: musical notation','view: mode: notation','mode: notation'})
 local quant=require_action(section,{'notation: set display quantization to 1/16 (default)'})
 local minimum=require_action(section,{'notation: set minimum display quantization note length to 1/64'})
 local proportional=require_action(section,{'notation: proportional (musical) note spacing'})
 local old=R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')
 assert(type(old)=='number' and old>=0,'Horizontaler Zoom nicht lesbar.')
 local timebase=R.MIDIEditor_GetSetting_int(editor,'timebase_unit')
 assert(timebase==0 or timebase==1,'Zeitbasis des Editors nicht unterstuetzt.')
 local _,startQN,endQN=R.TimeMap_QNToMeasures(project,firstQN or 0)
 assert(type(startQN)=='number' and type(endQN)=='number' and endQN>startQN,'Taktlaenge nicht lesbar.')
 -- Never guess a window width: a wrong guess made the previous Windows
 -- zoom results unreliable. JS_ReaScriptAPI is optional; without it, keep
 -- the user's existing horizontal zoom.
 local desired=nil
 if R.JS_Window_GetClientSize then
  local ok,width=pcall(R.JS_Window_GetClientSize,editor)
  if ok and type(width)=='number' and width>=500 and width<20000 then
   local pxPerQN=(width-240)/(4*(endQN-startQN))
   if timebase==0 then
    local bpm=R.TimeMap2_GetDividedBpmAtTime(project,R.GetCursorPositionEx(project))
    assert(type(bpm)=='number' and bpm>0,'Tempo fuer horizontale Skalierung fehlt.')
    pxPerQN=pxPerQN*bpm/60
   end
   local value=math.floor(pxPerQN*1024+0.5)
   assert(value>0 and value<2147483647,'Ungueltiger horizontaler Zoom.')
   desired=value
  end
 end
 R.MIDIEditor_OnCommand(editor,notation)
 R.MIDIEditor_OnCommand(editor,quant)
 R.MIDIEditor_OnCommand(editor,minimum)
 if R.GetToggleCommandStateEx(32060,proportional)==0 then
  R.MIDIEditor_OnCommand(editor,proportional)
 end
 if desired and desired~=old then
  if not R.MIDIEditor_SetSetting_int(editor,'pixels_per_timebase_unit',desired) or
   R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')~=desired then
   R.MIDIEditor_SetSetting_int(editor,'pixels_per_timebase_unit',old)
   error('Horizontaler Zoom konnte nicht gesetzt werden.')
  end
 end
 -- Deliberately omit unverified vertical zoom sequences and SCORE/clef edits.
end
local ok,why=xpcall(run,debug.traceback)
if not ok then R.ShowMessageBox(tostring(why),'Native Notation Studio - Offline',0) end
