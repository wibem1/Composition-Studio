from pathlib import Path
from lupa.lua54 import LuaRuntime
source=Path('REAPER_Notation_Diagnose.lua').read_text()
for missing_editor,translated,missing_api in [(False,False,False),(False,True,False),(True,False,False),(False,False,True)]:
 r=LuaRuntime(unpack_returned_tuples=True)
 r.globals().MISSING_EDITOR=missing_editor;r.globals().TRANSLATED=translated
 r.execute('''
 report=""
 local labels={"View: Zoom to project loop selection","Notation: Proportional (musical) note spacing","View: Zoom to content","View: Zoom in vertically"}
 reaper=setmetatable({
  GetAppVersion=function()return "7.83" end,GetOS=function()return "Win64" end,
  get_action_context=function()return false,"diagnose.lua",32060,123 end,
  MIDIEditor_GetActive=function()return not MISSING_EDITOR and 42 or nil end,
  MIDIEditor_EnumTakes=function(_,i)if i==0 then return "take" end end,
  MIDIEditor_GetTake=function()return "take"end,TakeIsMIDI=function()return true end,
  GetMediaItemTake_Item=function()return "item"end,GetMediaItem_Track=function()return "track"end,
  MIDI_CountEvts=function()return true,20 end,MIDI_GetNote=function()return true end,
  GetTrackStateChunk=function()return true,"<TRACK\\nSCORE 0 1 0 0\\n>"end,
  GetCursorPosition=function()return 0 end,TimeMap2_timeToQN=function(_,x)return x end,
  TimeMap_QNToMeasures=function()return 0,0,4 end,TimeMap2_QNToTime=function(_,x)return x end,
  GetSet_LoopTimeRange2=function()return 0,4 end,
  SectionFromUniqueID=function()return "section"end,
  kbd_enumerateActions=function(_,i)if not labels[i+1]then return 0,""end;return i+1,TRANSLATED and "Ansicht: Zoom "..i or labels[i+1]end,
  GetToggleCommandStateEx=function()return 1 end,
  ShowConsoleMsg=function(s)report=report..s end,
 },{__index=function(_,name)error("Forbidden/unexpected API: "..name)end})
 ''')
 if missing_api:r.execute('reaper.SectionFromUniqueID=false')
 r.execute(source)
 report=r.globals().report
 assert 'DIAGNOSEFEHLER' not in report,report
 if missing_editor:assert 'NICHT GEFUNDEN' in report
 if translated:assert 'FEHLT | View:' in report and 'Ansicht: Zoom' in report
 if missing_api:assert 'MIDI-Aktionsliste NICHT LESBAR' in report
 if not any((missing_editor,translated,missing_api)):assert 'GEFUNDEN 1' in report and 'Noten=20' in report
print('PASS: 4 production-script scenarios; any unexpected or mutating API fails the test')
