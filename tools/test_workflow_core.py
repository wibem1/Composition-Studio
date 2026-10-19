"""Run actual embedded core and host adapter with deterministic REAPER substitutes."""
from pathlib import Path
import tempfile
from lupa.lua54 import LuaRuntime
s=(Path(__file__).resolve().parents[1]/'Composition Studio.lua').read_text()
def section(a,b):return s[s.index(a):s.index(b)]
temp=tempfile.TemporaryDirectory()
r=LuaRuntime(unpack_returned_tuples=True)
r.globals().TEST_ROOT=temp.name
module=section('-- BEGIN SHARED WORKFLOW CORE','-- END SHARED WORKFLOW CORE')
decoder=section('local function decode_engine_json(src)','local function engine_translate_json(answer)')
adapter=section('-- Host adapter:','-- End shared workflow host adapter.')
api=r.execute(module+decoder+'''
local saved={},nil
local chunk="ORIGINAL"; local write_count=0; local EXT_SECTION="test"
local MODELS={openai={},anthropic={},google={}}
local busy=false; local update_status=""; local provider="openai";local model="test";local input=""
local function read_file(p) local f=io.open(p,"rb");if not f then return nil end;local s=f:read("*a");f:close();return s end
local function write_file(p,s) local f=io.open(p,"wb");if not f then return false end;f:write(s);f:close();return true end
local reaper={GetExtState=function()return "" end,GetResourcePath=function()return TEST_ROOT end,GetProjectGUID=function()return "TEST-PROJECT" end,RecursiveCreateDirectory=function(p)os.execute("mkdir -p '"..p.."'") end,CountTracks=function() return 1 end,GetTrack=function()return 1 end,GetTrackName=function()return true,"Piano" end,
 CountTrackMediaItems=function()return 1 end,GetTrackMediaItem=function()return 1 end,GetItemStateChunk=function()return true,chunk end,
 Master_GetTempo=function()return 120 end,CountTempoTimeSigMarkers=function()return 0 end,
 SetProjExtState=function(_,_,k,v)saved[k]=v end,GetProjExtState=function(_,_,k)return 1,saved[k] or "" end,
 CountMediaItems=function()return 1 end,GetMediaItem=function()return 1 end,GetActiveTake=function()return 1 end,
 GetMediaItem_Track=function()return 1 end,TimeMap2_QNToTime=function(_,q)return q end,
 TimeMap_GetTimeSigAtTime=function()return 4,4 end,TimeMap_QNToMeasures=function(_,q)local i=math.floor(q/4);return i,i*4,(i+1)*4 end,MIDI_CountEvts=function()return true,1,0,0 end}
local function track_guid() return "track1" end
local function item_guid() return "item1" end
local function add() end
local function diag_set() end
local function safe_work_title(x)return x end
local function initialize_halion_project()return 0,0 end
local TITLE_KEY="title"
local function trim(x)return x end
local function get_key()return "SECRET" end
local function composition_prompt()return "HOST FORMAT" end
local function track_context_items()return {{guid="item1",track=1,notes={}}} end
local launched=nil
local function launch(stage,prompt,key,data)launched={stage=stage,prompt=prompt,key=key,data=data} end
local function engine_translate_json(x) return "CS|new|-|Piano|0|0,1,60,80,0" end
local function lily_compile_import()write_count=write_count+1;chunk="CHANGED";return 1 end
local function apply_composition()write_count=write_count+1;chunk="CHANGED";return {1} end
local workflow_adapter_guard
'''+adapter+'''
return {a=workflow_adapter,mutate=function()chunk="EXTERNAL" end,original=function()chunk="ORIGINAL" end,
 writes=function()return write_count end,stored=function()return saved.WorkflowHistoryV1 end,
 launch=function()return launched end,set_busy=function(x)busy=x end}
''')
a=api.a
data=r.table_from({'request':'Variation','full':r.table_from([r.table_from({'guid':'item1','track':1})]),'music_tracks':r.table_from([r.table_from({'guid':'track1','track':1})])})
a.offer('engine_json','{"title":"Test"}',data)
assert api.writes()==0 and a.pending.state=='ready'
assert 'SECRET' not in api.stored() and 'ORIGINAL' in api.stored()
api.mutate();a.apply();assert api.writes()==0
api.original();a.apply();assert api.writes()==1 and a.records[1].state=='applied'
a.apply();assert api.writes()==1
api.original();a.offer('analysis',r'E5 $\rightarrow$ D5',data)
a.load();assert len(a.records)==2
# Loading a saved analysis does not invoke a provider.
a.analysis=a.records[2];assert api.launch() is None
a.review();assert api.launch().stage=='composition' and 'ANALYSE' in api.launch().prompt
assert a.transition(r.table(),32,2)==24
items=r.table_from([r.table_from({'take':1,'notes':r.table_from([r.table_from({'start_qn':23,'duration_qn':2})])})])
try:a.transition(items,32,2);raise AssertionError('Crossing note accepted')
except Exception as e:assert 'überspannt' in str(e)
api.set_busy(False);a.load();a.pending=a.records[1];api.original();a.apply();assert api.writes()==1
print('PASS REAPER: preview without write, exact original guard, durable raw/source, apply once, reload, analysis→revision, model call only on review, transition boundary')

# Catalog selection is discovered from provider data; future model IDs are accepted.
def table(v):
 if isinstance(v,dict):return r.table_from({k:table(x) for k,x in v.items()})
 if isinstance(v,list):return r.table_from([table(x) for x in v])
 return v
rows,token=a.models.parse('google',table({'models':[{'name':'models/gemini-future','displayName':'Future','supportedGenerationMethods':['generateContent']},{'name':'models/embed','supportedGenerationMethods':['embedContent']}],'nextPageToken':'NEXT'}))
assert len(rows)==1 and rows[1][2]=='gemini-future' and token=='NEXT'
rows,token=a.models.parse('anthropic',table({'data':[{'id':'claude-future','display_name':'Future'}],'has_more':True,'last_id':'claude-future'}))
assert rows[1][2]=='claude-future' and token=='claude-future'
rows,token=a.models.parse('openai',table({'data':[{'id':'gpt-future'},{'id':'text-embedding-future'},{'id':'gpt-audio-future'}]}))
assert len(rows)==1 and rows[1][2]=='gpt-future' and token is None
print('PASS model catalogs: future IDs, Google capability filtering, OpenAI non-text filter, Anthropic/Google pagination')

import json
translator=r.execute(decoder+section('local function engine_translate_json(answer)','local function lily_composition_prompt(request)')+'\nreturn engine_translate_json')
score={'bpm':100,'timeSignature':[4,4],'tempoEvents':[{'at':8,'bpm':80}],'tracks':[{'name':'Piano','program':0,'channel':0,'notes':[[0,1,60,80]],'ccEvents':[{'at':0,'controller':64,'value':127},{'at':1,'controller':64,'value':0}]}]}
cs=translator(json.dumps(score))
assert 'CSCTRL|Piano|0.000000|0|cc|64|127' in cs and 'CSMETA|tempo|8.000000|80.000000' in cs
score['tracks'][0]['ccEvents'][0]['value']=128
assert translator(json.dumps(score))[0] is None
print('PASS actual JSON translator: tempo events and per-track Sustain, invalid controller rejected')
