local source = assert(io.open("Composition Studio.lua","rb")):read("*a")
local code = assert(source:match("%-%- BEGIN NATIVE NOTATION\n(.-)%-%- END NATIVE NOTATION"))
local adapter = {guard=function() return "original" end}
local note = {start_qn=0.03125,duration_qn=0.4375,channel=1,pitch=60}
local function event(delta,flags,msg) return string.pack("i4Bs4",delta,flags,msg) end
local prefix=string.char(255,15)
local on=event(30,1,string.char(0x91,60,80))
local off=event(420,1,string.char(0x81,60,40))
local pedal=event(0,0,string.char(0xB1,64,127))
local tail=event(3390,0,string.char(0xB1,123,0))
local raw=on..pedal..off..tail
local row={take=1,item=1,start_qn=0,end_qn=4,original_stream=raw}
local targets={{note=note,item=row}}
local streams={raw,raw}
local undo,write=0,0
local fail
local reaper={
 TimeMap_QNToMeasures=function(_,qn) return math.floor(qn/4),math.floor(qn/4)*4 end,
 MIDI_GetPPQPosFromProjQN=function(_,qn) return qn*960 end,
 ValidatePtr2=function() return true end,
 MIDI_GetAllEvts=function(take) return true,streams[take] end,
 MIDI_SetAllEvts=function(take,buf)
  write=write+1
  if fail and write==2 then return false end
  streams[take]=buf;return true
 end,
 Undo_BeginBlock2=function() undo=undo+1 end,
 Undo_EndBlock2=function() undo=undo-1 end,
 UpdateItemInProject=function() end
}
assert(load(code,"notation","t",setmetatable({workflow_adapter=adapter,reaper=reaper},{__index=_G})))()
local good="DISPLAY|1|0|0.5|SICHER"
local data={workflow_guard="original",targets=targets}
local changed,represented=adapter.write_native_notation(good,data)
assert(changed==1 and represented==1 and undo==0)
local expected=on..event(0,0,prefix.."NOTE 1 60 disp_pos -0.031250000 disp_len 0.062500000")..pedal..off..tail
assert(streams[1]==expected,"all non-notation bytes and positions must remain unchanged")
assert(not pcall(adapter.write_native_notation,good,data),"reject stale raw events")
data.workflow_guard="stale"
assert(not pcall(adapter.write_native_notation,good,data),"reject stale project before writing")
assert(write==1)
for _,bad in ipairs({good.."\n"..good,"DISPLAY|1|0|0.5|UNSICHER","DISPLAY|1|0|1e999|SICHER",
 "DISPLAY|1|1|0.5|SICHER","DISPLAY|1|0|0.125|SICHER","DISPLAY|999|0|0.5|SICHER"}) do
 assert(next(adapter.notation_plan(bad,targets))==nil,bad)
end
local edit={{tick=30,channel=1,pitch=60,start=0,length=0.0625}}
local original_meta=event(0,0,prefix.."NOTE 1 60 articulation staccato")
local annotated=on..original_meta..pedal..off..tail
assert(adapter.notation_stream(annotated,edit)==on..event(0,0,prefix.."NOTE 1 60 articulation staccato disp_len 0.062500000")..pedal..off..tail)
assert(adapter.notation_stream(expected,edit)==expected,"preserve manual display overrides")
local doubled=on..event(0,1,string.char(0x91,60,70))..off..tail
assert(adapter.notation_stream(doubled,edit)==doubled,"ambiguous note-on remains untouched")
local row2={take=2,item=2,start_qn=0,end_qn=4,original_stream=raw}
streams={raw,raw};write=0;fail=true
assert(not pcall(adapter.write_native_notation,good.."\nDISPLAY|2|0|0.5|SICHER",
 {workflow_guard="original",targets={targets[1],{item=row2,note=note}}}))
assert(streams[1]==raw and streams[2]==raw and undo==0,"multi-take rollback")
print("PASS native notation plan, protected events, ambiguous notes, stale responses and transactional rollback")
