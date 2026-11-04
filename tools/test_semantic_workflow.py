"""Production request -> mocked provider reply -> parser -> real JSON save/reload.
No provider traffic. Missing host mutation APIs fail immediately.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
import json
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Composition Studio.lua').read_text()
def section(a, b):
    return source[source.index(a):source.index(b)]

with TemporaryDirectory() as folder:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = folder
    api = lua.execute(section('-- BEGIN SHARED WORKFLOW CORE', '-- END SHARED WORKFLOW CORE') +
        section('local function decode_engine_json(src)', 'local function engine_translate_json(answer)') + r'''
local EXT_SECTION,provider,model="test","google","fixture-model"
local busy,input,update_status=true,"",""
local MODELS={openai={},anthropic={},google={}}
local saved,messages,diagnostics={},{},{}
local chunk="NOTE-ON/OFF; VELOCITY; CHANNEL; CC64; TEXT; NOTATION; TEMPO ORIGINAL"
local calls,job,response=0,nil,nil
local selected=false
local items={{guid="{TEST}",track=1,score_context=true,notes={
 {start_qn=0.125,duration_qn=0.5,pitch=69,velocity=90,channel=0},
 {start_qn=4.02,duration_qn=0.48,pitch=48,velocity=70,channel=1},
 {start_qn=8,duration_qn=0.25,pitch=64,velocity=75,channel=1}}}}
local tracks={{guid="track1",track=1}}
local reaper=setmetatable({
 GetResourcePath=function()return ROOT end,
 RecursiveCreateDirectory=function(p)os.execute("mkdir -p '"..p.."'")end,
 GetProjExtState=function(_,_,k)return 1,saved[k] or "" end,
 SetProjExtState=function(_,_,k,v)saved[k]=v end,
 GetExtState=function()return "" end,genGuid=function()return "{TEST}" end,
 CountTracks=function()return 1 end,GetTrack=function()return 1 end,
 GetTrackName=function()return true,"Piano" end,
 CountTrackMediaItems=function()return 1 end,GetTrackMediaItem=function()return 1 end,
 GetItemStateChunk=function()return true,chunk end,Master_GetTempo=function()return 96 end,
 CountTempoTimeSigMarkers=function()return 0 end,EnumProjects=function()return 1 end,
 TimeMap_QNToMeasures=function(_,q)local n=math.floor(q/4);return n,4*n,4*(n+1)end,
 TimeMap2_QNToTime=function(_,q)return q end,
 TimeMap_GetTimeSigAtTime=function()return 4,4 end
},{__index=function(_,key)error("Unexpected host API: "..key)end})
local function read_file(p)local f=io.open(p,"rb");if not f then return end;local t=f:read("*a");f:close();return t end
local fail_write=false
local function write_file(p,t)if fail_write then return false end;local f=assert(io.open(p,"wb"));f:write(t);f:close();return true end
local function track_guid()return "track1"end
local function item_guid()return "{TEST}"end
local function trim(s)return (s or ""):gsub("^%s+",""):gsub("%s+$","")end
local function add(_,s)messages[#messages+1]=s end
local function diag_set(k,v)diagnostics[k]=v end
local function compact_context()return "Tempo 96"end
local function music_context(rows)
 local out={}
 for _,it in ipairs(rows)do for _,n in ipairs(it.notes)do out[#out+1]=string.format("N %s %.9f %.9f %d %d %d",it.guid,n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel)end end
 return table.concat(out,"\n")
end
local function notation_selection_items()
 if selected then return {{guid="{TEST}",track=1,notes={items[1].notes[1]},selection_source={{index=0,start_ppq=120,end_ppq=600,pitch=69,velocity=90,channel=0}}}},1 end
 return {},0
end
local function editor_reference_excerpt()return "READ_ONLY_REFERENCE: other notes are context only"end
local function score_request_intent()return true end
local function notation_visible_items()return items end
local function score_context_tracks()return tracks end
local function get_key()return "FIXTURE-KEY"end
local function log_communication()end
local last_diag={}
local function ai_poll()return response,nil,true end
local workflow_adapter_guard
local function launch(stage,prompt,key,data)
 calls=calls+1;job={stage=stage,data=data,key=key,project=1,prompt=prompt}
end
''' + section('local function parse_semnotes(', 'local function composition_prompt(') +
        section('-- Host adapter:', '-- End shared workflow host adapter.') +
        section('local function begin_process(', 'local function title_prompt(') +
        section('local function poll_job()', 'local function submit()') + r'''
return {a=workflow_adapter,begin=begin_process,poll=function(text)response=text;poll_job()end,
 select=function(v)selected=v end,job=function()return job end,calls=function()return calls end,chunk=function()return chunk end,
 mutate=function()chunk="EXTERNAL CHANGE"end,status=function()return update_status end,
 messages=messages,fail_write=function()fail_write=true end}
''')
    a = api.a
    assert a.load()
    original = api.chunk()
    api.begin('Analysiere die sichtbare Partitur für eine lesbare Notation')
    assert api.calls() == 1 and api.job().stage == 'analysis'
    prompt = api.job().prompt
    assert 'BAR|1|0.000000000|4.000000000|4|4' in prompt
    assert 'BAR|3|8.000000000|12.000000000|4|4' in prompt
    assert 'pauschale Quantisierung' in prompt and 'UNSICHER' in prompt
    assert 'N {TEST} 0.125000000 0.500000000 69 90 0' in prompt
    reply = ('Takt 1: Melodie, expressive Verzögerung. Takt 2: Bass; UNSICHER.\n'
        'SEMNOTE|{TEST}|0.125000000|0.500000000|69|90|0|Melodie|Achtel, rechte Hand|BESTAETIGT|Motivwiederkehr\n'
        'SEMNOTE|{TEST}|4.020000000|0.480000000|48|70|1|Bass|Achtel, linke Hand|UNSICHER|Alternative Mittelstimme\n'
        'SEMNOTE|{TEST}|8|0.25|99|75|1|Mittelstimme|Sechzehntel|VORLAEUFIG|Falsche Tonhöhe\n'
        'CS|new|-|Malicious|0|0,1,60,90,0')
    api.poll(reply)
    r = a.analysis
    assert r.state == 'draft' and a.pending is None
    assert len(r.semantic_notes) == 2 and r.semantic_invalid_count == 1
    assert r.semantic_uncertain_count == 1 and r.semantic_unassigned_count == 1
    assert r.semantic_source_unchanged and api.chunk() == original
    assert 'Nur Analyse' in api.status() and 'ohne Zuordnung: 1' in api.status()
    path = Path(a.history_path())
    stored = json.loads(path.read_text())
    assert stored[0]['raw_response'] == reply
    assert stored[0]['semantic_notes'][0]['original']['pitch'] == 69
    assert len(stored[0]['semantic_original']) == 3
    assert 'FIXTURE-KEY' not in path.read_text()
    assert a.load() and len(a.records[1].semantic_notes) == 2
    assert a.records[1].semantic_rejected[1].endswith('Falsche Tonhöhe')
    a.apply()  # An analysis never becomes an executable pending proposal.
    assert api.chunk() == original and api.calls() == 1
    print('PASS production request, meter, one provider stage, strict note binding, uncertainty, real JSON persistence/reload, no MIDI/CC/tempo APIs')

    api.select(True)
    api.begin('Analysiere die markierten Noten für Notation')
    assert api.calls() == 2 and 'READ_ONLY_REFERENCE' in api.job().prompt
    api.poll(reply)
    assert len(a.analysis.semantic_original) == 1 and len(a.analysis.semantic_notes) == 1
    assert a.analysis.semantic_invalid_count == 2
    assert len(a.analysis.notation_selection) == 1 and a.analysis.reference_context.startswith('READ_ONLY_REFERENCE')
    api.select(False)
    api.begin('Analysiere die markierten Noten für Notation')
    assert api.calls() == 2 and api.job() is None
    print('PASS selected-note analysis: one provider stage, exact target scope, read-only reference and missing-selection guard')

    api.begin('Analysiere die sichtbare Partitur für Notation')
    api.mutate()
    api.poll(reply)
    assert not a.analysis.semantic_source_unchanged and 'veraltet' in api.status()
    assert api.chunk() == 'EXTERNAL CHANGE'
    print('PASS external source change during request is recorded and visibly marked stale')

    before = path.read_bytes()
    api.begin('Analysiere die sichtbare Partitur für Notation')
    count = len(a.records)
    api.fail_write()
    api.poll(reply)
    assert len(a.records) == count and a.history_error
    assert path.read_bytes() == before and 'gesichert' in api.messages[len(api.messages)]
    print('PASS failed persistence retains existing history and removes unsaved in-memory record')
