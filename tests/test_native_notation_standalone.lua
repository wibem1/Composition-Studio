-- Runs the complete standalone file in an isolated REAPER simulation, no API traffic.
local source=assert(io.open('Native-Notation-Studio.lua','rb')):read('*a')
local checks=0
local function test(name,f) f();checks=checks+1;print('PASS '..name) end
local function reject(f) local ok=pcall(f);assert(not ok,'expected rejection') end
local event=function(d,f,m) return string.pack('i4Bs4',d,f,m) end
local prefix=string.char(255,15)
local function fixture()
 -- Expressive eighth notes, chord/overlap, note-off velocity, pedal, sysex,
 -- muted event, notation articulation, empty terminal event and signed deltas.
 return event(30,1,string.char(0x90,60,87))..
 event(0,0,prefix..'NOTE 0 60 articulation staccato')..
 event(0,0,string.char(0xB0,64,127))..
 event(420,1,string.char(0x80,60,35))..
 event(60,3,string.char(0x91,67,94))..
 event(-10,0,string.char(0xF0,1,2,0xF7))..
 event(400,3,string.char(0x91,67,0))..
 event(100,0,string.char(0xB0,64,0))..event(2840,0,'')
end
local function ordinary(raw)
 local result,pos,tick={},1,0
 while pos<=#raw do
  local d,f,m;d,f,m,pos=string.unpack('i4Bs4',raw,pos);tick=tick+d
  if m:sub(1,2)~=prefix then result[#result+1]=string.pack('i8Bs4',tick,f,m) end
 end
 return table.concat(result)
end
local function harness(options)
 local o=options or {};local state={streams={fixture(),fixture()},undo=0,writes=0,messages={},files={},queue={},time=0,actions={},visible={1,2},stamp=0,project=42,failAt=o.failAt}
 local notes={{true,false,false,30,450,0,60,87},{true,true,false,510,900,1,67,94}}
 local r={
 EnumProjects=function() return state.project end,
 MIDIEditor_GetActive=function() if state.editorClosed then return nil end;return 50 end,
 MIDIEditor_GetMode=function() return state.editorClosed and -1 or 0 end,
 MIDIEditor_EnumTakes=function(_,i,editable) assert(editable==false);return state.visible[i+1] end,
 GetMediaItemTake_Item=function(t) return t end,
 GetActiveTake=function(t) return t end,
 TakeIsMIDI=function() return true end,
 MIDI_CountEvts=function() return true,o.noteCount or #notes end,
 MIDI_GetNote=function(_,i) return table.unpack(notes[i%2+1]) end,
 MIDI_GetAllEvts=function(t) return true,state.streams[t] end,
 MIDI_GetProjQNFromPPQPos=function(_,p) return p/960 end,
 MIDI_GetPPQPosFromProjQN=function(_,q) return q*960 end,
 GetMediaItemInfo_Value=function(_,key) return ({D_POSITION=0,D_LENGTH=4,B_LOOPSRC=o.loop and 1 or 0})[key] end,
 GetMediaItemTakeInfo_Value=function(_,key) return ({D_PLAYRATE=o.rate or 1,D_STARTOFFS=0})[key] end,
 GetItemStateChunk=function() return true,o.pool and 'POOLEDEVTS {1234-1111}' or '<ITEM\n>' end,
 TimeMap2_timeToQN=function(_,v) return v end,
 TimeMap_QNToMeasures=function(_,q) return math.floor(q/4),math.floor(q/4)*4,math.floor(q/4)*4+4 end,
 GetProjectStateChangeCount=function() return state.stamp end,
 ValidatePtr2=function() return not state.deleted end,
 GetResourcePath=function() return '/fixture space/Ümlaut' end,
 GetExtState=function() return o.live and '' or '/response.txt' end,
 GetOS=function() return o.windows and 'Win64' or 'OSX64' end,
 genGuid=function() return '{1234-5678}' end,
 ExecProcess=function(command,timeout) assert(timeout==-2);state.command=command;return o.launchFail and nil or '0\n' end,
 time_precise=function() return state.time end,
 defer=function(f) state.queue[#state.queue+1]=f end,
 atexit=function(f) state.exit=f end,
 ShowMessageBox=function(msg) state.messages[#state.messages+1]=msg;return 0 end,
 MIDI_SetAllEvts=function(t,raw)
  state.writes=state.writes+1
  if state.failAt==state.writes then state.streams[t]='damaged';return false end
  if o.rollbackFail and state.writes>2 then return false end
  state.streams[t]=raw;state.stamp=state.stamp+1;return true
 end,
 Undo_BeginBlock2=function(p) assert(p==42);state.undo=state.undo+1;state.snapshot={table.unpack(state.streams)} end,
 Undo_EndBlock2=function(p,_,flags) assert(p==42 and flags==4);state.undo=state.undo-1 end,
 UpdateItemInProject=function() end,
 SectionFromUniqueID=function(id) assert(id==32060);return id end,
 kbd_enumerateActions=function(_,i)
  return ({11,12,0})[i+1],({'View: Mode: Musical notation','Notation: Proportional (musical) note spacing'})[i+1]
 end,
 GetToggleCommandStateEx=function() return 0 end,
 MIDIEditor_OnCommand=function(_,id) state.actions[#state.actions+1]=id;return true end
 }
 local fs={open=function(path,mode)
  if mode=='rb' then
   if not state.files[path] then return nil end
   return {read=function(_,n) if n=='*a' then return state.files[path] end;return state.files[path]:sub(1,n) end,close=function() return true end}
  end
  if o.diskFail then return nil end
  state.files[path]=''
  return {write=function(_,...) for _,v in ipairs({...}) do state.files[path]=state.files[path]..v end;return true end,close=function() return true end}
 end}
 state.files['/response.txt']='DISPLAY|1|0|0.5|SICHER\nDISPLAY|3|0|0.5|SICHER'
 local env=setmetatable({reaper=r,NATIVE_NOTATION_TEST=true,io=fs,
 os=setmetatable({getenv=function(k) if k=='OPENAI_API_KEY' and not o.noKey then return 'secret-test-key' end end,
 remove=function(p) state.files[p]=nil;return true end},{__index=os}),
 gfx={init=function() end,quit=function() state.closed=true end,getchar=function() return state.cancel and 27 or 0 end,drawstr=function() end,update=function() end,mouse_cap=0}}, {__index=_G})
 env._G=env
 local api=assert(load(source,'@Native-Notation-Studio.lua','t',env))()
 state.poll=function() local f=table.remove(state.queue,1);assert(f);f() end
 return api,state,r
end
local api,state=harness()
test('complete standalone Lua 5.4 load',function() assert(type(api.run)=='function') end)
test('all displayed takes, all notes regardless selection',function()
 local rows=api.selected();assert(#rows==2 and #rows[1].notes==2 and #rows[2].notes==2)
end)
for name,o in pairs({loop={loop=true},pool={pool=true},rate={rate=0.5}}) do test('reject unsupported source '..name,function() reject(function() harness(o).selected() end) end) end
local targets={{row={start_qn=0,end_qn=4},note={start_qn=30/960,duration_qn=420/960}}}
local good='DISPLAY|1|0|0.5|SICHER'
test('valid conservative display plan',function() local p=api.parse(good,targets);assert(p[1].start==-30/960 and p[1].length==0.0625) end)
for i,bad in ipairs({good..'\n'..good,good..'\n'..good..'\n'..good,'DISPLAY|1|0|1e999|SICHER','DISPLAY|1|nan|0.5|SICHER','DISPLAY|1|1|0.5|SICHER','DISPLAY|1|0|0.5|UNSICHER','DISPLAY|1|0|0|SICHER','DISPLAY|99|0|0.5|SICHER','DISPLAY|1|-1|0.5|SICHER','DISPLAY|1|0|9|SICHER'}) do
 test('reject invalid DISPLAY '..i,function() assert(next(api.parse(bad,targets))==nil) end)
end
local edit={{tick=30,channel=0,pitch=60,start=-30/960,length=0.0625}}
test('preserve absolute MIDI events, flags, bytes, pedal, sysex and tail',function()
 local raw=fixture();local out,n=api.stream(raw,edit);assert(n==1 and ordinary(out)==ordinary(raw));assert(out:find('articulation staccato disp_pos',1,true))
 assert(api.stream(out,edit)==out,'manual overrides/idempotency')
end)
for _,count in ipairs({2,3,4}) do test('ambiguous simultaneous note-ons '..count,function()
 local raw=event(30,1,string.char(0x90,60,80))
 for _=2,count do raw=raw..event(0,1,string.char(0x90,60,80)) end
 assert(api.stream(raw,edit)==raw)
end) end
for _,count in ipairs({2,3}) do test('ambiguous metadata '..count,function()
 local raw=event(30,1,string.char(0x90,60,80))
 for _=1,count do raw=raw..event(0,0,prefix..'NOTE 0 60') end
 assert(api.stream(raw,edit)==raw)
end) end
test('truncated raw stream fails before write',function() reject(function() api.stream(fixture():sub(1,-3),edit) end) end)
test('complete run writes two takes and native view; simulated undo restores originals',function()
 local a,s=harness();a.run();assert(s.writes==2 and s.undo==0 and #s.actions==2)
 for i=1,2 do assert(ordinary(s.streams[i])==ordinary(s.snapshot[i])) end
 s.streams=s.snapshot;assert(s.streams[1]==fixture() and s.streams[2]==fixture())
end)
test('second take write failure restores every attempted stream',function()
 local a,s=harness({failAt=2});reject(a.run);assert(s.writes==4 and s.undo==0 and s.streams[1]==fixture() and s.streams[2]==fixture())
end)
test('rollback failure is reported and undo block closes',function()
 local a,s=harness({failAt=2,rollbackFail=true});local ok,err=pcall(a.run);assert(not ok and err:find('Wiederherstellung fehlgeschlagen',1,true) and s.undo==0)
end)
test('over 500 visible notes fails as whole, no API and no MIDI writes',function()
 local a,s=harness({noteCount=251});reject(a.run);assert(s.writes==0 and not s.command)
end)
test('disk failure before API or MIDI write',function() local a,s=harness({diskFail=true});reject(a.run);assert(s.writes==0 and not s.command) end)
test('missing API key fails before background launch',function() local a,s=harness({live=true,noKey=true});reject(a.run);assert(s.writes==0 and not s.command) end)
test('closed MIDI editor fails before processing',function() local a,s=harness();s.editorClosed=true;reject(a.run);assert(s.writes==0) end)
test('process launch failure no write',function()
 local a,s,r=harness({live=true});r.ExecProcess=function() return nil end;reject(a.run);assert(s.writes==0)
end)
test('write readback corruption triggers verified rollback',function()
 local a,s,r=harness();local write=r.MIDI_SetAllEvts
 r.MIDI_SetAllEvts=function(t,raw) local ok=write(t,raw);if s.writes==1 then s.streams[t]='corrupt' end;return ok end
 reject(a.run);assert(s.writes==2 and s.undo==0 and s.streams[1]==fixture() and s.streams[2]==fixture())
end)
test('6/8 triplets accepted; grace-length notes and off-grid proposals skipped',function()
 local a,s,r=harness();r.TimeMap_QNToMeasures=function(_,q) return math.floor(q/3),math.floor(q/3)*3,math.floor(q/3)*3+3 end
 local t={{row={start_qn=0,end_qn=6},note={start_qn=3.02,duration_qn=0.31}}}
 assert(a.parse('DISPLAY|1|3|0.333333333|SICHER',t)[1])
 assert(next(a.parse('DISPLAY|1|3.04|0.333333333|SICHER',t))==nil)
 t[1].note.duration_qn=0.02;assert(next(a.parse('DISPLAY|1|3|0.125|SICHER',t))==nil)
end)
local function response(text)
 return '{"status":"completed","output":[{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":'..api.json_string(text)..'}]}]}'
end
test('JSON Unicode surrogate pair, escapes, controls and multi-part text',function()
 assert(api.decode_json('"\\uD834\\uDD1E"')=='𝄞')
 local input='a\0\b\f\n\r\t"\\/Ü';assert(api.decode_json(api.json_string(input))==input)
 assert(api.response_text(response(good))==good)
 assert(api.response_text('{"status":"completed","output":[{"type":"reasoning","text":"ignored"},{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"A"},{"type":"output_text","text":"B"}]}]}')=='A\nB')
end)
for i,bad in ipairs({'{"x":1,"x":2}','[01]','[1.]','[1e]','[1e999]','"\\uD800"','"\\q"','{"x":1,}','[] trailing','"unfinished','['..string.rep('[',50)..']'..string.rep(']',50)}) do test('reject malformed JSON '..i,function() reject(function() api.decode_json(bad) end) end) end
for i,bad in ipairs({'{"error":{"message":"DISPLAY|1|0|0.5|SICHER"}}','{"status":"incomplete","output":[]}','{"status":"completed","output":[]}',response(good):gsub('output_text','refusal'),response(good):gsub('"role":"assistant"','"role":"user"'),string.rep('a',1048577)}) do test('reject bad API envelope '..i,function() reject(function() api.response_text(bad) end) end) end
for _,win in ipairs({false,true}) do test('transport path quoting and no persisted key '..tostring(win),function()
 local a,s=harness({windows=win});local j=a.transport_files('/tmp/Ü a\'b$`;x',win,'a\n"b','test-model')
 local req=a.decode_json(s.files[j.request]);assert(req.input=='a\n"b' and req.max_output_tokens==6000 and req.store==false)
 for _,v in pairs(s.files) do assert(not v:find('secret-test-key',1,true)) end
 assert(j.command:find(win and 'powershell.exe' or '/bin/sh',1,true))
end) end
local function finish(a,s,code,text)
 for p in pairs(s.files) do if p:match('NNS%-.*%.json$') then local base=p:sub(1,-6);s.files[base..'.done']=code;s.files[base..'.response']=text end end
 s.poll()
end
test('deferred live path with simulated successful API and two-take write',function()
 local a,s=harness({live=true});a.run();assert(s.writes==0 and #s.queue==1);finish(a,s,'0',response(good..'\nDISPLAY|3|0|0.5|SICHER'));assert(s.writes==2 and s.undo==0)
end)
test('cancel while API running never writes, even after response arrives',function()
 local a,s=harness({live=true});a.run();s.cancel=true;s.poll();finish(a,s,'0',response(good));assert(s.writes==0 and s.closed)
end)
for _,kind in ipairs({'project','stamp','visibility','deleted','bytes','editor'}) do test('stale '..kind..' fails before writing',function()
 local a,s=harness({live=true});a.run()
 if kind=='project' then s.project=99 elseif kind=='stamp' then s.stamp=1 elseif kind=='visibility' then s.visible={1} elseif kind=='deleted' then s.deleted=true elseif kind=='editor' then s.editorClosed=true else s.streams[2]='changed' end
 finish(a,s,'0',response(good));assert(s.writes==0 and #s.messages>0)
end) end
for _,code in ipairs({'22','28','999'}) do test('HTTP/process error '..code..' no write',function()
 local a,s=harness({live=true});a.run();finish(a,s,code,response(good));assert(s.writes==0 and #s.messages>0)
end) end
test('gfx focus does not invalidate the captured MIDI editor',function()
 local a,s,r=harness({live=true});a.run();r.MIDIEditor_GetActive=function() return nil end
 finish(a,s,'0',response(good));assert(s.writes==1)
end)
test('early or malformed completion marker keeps waiting safely',function()
 local a,s=harness({live=true});a.run();finish(a,s,'','');assert(s.writes==0 and #s.queue==1)
end)
test('oversized response fails without writes',function()
 local a,s=harness({live=true});a.run();finish(a,s,'0',string.rep('X',1048577));assert(s.writes==0 and #s.messages>0)
end)
test('strict JSON rejects invalid UTF-8 and whitespace',function()
 reject(function() api.decode_json('"'..string.char(255)..'"') end)
 reject(function() api.decode_json('[1,\v2]') end)
end)
test('timeout no write',function() local a,s=harness({live=true});a.run();s.time=101;s.poll();assert(s.writes==0 and #s.messages>0 and #s.queue==0) end)
test('no valid interpretation leaves MIDI and undo unchanged',function() local a,s=harness();s.files['/response.txt']='uncertain';a.run();assert(s.writes==0 and s.undo==0) end)
print(('PASS %d standalone tests; no live API traffic'):format(checks))
