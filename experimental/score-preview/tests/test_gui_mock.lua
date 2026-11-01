-- Execute native ReaImGui preview script under a read-only REAPER simulation.
local deferred,draw_count={},0
local begins,ends,dummies=0,0,0
local edits={MIDI_SetNote=0,MIDI_InsertNote=0,MIDI_DeleteNote=0,MIDI_SetAllEvts=0}
local take,item={},{}
local r={
 ImGui_CreateContext=function() return {} end,
 ImGui_Begin=function()
  begins=begins+1
  return true,true
 end,
 ImGui_End=function()
  ends=ends+1
  assert(ends<=begins,'ImGui_End without a matching main window')
 end,
 -- ReaImGui's nested child window path caused two different real Windows
 -- assertion failures. Keep this test strict: no child API may be invoked.
 ImGui_BeginChild=function() error('Unexpected ImGui_BeginChild: score must use main-window canvas') end,
 ImGui_EndChild=function() error('Unexpected ImGui_EndChild: score must use main-window canvas') end,
 ImGui_Text=function() end,
 ImGui_SameLine=function() end,
 ImGui_Button=function() return false end,
 ImGui_GetCursorScreenPos=function() return 40,50 end,
 ImGui_GetWindowDrawList=function() return {} end,
 ImGui_DrawList_AddLine=function() draw_count=draw_count+1 end,
 ImGui_DrawList_AddText=function() draw_count=draw_count+1 end,
 ImGui_DrawList_AddEllipseFilled=function() draw_count=draw_count+1 end,
 ImGui_DrawList_AddCircleFilled=function() draw_count=draw_count+1 end,
 ImGui_DrawList_AddRectFilled=function() draw_count=draw_count+1 end,
 ImGui_Dummy=function(_,w,h)
  assert(type(w)=='number' and type(h)=='number')
  assert(w>=800 and h>=100,'Score canvas reservation is invalid')
  dummies=dummies+1
 end,
 CountSelectedMediaItems=function() return 1 end,
 GetSelectedMediaItem=function() return item end,
 GetActiveTake=function() return take end,
 TakeIsMIDI=function(t) return t==take end,
 GetSetMediaItemTakeInfo_String=function() return true,'Church Organ' end,
 GetMediaItem_Track=function() return {} end,
 GetTrackName=function() return true,'Church Organ' end,
 MIDI_CountEvts=function() return true,3,0,0 end,
 MIDI_GetNote=function(_,i)
  local n={{0,960,0,72},{0,1920,0,76},{960,1920,0,79}}
  local t=n[i+1]
  return true,false,false,t[1],t[2],t[3],t[4],90
 end,
 MIDI_GetProjQNFromPPQPos=function(_,ppq) return ppq/960 end,
 GetMediaItemInfo_Value=function() return 0 end,
 TimeMap2_timeToQN=function(_,value) return value end,
 defer=function(fn) deferred[#deferred+1]=fn end,
 ShowMessageBox=function(str) error('Unexpected dialog '..str) end,
}
for method in pairs(edits) do r[method]=function() edits[method]=edits[method]+1 end end
reaper=r
local ok,err=pcall(dofile,'experimental/score-preview/Notation Studio - Notenbild Test.lua')
assert(ok,tostring(err))
assert(#deferred==1,'initial window must defer one GUI frame')
local okframe,errframe=pcall(deferred[1])
assert(okframe,tostring(errframe))
assert(draw_count>18,'No real staff drawing occurred ('..draw_count..')')
assert(begins==1 and ends==1,'Mismatched main window stack')
assert(dummies==1,'Main-window score canvas was not reserved')
assert(#deferred==2,'One follow-up frame should be scheduled')
local next_ok,next_err=pcall(deferred[2])
assert(next_ok,'Second frame failed: '..tostring(next_err))
assert(begins==2 and ends==2 and dummies==2,'Second frame stack mismatch')
for name,count in pairs(edits) do assert(count==0,name..' modified MIDI') end
print('OK: ReaImGui main-window canvas, 2 frames, no child windows; '..draw_count..' drawing calls; zero MIDI edits')
