"""Exercise the production request parser, dispatcher and controller response path.
No provider requests, REAPER writes or paid calls are made by these tests.
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
s=(Path(__file__).resolve().parents[1]/'Composition Studio.lua').read_text()
def section(a,b):return s[s.index(a):s.index(b)]
r=LuaRuntime(unpack_returned_tuples=True)
api=r.execute('''
local busy=false;local update_status="";local input="";local job=nil;local last_diag={}
local VERSION="test";local COMPOSITION_ENGINE_NAME="Engine";local COMPOSITION_ENGINE_VERSION="1";local COMPOSITION_ENGINE_BUILD="1"
local provider="openai";local model="test";local DIAG_CACHE_PATH="unused"
local sent,messages={},{};local answer="";local selected=true;local blocked=false
local context={{guid="item",end_qn=64,notes={}}};local tracks={{guid="track"}}
local reaper={CountSelectedMediaItems=function()return selected and 1 or 0 end,EnumProjects=function()return 1 end}
local function selected_items()return selected and context or {} end
local function selected_tracks()return tracks end
local function track_context_items()return context end
local function trim(x)return x end
local function add(_,x)messages[#messages+1]=x end
local function diag_set(k,v)last_diag[k]=v end
local function get_key()return "KEY" end
local function provider_name()return "test" end
local function compact_context()return "CONTEXT" end
local function recent_dialog()return "DIALOG" end
local function persist_diag()end
local function write_file()end
local function diag_json()return "{}" end
local function log_communication()end
local function ai_poll()return answer,nil,true end
local function launch(stage,prompt,key,data)
 sent[#sent+1]={stage=stage,prompt=prompt,data=data};job={stage=stage,data=data,key=key,project=1}
end
local function launch_new_json(req,key,data)launch("engine_json",req,key,data)end
local function continuation_prompt(req,items,tr,bars,start)return req.." TOTAL="..bars.." START="..start end
local function composition_prompt(req)return req end
local function analysis_prompt(req)return req end
local function begin_swam_interpretation()launch("swam_interpretation","SWAM","KEY",{})end
local workflow_core={prompt=function(mode)return mode end}
local reviewed=nil
local workflow_adapter={
 transition=function(_,endpoint,count)if blocked then error("crossing note") end;return endpoint-count*4 end,
 review=function(task)assert(not busy);reviewed=task end,
 offer=function(stage,text,data)sent[#sent+1]={stage="proposal",payload=text,data=data};busy=false end}
local CONTROLLER="TEST"
'''+section('local function request_words(request)','local function compact_music_excerpt')+
section('local function begin_continuation(request,bars,tail)','local function title_prompt()')+
section('local function poll_job()','local function submit()')+'''
return {bars=continuation_bars,tail=request_transition,
 begin=function(req)busy=true;begin_process(req)end,
 reply=function(text)answer=text;poll_job()end,
 last=function()return sent[#sent]end,count=function()return #sent end,
 message=function()return messages[#messages]end,reviewed=function()return reviewed end,
 select=function(value)selected=value end,block=function(value)blocked=value end}
''')
for request,bars,tail in [
 ('Verlängere um 16 Takte',16,0),
 ('Verlängere um 16 Takte und gestalte die letzten zwei Takte neu',16,2),
 ('Gestalte die letzten 3 Takte neu, verlängere um 16 Takte',16,3),
 ('Verlängere um sechzehn Takte mit vier Übergangstakten',16,4),
 ('Setze das Stück mit 16 weiteren Takten fort',16,0),
 ('Verlängere um 16 Takte, nimm das Motiv der letzten 2 Takte als Vorbild',16,0),
 ('Verlängere um 16 Takte; Schluss erhalten',16,0),
]:
 assert api.bars(request)==bars,request
 assert api.tail(request)==tail,request
 api.begin(request);last=api.last()
 assert last.stage=='lily_continuation',request
 assert last.data.extension_bars==bars+tail and last.data.extension_start==64-tail*4,request
 api.reply('GENERATED LILYPOND')
 assert api.last().stage=='proposal' and api.last().payload=='GENERATED LILYPOND'
print('PASS text continuations: exact new bars, explicit transition, German number words, existing ending preserved by default, generated result stays a proposal')
for text in ('Verlängere um 16 Takte mit einem Übergang','Verlängere um 16 Takte und gestalte die letzten 5 Takte neu','Verlängere um 16 Takte, Schluss erhalten, gestalte die letzten 2 Takte neu'):
 before=api.count();api.begin(text)
 assert api.count()==before and api.message(),text
api.block(True);before=api.count();api.begin('Verlängere um 16 Takte und gestalte die letzten 2 Takte neu')
assert api.count()==before and 'crossing note' in api.message()
api.block(False)
print('PASS ambiguous/unsupported transitions and unsafe musical boundaries do not launch generation')
api.select(False);api.begin('Verlängere um 16 Takte');assert api.last().stage=='lily_continuation'
print('PASS selected-track context also works without selected MIDI items')
for req,answer,stage in [
 ('Ergänze eine weitere Stimme von 16 Takten','NEED_MUSIC|Zusätzliche Stimme','composition'),
 ('Analysiere die Komposition','NEED_ANALYSIS|Musikalische Analyse','analysis'),
 ('Führe das Stück sechzehn Takte weiter','NEED_CONTINUE|16|2|Expliziter Übergang','lily_continuation'),
 ('Interpretiere die Auswahl für SWAM','NEED_SWAM|Interpretation','swam_interpretation'),
]:
 if 'NEED_CONTINUE' in answer:req+=' und gestalte die letzten zwei Takte neu'
 api.begin(req);assert api.last().stage=='controller',req
 api.reply(answer);assert api.last().stage==stage,req
 if stage=='composition':assert api.last().data.full[1].guid=='item'
api.begin('Setze die Vorschläge um');api.reply('NEED_REVISE|Letzte Analyse umsetzen')
assert api.reviewed()=='Setze die Vorschläge um'
api.begin('Überarbeite anhand der letzten Analyse')
assert api.reviewed()=='Überarbeite anhand der letzten Analyse'
api.begin('Führe weiter');before=api.count();api.reply('NEED_CONTINUE|16|5|Ungültiger Übergang')
assert api.count()==before
print('PASS real controller response path: extra voice, analysis, free continuation, SWAM, review; invalid transition rejected')
assert 'ImGui_MenuItem(ctx,"Fortsetzung:' not in s and 'Überarbeiten##review' not in s
print('PASS REAPER-specific UI has no transition menu or separate review button')
