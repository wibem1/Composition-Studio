"""Complete-track workflow: real production coordination, durable recovery, bounded calls."""
import copy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from lupa.lua54 import LuaRuntime
from build_studio import inline, load_manifest

units = {u['id']: u for u in load_manifest()['units']}
def unit(name): return inline(units[name])
HEADER = r'''
local EXT_SECTION="test";local TITLE_KEY="title";local VERSION="dev"
local provider="openai";local model="fixture";local reasoning_mode="auto"
local busy=false;local update_status="";local input="";local info_visible=false;local history_mode=false
local last_diag={};local last_made={};local swam_last_made={};local work_title=""
local messages={};local calls={};local writes=0;local committed=""
local project=1;local chunk="ORIGINAL";local saved={[1]={},[2]={}}
local response=nil;local response_error=nil
local source_items={{guid="item1",track_guid="track1",track_name="Piano",track=1,take=1,
 start_qn=0,end_qn=4,notes={{start_qn=0,duration_qn=1.125,pitch=60,velocity=80,channel=0}}}}
local launch
local costs={begin=function()end,rate=function()return {2,10} end}
local function add(_,text)messages[#messages+1]=text end
local function diag_set(key,value)last_diag[key]=value end
local function read_file(path)local f=io.open(path,"rb");if not f then return nil end;local text=f:read("*a");f:close();return text end
local function write_file(path,text)local f=io.open(path,"wb");if not f then return false end;f:write(text);f:close();return true end
local function item_guid(item)return item=="created-item" and "created" or "item1" end
local function track_guid()return "track1" end
local function get_key()return "FIXTURE-KEY" end
local function selected_items()return source_items end
local function selected_tracks()return {} end
local function track_context_items()return source_items end
local function score_context_tracks()return {{guid="track1",track=1,name="Piano"}} end
local function score_request_intent()return false end
local function editor_reference_excerpt()return "READ ONLY REFERENCE" end
local function initialize_halion_project()end
local function reasoning_parameters()return "","provider_default" end
local function music_context()return "SOURCE NOTES" end
local function apply_composition(text)
 assert(not text:find("CSMETA|",1,true),"Song changed global map")
 for line in text:gmatch("[^\r\n]+")do assert(line:match("^CS|new|%-|") or line:match("^CSCTRL|"),line)end
 writes=writes+1;committed=text;return {"created-item"}
end
reaper={GetExtState=function()return "" end,
 GetProjExtState=function(_,_,key)return 1,saved[project][key] or "" end,
 SetProjExtState=function(_,_,key,value)saved[project][key]=value;return 1 end,
 GetResourcePath=function()return TEST_ROOT end,RecursiveCreateDirectory=function(path)MAKE_DIR(path)end,
 genGuid=function()return "{PROJECT-"..project.."}" end,
 CountTracks=function()return 1 end,GetTrack=function()return 1 end,GetTrackName=function()return true,"Piano" end,
 CountTrackMediaItems=function()return 1 end,GetTrackMediaItem=function()return 1 end,
 GetItemStateChunk=function()return true,chunk end,Master_GetTempo=function()return 120 end,
 CountTempoTimeSigMarkers=function()return 0 end,TimeMap_GetTimeSigAtTime=function()return 4,4 end,
 CountMediaItems=function()return 1 end,GetMediaItem=function()return 1 end,
 GetActiveTake=function()return 1 end,GetMediaItem_Track=function()return 1 end,
 EnumProjects=function()return project end,TimeMap2_timeToQN=function(_,value)return value end,
 SetExtState=function()end}
'''

def setup(directory):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_ROOT=directory
    lua.globals().MAKE_DIR=lambda p: Path(p).mkdir(parents=True,exist_ok=True)
    code=HEADER
    for name in ['shared/workflow','core/text','music/cs_notes','music/programs','music/json_codec','music/json_score','music/continuation_request','music/json_direct_prompt','music/model','music/memory','music/whole_track']:
        code+=unit(name)
    code+='local function analysis_prompt(r)return r end;local function composition_prompt(r)return r end\n'
    code+=unit('ai/request_state')+unit('ai/requests')
    code+='''
ai_command=function(prompt,key,limit)
 assert(key=="FIXTURE-KEY")
 calls[#calls+1]={prompt=prompt,limit=limit};return {},nil
end
ai_poll=function()return response,response_error,true end
'''
    code+=unit('workflow/proposals')+unit('workflow/apply_review')+unit('workflow/music_workspace')+unit('workflow/whole_track')+unit('workflow/router')+unit('workflow/jobs')
    code+='''
return {submit=function(text)input=text;submit()end,
 complete=function(text,error_text,usd)response=text;response_error=error_text;last_diag.usage_estimated_usd=usd;poll_job()end,
 calls=calls,messages=messages,workflow=workflow_adapter,track=whole_track,plan=track_plan,
 writes=function()return writes end,committed=function()return committed end,busy=function()return busy end,
 source=function(value)source_items=value end,mutate=function()chunk="CHANGED"end,
 switch=function(value)project=value end,cancel=whole_track.cancel,
 decode=decode_engine_json,encode=workflow_adapter.encode}
'''
    return lua,lua.execute(code)

def table(lua,v):
    if isinstance(v,dict):return lua.table_from({k:table(lua,x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(lua,x) for x in v])
    return v

def failure(fn,*args):
    try:fn(*args)
    except Exception:return
    raise AssertionError('Invalid data accepted')

def fixture(api,lua,duration=143.364):
    notes=[{'start_qn':1+i,'duration_qn':min(1.125,duration-i),'pitch':60,'velocity':80,'channel':0} for i in range(int(duration))]
    api.source(table(lua,[{'guid':'item1','track_guid':'track1','track_name':'Piano','track':1,'take':1,'start_qn':1,'end_qn':1+duration,'notes':notes}]))

PLAN={'schema':'Composition-TrackPlan-1','title':'Techno','idea':'Source motif develops across the entire work.',
 'tracks':[{'name':name,'program':pg,'channel':ch,'role':role} for name,pg,ch,role in [('Synth',80,0,'motif'),('Bass',38,1,'bass'),('Drums',0,9,'drums')]],
 'sections':[{'name':'Development','start_qn':0,'end_qn':143.364,'direction':'Develop the source theme and transition continuously.'}]}

def window(index,duration=143.364):
    start=index*16;end=min(duration,start+16)
    return {'schema':'Composition-TrackWindow-1','start_qn':start,'end_qn':end,'bpm':120,'timeSignature':[4,4],
     'continuity':'Keep the source motif and harmonic direction into the next window.',
     'tracks':[dict(t,notes=[[start,1,60,80],[end-0.25,0.25,64,75]],ccEvents=[]) for t in PLAN['tracks']]}

def complete(api,value=None,error=None,usd='0.01'):
    api.complete(json.dumps(value) if value is not None else None,error,usd)

def messages(api):return '\n'.join(api.messages.values())

with TemporaryDirectory() as directory:
    lua,api=setup(directory);fixture(api,lua)
    api.submit('Ganzer Track: Erstelle eine Techno-Version mit Synthie, Bass und Drums.')
    assert len(api.calls)==0 and 'höchstens 10 KI-Aufrufe' in messages(api)
    checkpoint=api.track.load();assert checkpoint.snapshot.bounds.end_qn==144.364
    assert checkpoint.snapshot.bounds.start_qn==1
    assert 'FIXTURE-KEY' not in Path(api.track.path()).read_text()
    api.submit('Track-Aufbau starten: 0.001 USD');assert len(api.calls)==0
    api.submit('Track-Aufbau starten: 2 USD');assert len(api.calls)==1 and api.calls[1].limit==2048
    complete(api,PLAN);assert len(api.calls)==2 and api.calls[2].limit==8192
    assert api.writes()==0 and api.workflow.pending is None
    complete(api,window(0));complete(api,window(1))
    assert len(api.track.load().results)==2 and len(api.calls)==4
    complete(api,error='MAX_TOKENS: partial response')
    assert not api.busy() and len(api.calls)==4 and api.writes()==0
    assert len(api.track.load().results)==2
    api.submit('Track-Aufbau fortsetzen');assert len(api.calls)==4
    api.submit('Track-Aufbau starten: 2 USD');assert len(api.calls)==5
    assert '"start_qn":32' in api.calls[5].prompt
    assert 'VORHERIGE ÜBERGABE' in api.calls[5].prompt and 'VORHERIGE AUSKLINGENDE NOTEN' in api.calls[5].prompt
    for i in range(2,9):complete(api,window(i))
    assert not api.busy() and api.writes()==0 and api.workflow.pending.stage=='whole_track'
    record=api.workflow.pending
    score=json.loads(record.raw_response)
    assert len(score['tracks'])==3 and score['sections'][-1]['end_qn']==143.364
    for tr in score['tracks']:
        assert tr['notes'][0][0]==0 and abs(tr['notes'][-1][0]+tr['notes'][-1][1]-143.364)<1e-6
    api.workflow.load()
    saved=api.workflow.records[1];api.workflow.pending=saved
    api.workflow.apply();assert api.writes()==1 and saved.state=='applied'
    assert '1.000000,1.000000,60' in api.committed() and 'CSMETA|' not in api.committed()
    api.workflow.apply();assert api.writes()==1
    api.submit('Track-Aufbau starten: 2 USD');assert len(api.workflow.records)==1 and api.writes()==1
    # Entire track survived a late fault; only the failed window was explicitly restarted.
    assert len(api.calls)==11
    snapshot=checkpoint.snapshot;windows,duration=api.plan.windows(snapshot)
    valid=table(lua,PLAN)
    for change in ['short','gap','program','duplicate']:
        bad=copy.deepcopy(PLAN)
        if change=='short':bad['sections'][0]['end_qn']=128
        elif change=='gap':bad['sections'][0]['start_qn']=1
        elif change=='program':bad['tracks'][0]['program']=128
        else:bad['tracks'][1]['name']='Synth'
        failure(api.plan.validate,table(lua,bad),duration)
    for change in ['wrong_window','pitch','negative','instrument','open_pedal','outside_cc','empty','nan']:
        bad=window(0)
        if change=='wrong_window':bad['end_qn']=8
        elif change=='pitch':bad['tracks'][0]['notes'][0][2]=128
        elif change=='negative':bad['tracks'][0]['notes'][0][1]=-1
        elif change=='instrument':bad['tracks'][0]['channel']=2
        elif change=='open_pedal':bad['tracks'][0]['ccEvents']=[{'at':0,'controller':64,'value':127}]
        elif change=='outside_cc':bad['tracks'][0]['ccEvents']=[{'at':16,'controller':11,'value':80}]
        elif change=='empty':bad['tracks']=[]
        else:bad['tracks'][0]['notes'][0][0]=float('nan')
        failure(api.plan.validate_window,table(lua,bad),windows[1],valid,snapshot,duration)
    silent=window(0);silent['tracks']=[];silent['rest']=True
    api.plan.validate_window(table(lua,silent),windows[1],valid,snapshot,duration)
    sustained=window(0);sustained['tracks'][0]['notes'][0][1]=20
    api.plan.validate_window(table(lua,sustained),windows[1],valid,snapshot,duration)
    failure(api.plan.assemble,valid,table(lua,[window(0)]),windows,snapshot)

# Budget stops before the next call, and unknown usage saves valid work but halts.
for mode in ['budget','unknown','stale','project','cancel']:
    with TemporaryDirectory() as directory:
        lua,api=setup(directory);fixture(api,lua)
        api.submit('Ganzer Track: Techno mit Synthie, Bass und Drums')
        api.submit('Track-Aufbau starten: '+('0.08 USD' if mode=='budget' else '2 USD'))
        assert len(api.calls)==1
        if mode=='stale':api.mutate()
        elif mode=='project':api.switch(2)
        elif mode=='cancel':api.cancel()
        complete(api,PLAN,usd='' if mode=='unknown' else '0.01')
        assert len(api.calls)==1 and not api.busy() and api.writes()==0
        if mode in ['budget','unknown']:assert api.track.load().plan is not None
        if mode=='cancel':assert api.track.load().inflight
# A fresh Lua session reloads saved partial results; successful work is not regenerated.
with TemporaryDirectory() as directory:
    lua,api=setup(directory);fixture(api,lua,32)
    plan=copy.deepcopy(PLAN);plan['sections'][0]['end_qn']=32
    api.submit('Ganzer Track: Techno mit drei Stimmen');api.submit('Track-Aufbau starten: 2 USD')
    complete(api,plan);complete(api,window(0,32));complete(api,error='transport failure')
    assert len(api.track.load().results)==1
    lua,api=setup(directory);fixture(api,lua,32)
    api.submit('Track-Aufbau fortsetzen');assert len(api.calls)==0
    api.submit('Track-Aufbau starten: 2 USD');assert len(api.calls)==1 and '"start_qn":16' in api.calls[1].prompt
    complete(api,window(1,32));assert api.workflow.pending.stage=='whole_track'
    api.mutate();api.workflow.apply();assert api.writes()==0
    Path(api.track.path()).write_text('corrupt checkpoint')
    api.submit('Track-Aufbau fortsetzen');assert len(api.calls)==1

print('PASS complete fractional 36-bar track, shared plan/tails, cost preview and budget, durable partial recovery, no retries/partial commit, reload/apply once, source/project/cancel guards and MIDI contracts')
