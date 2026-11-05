"""Actual musical model, memory, routing, async response and guarded proposal flow."""
import copy
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from lupa.lua54 import LuaRuntime
from build_studio import ROOT, inline, load_manifest

units = {unit['id']: unit for unit in load_manifest()['units']}


def unit(name):
    return inline(units[name])


def must_fail(function, *arguments):
    try:
        function(*arguments)
    except Exception:
        return
    raise AssertionError('Invalid data accepted')


with TemporaryDirectory() as temporary:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_ROOT = temporary
    lua.globals().MAKE_DIR = lambda path: Path(path).mkdir(parents=True, exist_ok=True)
    header = '''
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
local costs={begin=function()end}
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
 for line in text:gmatch("[^\\r\\n]+")do assert(line:match("^CS|new|%-|") or line:match("^CSCTRL|"),line)end
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
    modules = ['shared/workflow', 'core/text', 'music/cs_notes', 'music/programs',
               'music/json_codec', 'music/json_score', 'music/continuation_request',
               'music/json_direct_prompt', 'music/model', 'music/memory']
    code = header + ''.join(unit(name) for name in modules)
    code += '''
local function analysis_prompt(request)return request.."\\nSOURCE NOTES" end
local function composition_prompt(request)return request end
'''
    code += unit('ai/request_state') + unit('ai/requests')
    # The real launch and poll_job run; only the provider boundary is replaced.
    code += '''
ai_command=function(prompt,key)
 calls[#calls+1]={prompt=prompt,key=key};return {},nil
end
ai_poll=function()return response,response_error,true end
'''
    code += unit('workflow/proposals') + unit('workflow/apply_review')
    code += unit('workflow/music_workspace') + unit('workflow/router') + unit('workflow/jobs')
    code += '''
return {
 model=music_model,memory=music_memory,workspace=music_workspace,workflow=workflow_adapter,
 submit=function(text)input=text;submit()end,
 complete=function(text,error_text)response=text;response_error=error_text;poll_job()end,
 calls=function()return #calls end,prompt=function()return calls[#calls] and calls[#calls].prompt end,
 writes=function()return writes end,committed=function()return committed end,
 busy=function()return busy end,messages=messages,
 mutate=function(value)chunk=value end,switch=function(value)project=value end,
 reload=function()return workflow_adapter.load()end,
 corrupt=function(value)saved[project].MusicMemoryV1=value end,
 source=function(value)source_items=value end,
 records=function()return workflow_adapter.encode(workflow_adapter.records)end,
 stored=function()return saved[project].MusicMemoryV1 end}
'''
    api = lua.execute(code)

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(item) for item in value])
        return value

    # Pure model keeps expressive timing and strips native handles.
    source = [{'guid': 'item1', 'track_guid': 'track1', 'track_name': 'Piano', 'item': 'NATIVE-HANDLE',
               'notes': [{'start_qn': 1.01, 'duration_qn': 0.937, 'pitch': 60, 'velocity': 80, 'channel': 0}]}]
    assert api.workspace.request_kind('Analysiere die Komposition') is None
    assert api.workspace.request_kind('Zeige den Song') is None
    snapshot = api.model.capture(table(source), 120, 4, 4)
    assert snapshot.parts[1].events[1].at == 1.01
    assert snapshot.parts[1].events[1].duration == 0.937
    assert snapshot.parts[1].events[1].source_item == 'item1'
    assert snapshot.parts[1]['item'] is None
    must_fail(api.model.capture, table([]), 120, 4, 4)
    oversized = copy.deepcopy(source)
    oversized[0]['notes'] *= 2501
    must_fail(api.model.capture, table(oversized), 120, 4, 4)
    memory = api.memory.empty()
    remembered = api.memory.append(memory, 'Die Begleitung bleibt schlicht.')
    assert len(memory.decisions) == 0 and len(remembered.decisions) == 1
    must_fail(api.memory.append, memory, 'x' * 601)
    must_fail(api.memory.validate, table({'schema': 'unknown', 'decisions': []}))
    encoded_overflow = {'schema': 'Composition-Memory-1',
                        'decisions': [{'id': i + 1, 'text': '\n' * 599 + 'a'} for i in range(24)]}
    must_fail(api.workspace.store_memory, table(encoded_overflow))
    assert api.stored() is None
    print('PASS pure performance model and bounded copy-on-write musical memory')

    api.submit('Merke musikalisch: Die Begleitung bleibt schlicht.')
    assert api.calls() == 0 and api.writes() == 0 and not api.busy()
    assert 'Die Begleitung bleibt schlicht.' in api.stored()
    api.submit('Zeige Musikgedächtnis')
    assert 'schlicht' in api.messages[len(api.messages)]
    api.switch(2)
    api.submit('Zeige Musikgedächtnis')
    assert 'Noch keine' in api.messages[len(api.messages)]
    api.switch(1)
    api.submit('Analysiere den Werkzusammenhang')
    assert api.calls() == 1 and api.busy()
    assert 'Composition-Music-1' in api.prompt() and 'schlicht' in api.prompt()
    api.complete('Beobachtung: zwei Gesten. Interpretation: mögliche Motivbeziehung. Vorschlag: Anfang bewahren.')
    assert api.workflow.analysis.stage == 'analysis' and api.writes() == 0
    assert api.reload() and len(api.workflow.records) == 1
    print('PASS local commands, project isolation, memory injection and persistent read-only work analysis')

    song = {'schema': 'Composition-Song-1', 'title': 'Gestalt', 'bpm': 120, 'timeSignature': [4, 4],
            'tracks': [{'name': 'Piano', 'role': 'Motivträger', 'program': 0, 'channel': 0,
                        'notes': [[0, 1.125, 60, 80], [4, 1, 64, 85], [7, 1, 60, 70]],
                        'ccEvents': [{'at': 0, 'controller': 11, 'value': 80}]}],
            'sections': [{'id': 'a', 'name': 'Gedanke', 'start_qn': 0, 'end_qn': 4},
                         {'id': 'b', 'name': 'Antwort', 'start_qn': 4, 'end_qn': 8, 'purpose': 'Rückbezug'}],
            'relationships': [{'from': 'a', 'to': 'b', 'description': 'Motiv wird beantwortet'}]}
    for mutate in [lambda s: s.update(bpm=90), lambda s: s.update(tempoEvents=[{'at': 0, 'bpm': 90}]),
                   lambda s: s['sections'][1].update(start_qn=5),
                   lambda s: s['relationships'][0].update(to='unknown'),
                   lambda s: s['tracks'][0]['notes'][0].__setitem__(2, 128),
                   lambda s: s['tracks'].append(copy.deepcopy(s['tracks'][0])),
                   lambda s: s.update(pedalEvents=[{'at': 0, 'value': 127}]),
                   lambda s: s['tracks'][0]['ccEvents'][0].update(at=9000),
                   lambda s: s['tracks'][0].update(pitchBend=[[0, 100]]),
                   lambda s: s['tracks'][0].update(ccEvents=[{'at': 0, 'controller': '64', 'value': 127}])]:
        invalid = copy.deepcopy(song)
        mutate(invalid)
        cs, error = api.workspace.song_to_cs(json.dumps(invalid), snapshot)
        assert cs is None and error
    api.submit('Entwickle die Auswahl zu einem vollständigen Song')
    assert api.calls() == 2 and api.writes() == 0
    assert 'schlicht' in api.prompt() and 'Composition-Song-1' in api.prompt()
    api.complete(json.dumps(song))
    proposal = api.workflow.pending
    assert proposal.stage == 'song_construction' and proposal.state == 'ready'
    assert 'Antwort' in proposal.song_summary and proposal.music_snapshot.representation == 'performance'
    assert 'schlicht' in proposal.music_memory_context
    assert 'FIXTURE-KEY' not in api.records() and 'NATIVE-HANDLE' not in api.records()
    assert api.writes() == 0
    assert api.reload()
    api.workflow.pending = api.workflow.records[2]
    api.mutate('EXTERNAL CHANGE')
    api.workflow.apply()
    assert api.writes() == 0 and api.workflow.pending.state == 'ready'
    api.mutate('ORIGINAL')
    api.workflow.apply()
    assert api.writes() == 1 and api.workflow.records[2].state == 'applied'
    assert 'CSMETA|' not in api.committed() and 'CS|new|-|Piano|' in api.committed()
    assert 'CSCTRL|Piano|' in api.committed()
    api.workflow.apply()
    assert api.writes() == 1
    assert api.reload() and api.workflow.records[2].state == 'applied'
    assert api.workflow.records[2].music_snapshot.schema == 'Composition-Music-1'
    print('PASS song validation, durable proposal/reload, stale-source block, explicit apply once and preserved project map')

    before = len(api.workflow.records)
    api.submit('Baue einen Song aus der Auswahl')
    api.complete('{"schema":"unknown"}')
    assert len(api.workflow.records) == before and api.workflow.pending is None and not api.busy()
    api.submit('Baue einen Song aus der Auswahl')
    api.complete(None, 'Provider error')
    assert len(api.workflow.records) == before and api.writes() == 1
    api.submit('Baue einen Song aus der Auswahl')
    api.switch(2)
    api.complete(json.dumps(song))
    assert api.writes() == 1 and not api.busy()
    api.switch(1)
    api.corrupt('{broken')
    before_calls = api.calls()
    api.submit('Baue einen Song aus der Auswahl')
    assert api.calls() == before_calls and not api.busy()
    api.submit('Lösche Musikgedächtnis')
    assert api.calls() == before_calls and api.writes() == 1
    assert len(json.loads(api.stored())['decisions']) == 0
    api.source(table([]))
    api.submit('Entwickle die markierten Noten zu einem Song')
    assert api.calls() == before_calls and not api.busy()
    api.submit('Baue einen Song aus den ausgewählten Arrangement-Items')
    assert api.calls() == before_calls and not api.busy()
    print('PASS invalid/provider/project-switch/corrupt-memory/missing-selection failures without partial MIDI writes or retries')
