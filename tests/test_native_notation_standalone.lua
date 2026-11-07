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
 state.chunks={}
 state.chunkWrites=0
 state.zoom=81920;state.zoomSets=0;state.generation=0
 local function itemID(t) return t%1000 end
 local function trackItems(t) return o.hidden and t==1 and {1,3} or {t} end
 if o.hidden then state.streams[3]=fixture() end
 local function hex(raw) return (raw:gsub('.',function(c) return ('%02x'):format(c:byte()) end)) end
 local function unhex(raw) return (raw:gsub('..',function(c) return string.char(tonumber(c,16)) end)) end
 local function defaultChunk(t)
  local s='<TRACK {TRACK'..t..'}\nNAME "Untouched name"\nSCORE 6 '..(o.currentClef or 1)..' 0.125 0.25\n<FXCHAIN\nSCORE nested must stay\n>\n'
  for _,id in ipairs(trackItems(t)) do s=s..'<ITEM\nGUID {I'..id..'}\nNNS_RAW '..id..' %RAW'..id..'%\n>\n' end
  return s..'>\n'
 end
 local notes={{true,false,false,30,450,0,60,87},{true,true,false,510,900,1,67,94}}
 local r={
 EnumProjects=function() return state.project end,
 MIDIEditor_GetActive=function() if state.editorClosed then return nil end;return 50 end,
 MIDIEditor_GetMode=function() return state.editorClosed and -1 or 0 end,
 MIDIEditor_EnumTakes=function(_,i,editable) assert(editable==false);return state.visible[i+1] end,
 GetMediaItem_Track=function(item) return item==3 and 1 or item end,
 GetSetMediaItemInfo_String=function(item) return true,'{I'..item..'}' end,
 GetSetMediaItemTakeInfo_String=function(t) return true,'{T'..itemID(t)..'}' end,
 CountMediaItems=function() return o.hidden and 3 or 2 end,
 GetMediaItem=function(_,i) return i+1 end,
 CountTrackMediaItems=function(t) return #trackItems(t) end,
 GetTrackMediaItem=function(t,i) return trackItems(t)[i+1] end,
 CountTakes=function() return 1 end,
 GetTake=function(item) return item+1000*state.generation end,
 GetTrackStateChunk=function(t)
  local template=state.chunks[t] or defaultChunk(t)
  return true,(template:gsub('%%RAW(%d+)%%',function(id) return hex(state.streams[tonumber(id)]) end))
 end,
 SetTrackStateChunk=function(t,chunk)
  state.chunkWrites=state.chunkWrites+1
  local template=chunk:gsub('NNS_RAW (%d+) ([%x]+)',function(id,data)
   state.streams[tonumber(id)]=unhex(data);return 'NNS_RAW '..id..' %RAW'..id..'%'
  end)
  state.chunks[t]=template
  if o.recreate then state.generation=state.generation+1 end
  if o.chunkCorrupt and state.chunkWrites==1 then state.streams[o.hidden and 3 or t]='changed' end
  if o.chunkFailAt==state.chunkWrites then return false end
  return true
 end,
 GetMediaItemTake_Item=function(t) return itemID(t) end,
 GetMediaItemTake_Source=function(t) return t end,
 GetMediaSourceLength=function() return o.sourceLength or 4,o.sourceSeconds~=true end,
 MIDI_GetProjTimeFromPPQPos=function(_,p) return (o.origin or 0)+p/960 end,
 GetActiveTake=function(t) return t end,
 TakeIsMIDI=function() return true end,
 MIDI_CountEvts=function() return not o.countFail,o.noteCount or #notes end,
 MIDI_GetNote=function(t,i) if o.noteFail then return false end;return table.unpack(o.badNote or (o.trackNotes and o.trackNotes[itemID(t)] and o.trackNotes[itemID(t)][i%2+1]) or notes[i%2+1]) end,
 MIDI_GetAllEvts=function(t) if o.recreate and t<1000*state.generation then return false end;return true,state.streams[itemID(t)] end,
 MIDI_GetProjQNFromPPQPos=function(_,p) if o.badQN then return 0/0 end;return (o.origin or 0)+p/960 end,
 MIDI_GetPPQPosFromProjQN=function(_,q) return q*960 end,
 GetMediaItemInfo_Value=function(_,key) return ({D_POSITION=0,D_LENGTH=4,B_LOOPSRC=o.loop and 1 or 0})[key] end,
 GetMediaItemTakeInfo_Value=function(_,key) return ({D_PLAYRATE=o.rate or 1,D_STARTOFFS=0})[key] end,
 GetItemStateChunk=function(item) return true,o.chunk or (o.pool and 'POOLEDEVTS {1234-1111}' or (o.uniquePools and ('POOLEDEVTS {1234-'..item..'}') or '<ITEM\n>')) end,
 TimeMap2_timeToQN=function(_,v) return v end,
 TimeMap_QNToMeasures=function(_,q) return math.floor(q/4),math.floor(q/4)*4,math.floor(q/4)*4+4 end,
 GetProjectStateChangeCount=function() return state.stamp end,
 ValidatePtr2=function() return not state.deleted end,
 GetResourcePath=function() return '/fixture space/Ümlaut' end,
 GetExtState=function(_,key) if key=='ZoomPercent' then return state.zoomPercent or '' end;return o.live and '' or '/response.txt' end,
 SetExtState=function(_,key,value) assert(key=='ZoomPercent');state.zoomPercent=value end,
 GetUserInputs=function() return not o.zoomCancel,o.zoomInput or '150' end,
 MIDIEditor_GetSetting_int=function(_,key) return key=='timebase_unit' and (o.timebase or 1) or state.zoom end,
 MIDIEditor_SetSetting_int=function(_,key,value) assert(key=='pixels_per_timebase_unit');state.zoomSets=state.zoomSets+1;state.zoom=value;return true end,
 GetCursorPositionEx=function() return 0 end,
 TimeMap2_GetDividedBpmAtTime=function() return o.bpm or 120 end,
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
  state.streams[itemID(t)]=raw;state.stamp=state.stamp+1;return true
 end,
 Undo_BeginBlock2=function(p) assert(p==42);state.undo=state.undo+1;state.snapshot={table.unpack(state.streams)};state.snapshotChunks={table.unpack(state.chunks)} end,
 Undo_EndBlock2=function(p,_,flags) assert(p==42 and (flags==4 or flags==5));state.undoFlags=flags;state.undo=state.undo-1 end,
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
 return api,state,r,env
end
local api,state=harness()
test('complete standalone Lua 5.4 load',function() assert(type(api.run)=='function') end)
test('all displayed takes, all notes regardless selection',function()
 local rows=api.selected();assert(#rows==2 and #rows[1].notes==2 and #rows[2].notes==2)
end)
for name,o in pairs({loop={loop=true,sourceLength=2},pool={pool=true},rate={rate=0.5}}) do test('reject unsupported source '..name,function() reject(function() harness(o).selected() end) end) end
test('ordinary non-repeating loop-source item is supported',function()
 local a,s=harness({loop=true});a.run();assert(s.writes==2)
end)
test('non-repeating seconds-based source is supported',function()
 local a,s=harness({loop=true,sourceSeconds=true});a.run();assert(s.writes==2)
end)
for name,opts in pairs({negative_origin={loop=true,origin=1},offset_repetition={loop=true,origin=-1},unknown_length={loop=true,sourceLength=0},infinite_length={loop=true,sourceLength=math.huge},independent_tempo={loop=true,chunk='IGNTEMPO 1 120 4 4'},second_pool={chunk='POOLEDEVTS {0000-0000}\nPOOLEDEVTS {1234-1111}'},note_read={noteFail=true},count_read={countFail=true},bad_qn={badQN=true}}) do
 test('preflight rejection '..name,function() local a,s=harness(opts);reject(a.run);assert(s.writes==0 and not s.command) end)
end
for name,note in pairs({zero_duration={true,false,false,30,30,0,60,80},negative_duration={true,false,false,30,20,0,60,80},fractional_pitch={true,false,false,30,60,0,60.5,80},invalid_channel={true,false,false,30,60,16,60,80},nan_tick={true,false,false,0/0,60,0,60,80},infinite_tick={true,false,false,30,math.huge,0,60,80},zero_velocity={true,false,false,30,60,0,60,0}}) do
 test('bad source note '..name,function() local a,s=harness({badNote=note});reject(a.run);assert(s.writes==0 and not s.command) end)
end
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
test('corrupt source stream fails before API launch',function()
 local a,s=harness({live=true});s.streams[1]=fixture():sub(1,-3);reject(a.run);assert(s.writes==0 and not s.command)
end)
test('cancelled oversized response is discarded and cleaned without an error',function()
 local a,s=harness({live=true});a.run();s.cancel=true;s.poll()
 finish(a,s,'0',string.rep('X',1048577));assert(s.writes==0 and #s.messages==0)
 for p in pairs(s.files) do assert(not p:find('NNS-',1,true)) end
end)
test('timeout no write',function() local a,s=harness({live=true});a.run();s.time=101;s.poll();assert(s.writes==0 and #s.messages>0 and #s.queue==0) end)
test('no valid interpretation leaves MIDI and undo unchanged',function() local a,s=harness();s.files['/response.txt']='uncertain';a.run();assert(s.writes==0 and s.undo==0) end)
local function score(notes,current) return api.choose_clef(notes,current or 0) end
local function n(p,start,duration,ch,muted)
 return {pitch=p,start_qn=start or 0,duration_qn=duration or 1,channel=ch or 0,muted=muted or false}
end
for _,case in ipairs({{'high',{{72,76,79}},1},{'low',{{36,40,48}},2},{'central single line',{{60}},1},{'wide single line',{{36,84}},nil}}) do
 test('automatic clef '..case[1],function()
  local notes={};for i,p in ipairs(case[2][1]) do notes[#notes+1]=n(p,i) end
  local chosen=score(notes)
  if case[3] then assert(chosen==case[3]) else assert(chosen==1 or chosen==2) end
 end)
end
for name,values in pairs({alto={3,60},tenor={4,58},octave={5,36},percussion={10,84},one_line={11,60},chart={12,60}}) do
 test('preserve suitable/conventional clef '..name,function() assert(score({n(values[2])},values[1])==values[1]) end)
end
test('GM percussion receives percussion clef',function() assert(score({n(38,0,1,9)},1)==10) end)
test('muted outlier does not change treble clef',function() assert(score({n(72),n(24,0,20,0,true)},1)==1) end)
test('clear existing two-hand chord keeps piano staff',function() assert(score({n(48),n(60),n(76)},0)==0) end)
test('wide sequential melody never creates piano staff',function() assert(score({n(36,0),n(60,1),n(84,2)},0)~=0) end)
test('same chord does not create piano staff from treble',function() assert(score({n(48),n(60),n(76)},1)~=0) end)
test('empty or fully muted track keeps current clef',function() assert(score({},0)==0 and score({n(36,0,1,0,true)},1)==1) end)
local complex='<TRACK {X}\r\nSCORE 6 1 0.125 0.25 extra\r\n<ITEM\r\nSCORE 0 9 9 9\r\n<SOURCE MIDI\r\nDATA preserved\r\n>\r\n>\r\n>\r\n'
test('only top-level clef changes; other fields and nested data are byte-exact',function()
 local patched,current=api.track_clef_chunk(complex,2)
 assert(current==1 and patched==complex:gsub('SCORE 6 1 0.125','SCORE 6 2 0.125',1))
 assert(api.track_clef_chunk(patched,2)==patched)
end)
test('default SCORE line can be inserted with CRLF preserved',function()
 local chunk='<TRACK {X}\r\nNAME "x"\r\n>\r\n'
 local patched,current=api.track_clef_chunk(chunk,1)
 assert(current==0 and patched=='<TRACK {X}\r\nSCORE 0 1 0 0\r\nNAME "x"\r\n>\r\n')
end)
for name,chunk in pairs({duplicate='<TRACK\nSCORE 0 1 0 0\nSCORE 0 2 0 0\n>\n',unclosed='<TRACK\n<ITEM\n>\n',wrong_root='<TRACKING\n>\n',unknown='<TRACK\nSCORE 0 99 0 0\n>\n',bad_fields='<TRACK\nSCORE 0 1 ??? 0\n>\n',extra_close='<TRACK\n>\n>\n'}) do
 test('reject ambiguous/unsupported track chunk '..name,function() reject(function() api.track_clef_chunk(chunk,2) end) end)
end
local function notePair(p,q)
 return {{true,false,false,30,450,0,p,87},{true,false,false,510,900,1,q,94}}
end
local function pitched(p,q)
 return (fixture():gsub(string.char(0x90,60,87),string.char(0x90,p,87),1):gsub(string.char(0x80,60,35),string.char(0x80,p,35),1)
  :gsub('NOTE 0 60','NOTE 0 '..p,1):gsub(string.char(0x91,67,94),string.char(0x91,q,94),1):gsub(string.char(0x91,67,0),string.char(0x91,q,0),1))
end
local function clefHarness(extra)
 local opts=extra or {};opts.trackNotes={[1]=notePair(36,43),[2]=notePair(72,79)}
 local a,s,r=harness(opts);s.streams[1]=pitched(36,43);s.streams[2]=pitched(72,79)
 return a,s,r
end
test('different visible tracks receive independent clefs with unchanged performance',function()
 local a,s,r=clefHarness({hidden=true,recreate=true})
 local originals={table.unpack(s.streams)};a.run()
 assert(s.writes==2 and s.chunkWrites==1 and s.undo==0)
 local _,chunk=r.GetTrackStateChunk(1);local _,clef=a.track_clef_chunk(chunk);assert(clef==2)
 for i=1,3 do assert(ordinary(s.streams[i])==ordinary(originals[i])) end
 assert(s.streams[3]==originals[3] and s.generation>0)
end)
test('clef still applies when AI offers no safe rhythm offsets',function()
 local a,s,r=clefHarness();s.files['/response.txt']='uncertain';a.run();assert(s.writes==0 and s.chunkWrites==1)
 local _,chunk=r.GetTrackStateChunk(1);local _,clef=a.track_clef_chunk(chunk);assert(clef==2)
end)
test('clef setter failure rolls back chunks and MIDI with recreated pointers',function()
 local a,s,r=clefHarness({chunkFailAt=1,recreate=true});local raw1,raw2=s.streams[1],s.streams[2]
 local _,chunk=r.GetTrackStateChunk(1)
 reject(a.run);assert(s.undo==0 and s.streams[1]==raw1 and s.streams[2]==raw2)
 local _,after=r.GetTrackStateChunk(1);assert(after==chunk and s.chunkWrites==2)
end)
test('hidden take corruption is detected and rolled back',function()
 local a,s,r=clefHarness({hidden=true,chunkCorrupt=true,recreate=true});local originals={table.unpack(s.streams)}
 reject(a.run);assert(s.undo==0)
 for i=1,3 do assert(s.streams[i]==originals[i]) end
end)
test('several visible takes on same track share one clef decision',function()
 local a,s,r=clefHarness({hidden=true});s.visible={1,3}
 local rows=a.selected();local targets=a.prepare_clefs(rows);assert(#targets==1 and #targets[1].notes==4)
end)
test('zoom repeats are absolute and do not accumulate',function()
 local a,s,r=harness();local rows=a.selected();a.apply_zoom(rows,50);local once=s.zoom;a.apply_zoom(rows,50)
 assert(once==81920 and s.zoom==once and s.writes==0 and not s.command)
end)
test('stored zoom factor is respected',function()
 local a,s=harness();s.zoomPercent='150';a.apply_zoom(a.selected(),50);assert(s.zoom==122880)
end)
test('seconds timebase uses tempo conversion',function()
 local a,s=harness({timebase=0,bpm=120});a.apply_zoom(a.selected(),50,100);assert(s.zoom==163840)
end)
test('dense bars get more horizontal space',function()
 local a,s=harness();local notes={};for i=1,28 do notes[i]=n(60,i/100) end
 local v,factor,base=a.zoom_value({{item=1,notes=notes}},50,100);assert(base==120 and v==122880)
end)
for _,factor in ipairs({0,49,251,math.huge}) do test('zoom factor limit '..tostring(factor),function()
 local a,s=harness();reject(function() a.apply_zoom(a.selected(),50,factor) end);assert(s.zoomSets==0)
end) end
test('zoom setting dialog persists factor and performs no API call',function()
 local a,s=harness({zoomInput='175'});a.zoom_dialog();assert(s.zoomPercent=='175' and s.zoom==143360 and s.writes==0 and not s.command)
end)
test('cancelled zoom dialog leaves view untouched',function()
 local a,s=harness({zoomCancel=true});a.zoom_dialog();assert(s.zoomSets==0 and not s.zoomPercent and not s.command)
end)
test('zoom readback failure restores original scale',function()
 local a,s,r=harness();local read=r.MIDIEditor_GetSetting_int
 r.MIDIEditor_GetSetting_int=function(ed,key) if key=='pixels_per_timebase_unit' and s.zoomSets==1 then return -1 end;return read(ed,key) end
 reject(function() a.apply_zoom(a.selected(),50,150) end);assert(s.zoom==81920)
end)
test('clefs and rhythm share simulated Undo/Redo block with item and track flags',function()
 local a,s,r=clefHarness();a.run();assert(s.undoFlags==5)
 local changedStreams,changedChunks={table.unpack(s.streams)},{table.unpack(s.chunks)}
 s.streams=s.snapshot;s.chunks=s.snapshotChunks
 local _,chunk=r.GetTrackStateChunk(1);local _,clef=a.track_clef_chunk(chunk);assert(clef==1 and s.streams[1]==pitched(36,43))
 s.streams=changedStreams;s.chunks=changedChunks
 local _,after=r.GetTrackStateChunk(1);local _,restored=a.track_clef_chunk(after);assert(restored==2)
end)
test('non-MIDI track change during analysis invalidates the whole result',function()
 local a,s,r=clefHarness({live=true});a.run()
 local _,before=r.GetTrackStateChunk(1);s.chunks[1]=before:gsub('Untouched name','changed name')
 finish(a,s,'0',response(good));assert(s.writes==0 and s.chunkWrites==0 and #s.messages>0)
end)
test('zoom setter failure that changes the scale is restored',function()
 local a,s,r=harness();local set=r.MIDIEditor_SetSetting_int
 r.MIDIEditor_SetSetting_int=function(ed,key,value) set(ed,key,value);return s.zoomSets~=1 end
 reject(function() a.apply_zoom(a.selected(),50,150) end);assert(s.zoom==81920 and s.zoomSets==2)
end)
test('companion zoom action loads the actual main file in module mode with no AI',function()
 local a,s,r,env=harness({zoomInput='125'})
 assert(loadfile('Native-Notation-Studio-Zoom.lua','t',env))()
 assert(s.zoomPercent=='125' and s.zoom==102400 and s.writes==0 and not s.command and #s.messages==0)
end)
test('ordinary unique POOLEDEVTS identities are not shared pools',function()
 local a,s=harness({uniquePools=true});a.run();assert(s.writes==2)
end)
test('only documented native chunk normalization is accepted',function()
 local before='<TRACK\nNAME "same"\nVU 64\n>\n'
 local patched=api.track_clef_chunk(before,2)
 local native='<TRACK\nNAME "same"\nLANEREC -1 -1 -1 0\nVU 64\nSCORE 0 2 0 0\n>\n'
 assert(api.track_equivalent(patched,native))
 assert(not api.track_equivalent(patched,native:gsub('NAME "same"','NAME "changed"')))
 assert(not api.track_equivalent(patched,native:gsub('SCORE 0 2','SCORE 6 2')))
 assert(not api.track_equivalent(patched,native:gsub('LANEREC %-1 %-1 %-1 0','LANEREC 1 2 3 4')))
end)
test('rollback of an implicit default explicitly restores clef zero',function()
 local before='<TRACK\nNAME "same"\n>\n'
 local restored=api.track_clef_chunk(before,0,true)
 assert(restored:find('SCORE 0 0 0 0',1,true) and api.track_equivalent(before,restored))
end)
test('pure zoom works for pooled/repeating/stretched sources without analysis or MIDI writes',function()
 local a,s=harness({pool=true,loop=true,sourceLength=2,rate=0.5});a.zoom_dialog()
 assert(s.zoomPercent=='150' and s.writes==0 and not s.command)
end)
print(('PASS %d standalone tests; no live API traffic'):format(checks))
