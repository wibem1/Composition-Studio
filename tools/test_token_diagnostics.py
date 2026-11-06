"""Production usage accounting, visible partial response, JSON export and restart restore."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from lupa.lua54 import LuaRuntime
from build_studio import inline,load_manifest

units={u['id']:u for u in load_manifest()['units']}
def source(name):return inline(units[name])

def setup(folder):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().ROOT=folder
    code='''
local EXT_SECTION="diagnosis-test";local SCRIPT_NAME="test";local busy=false;local last_diag={}
local provider="google";local model="gemini-4-argon";local reasoning_mode="medium";local settings={}
local reaper={GetResourcePath=function()return ROOT end,GetExtState=function(_,k)return settings[k] or ""end,
 SetExtState=function(_,k,v)settings[k]=v end,time_precise=function()return 10 end}
local function add()end
local function reasoning_parameters()return "","fixture"end
local launch
'''
    for name in ['core/text','platform/files','ai/response','diagnostics/state','ai/costs','music/json_codec','diagnostics/partial_response','ai/requests']:
        code+=source(name)
    code+='''
return {diag=function()return last_diag end,export=diag_json,costs=costs,
 run=function(pv,md,raw,status)
  diag_set("api_stage","composition")
  local a={provider=pv,model=md,timeout_seconds=600,deadline=1000,rq=ROOT.."/rq",rs=ROOT.."/rs",cd=ROOT.."/code"}
  costs.start(a);write_file(a.rq,"REQUEST FIXTURE");write_file(a.rs,raw);write_file(a.cd,status or "200")
  return ai_poll(a)
 end,
 start=function()local a={provider="google",model="gemini-4-argon",timeout_seconds=600};costs.start(a);return a end,
 record=costs.record}
'''
    return lua,lua.execute(code)


def google(answer,thoughts,text='CS|new|-|Synth|80|0,1,60,90,0;'):
    usage={'promptTokenCount':33932,'candidatesTokenCount':answer}
    if thoughts is not None:usage['thoughtsTokenCount']=thoughts
    return {'usageMetadata':usage,'candidates':[{'finishReason':'MAX_TOKENS','content':{'parts':[
     {'thought':True,'text':'HIDDEN_THINKING_BLOCK'}, {'thought':'unexpected','text':'HIDDEN_MALFORMED_FLAG'}, {'text':text}]}}]}

for answer,thoughts in [(32768,0),(768,32000),(32768,None)]:
    with TemporaryDirectory() as folder:
        lua,api=setup(folder);raw=json.dumps(google(answer,thoughts))
        result,error,done=api.run('google','gemini-4-argon',raw,'200')
        assert result is None and done and 'Tokenlimit' in error
        d=json.loads(api.export())
        assert d['usage_answer_tokens']==str(answer)
        assert d['usage_output_tokens']=='32768'
        assert d['usage_reasoning_tokens']==(str(thoughts) if thoughts is not None else 'nicht separat ausgewiesen')
        assert d['usage_estimated_usd']=='0.395544'
        assert d['usage_input_estimated_usd']=='0.067864' and d['usage_output_estimated_usd']=='0.327680'
        if thoughts is not None:
            assert abs(float(d['usage_reasoning_estimated_usd'])-thoughts*.00001)<1e-9
        else:
            assert d['usage_reasoning_estimated_usd']=='' and 'unbekannt' in d['usage_breakdown_status']
        assert d['api_partial_answer'].startswith('CS|new|')
        assert 'HIDDEN_' not in api.export()
        assert json.loads(d['usage_provider_json'])['promptTokenCount']==33932
        assert d['api_stage']=='composition' and d['api_stop_reason']=='MAX_TOKENS'
        assert not Path(folder,'rs').exists() and not Path(folder,'rq').exists()
        assert api.costs.total.calls==1
        # Exactly the previously exported counts, stop reason and partial text survive fresh Lua startup.
        lua,api=setup(folder);restored=json.loads(api.export())
        for key in ['usage_answer_tokens','usage_output_tokens','usage_reasoning_tokens','usage_estimated_usd','api_stop_reason','api_partial_answer','usage_provider_json','api_stage']:
            assert restored[key]==d[key],key
        api.start();pending=json.loads(api.export())
        for key in ['usage_answer_tokens','usage_reasoning_tokens','usage_provider_json','api_partial_answer','api_partial_answer_bytes']:
            assert pending[key]=='',key
        assert pending['api_status']=='PENDING'

with TemporaryDirectory() as folder:
    lua,api=setup(folder)
    raw={'status':'incomplete','incomplete_details':{'reason':'max_output_tokens'},
     'usage':{'input_tokens':33932,'output_tokens':32768,'output_tokens_details':{'reasoning_tokens':32000}},
     'output':[{'type':'reasoning','summary':[{'type':'summary_text','text':'HIDDEN_REASONING'}]},
               {'type':'message','content':[{'type':'output_text','text':'VISIBLE PARTIAL'},{'type':'refusal','refusal':'NOT OUTPUT TEXT'}]}]}
    assert api.run('openai','gpt-5.6-terra',json.dumps(raw),'200')[0] is None
    d=json.loads(api.export())
    assert d['usage_output_tokens']=='32768' and d['usage_reasoning_tokens']=='32000' and d['usage_answer_tokens']=='768'
    assert d['api_partial_answer']=='VISIBLE PARTIAL' and 'HIDDEN_' not in api.export()
    assert d['api_stop_reason']=='max_output_tokens'
    assert d['usage_estimated_usd']=='0.461080' # reasoning already included, not added twice
    for invalid in [-1,32769,'not-a-number']:
        broken=json.loads(json.dumps(raw));broken['usage']['output_tokens_details']['reasoning_tokens']=invalid
        assert api.costs.usage('openai',json.dumps(broken)) is None

with TemporaryDirectory() as folder:
    lua,api=setup(folder)
    raw={'stop_reason':'max_tokens','usage':{'input_tokens':33932,'output_tokens':32768},
         'content':[{'type':'thinking','thinking':'HIDDEN_THINKING'},{'type':'text','text':'VISIBLE ANTHROPIC'}]}
    assert api.run('anthropic','claude-sonnet-5',json.dumps(raw),'200')[0] is None
    d=json.loads(api.export())
    assert d['usage_output_tokens']=='32768' and 'nicht separat' in d['usage_reasoning_tokens']
    assert d['usage_answer_tokens']=='nicht separat bestimmbar'
    assert d['usage_reasoning_estimated_usd']=='' and d['api_partial_answer']=='VISIBLE ANTHROPIC'
    assert 'HIDDEN_' not in api.export()

# Bounded retention, UTF-8 safe slicing and proper JSON escaping/restore of control characters.
for text in ['€'*100000,'Visible\n"quoted"\\text\t\x01🙂']:
    with TemporaryDirectory() as folder:
        lua,api=setup(folder)
        assert api.run('google','gemini-4-argon',json.dumps(google(768,32000,text)),'200')[0] is None
        d=json.loads(api.export());retained=d['api_partial_answer']
        assert int(d['api_partial_answer_bytes'])==len(text.encode())
        assert len(retained.encode())<=262144 and text.startswith(retained)
        assert d['api_partial_truncated']==('true' if len(text.encode())>262144 else 'false')
        lua,api=setup(folder);assert json.loads(api.export())['api_partial_answer']==retained
with TemporaryDirectory() as folder:
    lua,api=setup(folder)
    assert api.run('google','gemini-4-argon','{"finishReason":"MAX_TOKENS","candidates":[','200')[0] is None
    d=json.loads(api.export());assert d['api_partial_answer']=='' and 'ungültig' in d['api_partial_status']
print('PASS real production diagnostic split for Google/OpenAI/Anthropic, equal totals with different thinking shares, unchanged billing, safe partial retention, UTF-8/control JSON and fresh-session restore; no provider calls')

# Old exports still load, with unavailable new breakdown explicitly left unset.
with TemporaryDirectory() as folder:
    Path(folder,'Composition-Studio-Last-Diagnosis.json').write_text(json.dumps({'version':'1.3.0','usage_output_tokens':'32768','usage_reasoning_tokens':'nicht separat ausgewiesen','api_stop_reason':'MAX_TOKENS'}))
    lua,api=setup(folder);d=json.loads(api.export())
    assert d['usage_output_tokens']=='32768' and d['usage_reasoning_tokens']=='nicht separat ausgewiesen'
    assert d['usage_answer_tokens']=='' and d['api_partial_answer']==''
print('PASS old diagnosis compatibility without inventing historical breakdown')
