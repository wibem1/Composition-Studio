-- @description Development test: Native Notation Studio in an isolated EMPTY project
-- Does not call a provider. Run through tools/test_native_notation_reaper.py.
local logPath=os.getenv('NNS_NATIVE_TEST_LOG') or (reaper.GetResourcePath()..'/NativeNotationStudio-native-test.log')
local fixturePath=reaper.GetResourcePath()..'/NNS-native-display-fixture.txt'
local scriptPath=debug.getinfo(1,'S').source:sub(2)
local root=assert(scriptPath:match('^(.*)[/\\]tests[/\\]'),'Absolute tests script path required')
local logFile=assert(io.open(logPath,'w'))
local function log(s) logFile:write(s,'\n');logFile:flush() end
log('START '..reaper.GetAppVersion())
local R=reaper
local ok,why=xpcall(function()
 local project=R.EnumProjects(-1,'')
 assert(R.CountTracks(project)==0,'This regression requires an isolated EMPTY project; no changes made')
 for i=0,1 do
  R.InsertTrackAtIndex(i,false)
  local track=R.GetTrack(project,i)
  local item=R.CreateNewMIDIItemInProj(track,0,4,false)
  log('LOOP_SOURCE_FLAG '..tostring(R.GetMediaItemInfo_Value(item,'B_LOOPSRC')))
  R.SetMediaItemSelected(item,true)
  local take=R.GetActiveTake(item)
  R.MIDI_InsertNote(take,false,false,30,450,0,i==0 and 36 or 72,87,false)
  R.MIDI_InsertNote(take,false,false,510,900,1,i==0 and 43 or 79,94,false)
 end
 R.Undo_OnStateChangeEx2(project,'Native fixture baseline',-1,-1)
 R.Main_OnCommand(40153,0)
 log('OPEN COMMAND SENT')
 local function audit()
  local good,errorMessage=xpcall(function()
   local editor=assert(R.MIDIEditor_GetActive(),'no native MIDI editor')
   log('NATIVE EDITOR OPEN')
   local proxy=setmetatable({
    ShowMessageBox=function(message) log('STATUS '..message);return 0 end,
    GetExtState=function(section,key)
     if section=='NativeNotationStudio' and key=='TestResponseFile' then return fixturePath end
     if section=='NativeNotationStudio' and key=='ZoomPercent' then return '100' end
     return R.GetExtState(section,key)
    end
   },{__index=R})
   local env=setmetatable({NATIVE_NOTATION_MODULE=true,reaper=proxy},{__index=_G});env._G=env
   local api=assert(loadfile(root..'/Native-Notation-Studio.lua','t',env))()
   local rows=api.selected();log('VISIBLE TAKES '..#rows);assert(#rows==2,'native visible scope is not both tracks')
   local response=assert(io.open(fixturePath,'w'))
   local id=0;local originals={}
   for _,row in ipairs(rows) do
    local _,takeID=R.GetSetMediaItemTakeInfo_String(row.take,'GUID','',false)
    originals[takeID]=row.raw
    for _,note in ipairs(row.notes) do
     id=id+1
     response:write(('DISPLAY|%d|%.9f|0.5|SICHER\n'):format(id,math.floor(note.start_qn*2+0.5)/2))
    end
   end
   response:close()
   api.run()
   local value=R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')
   local unit=R.MIDIEditor_GetSetting_int(editor,'timebase_unit')
   log('ZOOM '..value..' UNIT '..unit)
   assert(value==81920 or value==163840,'unexpected native zoom')
   local function ordinary(raw)
    local out,pos,tick={},1,0
    while pos<=#raw do
     local d,flags,message;d,flags,message,pos=string.unpack('i4Bs4',raw,pos);tick=tick+d
     if message:sub(1,2)~=string.char(255,15) then out[#out+1]=string.pack('i8Bs4',tick,flags,message) end
    end
    return table.concat(out)
   end
   for i=0,1 do
    local track=R.GetTrack(project,i)
    local _,chunk=R.GetTrackStateChunk(track,'',false)
    local _,clef=api.track_clef_chunk(chunk)
    log('CLEF TRACK '..i..' '..clef)
    assert(clef==(i==0 and 2 or 1),'wrong native clef value')
    local tk=R.GetActiveTake(R.GetTrackMediaItem(track,0))
    local _,takeID=R.GetSetMediaItemTakeInfo_String(tk,'GUID','',false)
    local _,raw=R.MIDI_GetAllEvts(tk)
    assert(ordinary(raw)==ordinary(originals[takeID]),'performance changed in native standalone flow')
   end
   log('PASS native two-track standalone flow, clefs, zoom and performance integrity')
   local currentRows=api.selected()
   api.apply_zoom(currentRows,editor,150)
   local enlarged=R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')
   api.apply_zoom(currentRows,editor,150)
   assert(R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')==enlarged and enlarged==value*1.5,'native repeated zoom accumulated')
   api.apply_zoom(currentRows,editor,100)
   log('PASS native absolute zoom 150 percent, repeated and reset')
   R.Undo_DoUndo2(project)
   for i=0,1 do
    local tk=R.GetActiveTake(R.GetTrackMediaItem(R.GetTrack(project,i),0))
    local _,raw=R.MIDI_GetAllEvts(tk)
    local _,takeID=R.GetSetMediaItemTakeInfo_String(tk,'GUID','',false)
    assert(raw==originals[takeID],'native Undo did not restore original MIDI')
    local _,chunk=R.GetTrackStateChunk(R.GetTrack(project,i),'',false)
    local _,clef=api.track_clef_chunk(chunk);assert(clef==0,'native Undo did not restore original default clef')
   end
   log('PASS native standalone Undo')
   R.Undo_DoRedo2(project)
   local _,chunk=R.GetTrackStateChunk(R.GetTrack(project,0),'',false)
   local _,clef=api.track_clef_chunk(chunk);assert(clef==2)
   log('PASS native standalone Redo')
   os.remove(fixturePath)
  end,debug.traceback)
  log(good and 'ALL PASSED' or ('FAIL '..tostring(errorMessage)));logFile:close()
 end
 R.defer(audit)
end,debug.traceback)
if not ok then log('FAIL '..tostring(why));logFile:close() end
