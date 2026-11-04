-- @description Composition Studio - Display length feasibility test (selected notes)
-- @version 0.1.0-test
-- Test on a COPY of a project. Changes notation metadata only; use REAPER Undo.
local r=reaper
local editor=r.MIDIEditor_GetActive()
if not editor then return end
local changed=0
local function process(take)
 if not take or not r.TakeIsMIDI(take) then return end
 r.MIDI_Sort(take)
 local _,nn,_,nt=r.MIDI_CountEvts(take)
 local notes={}
 for i=0,nn-1 do
  local ok,sel,_,s,e,ch,p=r.MIDI_GetNote(take,i)
  if ok and sel then notes[#notes+1]={s=s,e=e,ch=ch,p=p} end
 end
 if #notes==0 then return end
 local q0=r.MIDI_GetProjQNFromPPQPos(take,0)
 local ppq=r.MIDI_GetPPQPosFromProjQN(take,q0+1)-r.MIDI_GetPPQPosFromProjQN(take,q0)
 if ppq<=0 then return end
 local existing={}
 for i=0,nt-1 do
  local ok,_,_,pos,typ,msg=r.MIDI_GetTextSysexEvt(take,i)
  if ok and typ==15 then
   local ch,p=msg:match("^NOTE (%d+) (%d+)")
   if ch then
    local key=string.format("%.8f:%d:%d",pos,tonumber(ch),tonumber(p))
    existing[key]=existing[key] or {}
    table.insert(existing[key],{i=i,msg=msg})
   end
  end
 end
 local edits,adds={},{}
 for _,n in ipairs(notes) do
  local d=(ppq/2-(n.e-n.s))/ppq
  local key=string.format("%.8f:%d:%d",n.s,n.ch,n.p)
  local list=existing[key]
  local ev=list and table.remove(list,1)
  if ev then
   local msg=ev.msg:gsub(" disp_len [+-]?[%d%.]+","")
   if math.abs(d)>0.0005 then msg=msg..string.format(" disp_len %.6f",d) end
   edits[#edits+1]={i=ev.i,msg=msg}
  elseif math.abs(d)>0.0005 then
   adds[#adds+1]={s=n.s,msg=string.format("NOTE %d %d disp_len %.6f",n.ch,n.p,d)}
  end
  changed=changed+1
 end
 r.MIDI_DisableSort(take)
 for _,e in ipairs(edits) do r.MIDI_SetTextSysexEvt(take,e.i,nil,nil,nil,15,e.msg,true) end
 for _,e in ipairs(adds) do r.MIDI_InsertTextSysexEvt(take,false,false,e.s,15,e.msg) end
 r.MIDI_Sort(take)
 r.MarkTrackItemsDirty(r.GetMediaItemTake_Track(take),r.GetMediaItemTake_Item(take))
end
r.Undo_BeginBlock2(0)
local i=0
while true do
 local take=r.MIDIEditor_EnumTakes(editor,i,true)
 if not take then break end
 process(take)
 i=i+1
end
r.Undo_EndBlock2(0,"Notation test: display selected notes as eighths",-1)
r.ShowConsoleMsg("Display-length test: "..changed.." selected notes processed. MIDI note events untouched.\n")
