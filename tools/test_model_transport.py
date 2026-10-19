"""Real curl/shell transport against a local HTTP fixture; actual Lua catalog code.
No API keys, provider calls or costs. REAPER calls are replaced, not HTTP parsing.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
import json,shlex,subprocess,threading
from urllib.parse import urlsplit,parse_qs
from lupa.lua54 import LuaRuntime
s=(Path(__file__).resolve().parents[1]/'Composition Studio.lua').read_text()
def section(a,b):return s[s.index(a):s.index(b)]
state={'error':False,'invalid':False};requests=[]
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  path=urlsplit(self.path);query=parse_qs(path.query);pv=path.path.strip('/')
  requests.append((pv,query))
  header={'openai':'Authorization','anthropic':'x-api-key','google':'x-goog-api-key'}[pv]
  assert self.headers[header]==('Bearer FIXTURE-KEY' if pv=='openai' else 'FIXTURE-KEY')
  if pv=='anthropic':assert self.headers['anthropic-version']=='2023-06-01'
  if pv=='openai':body={'data':[{'id':'gpt-future-2099'},{'id':'text-embedding-future'}]}
  elif pv=='anthropic':
   body={'data':[{'id':'claude-future-2' if query.get('after_id') else 'claude-future-1','display_name':'Future Claude'}],'has_more':not bool(query.get('after_id')),'last_id':'NEXT'}
  else:
   body={'models':[{'name':'models/gemini-future-2' if query.get('pageToken') else 'models/gemini-future-1','supportedGenerationMethods':['generateContent']},{'name':'models/embed-future','supportedGenerationMethods':['embedContent']}]}
   if not query.get('pageToken'):body['nextPageToken']='NEXT'
  self.send_response(401 if state['error'] else 200);self.end_headers()
  self.wfile.write(b'invalid JSON' if state['invalid'] else json.dumps(body).encode())
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
try:
 with TemporaryDirectory(prefix="Wilhelm's Studio ä ") as d:
  folder=Path(d);messages=[];saved={};clock=[0];mode=['normal'];commands=[]
  r=LuaRuntime(unpack_returned_tuples=True);r.globals().ROOT=d
  def execute(command,timeout):
   argv=shlex.split(command)
   assert len(argv)==2 and argv[0]=='/bin/sh' and Path(argv[1]).suffix=='.sh',command
   assert 'FIXTURE-KEY' not in command
   path=Path(argv[1]);script=path.read_text()
   assert 'FIXTURE-KEY' not in script
   commands.append(command)
   if mode[0]=='fail':return None
   if mode[0]=='hang':return ''
   for original,pv in [('https://api.openai.com/v1/models','openai'),('https://api.anthropic.com/v1/models','anthropic'),('https://generativelanguage.googleapis.com/v1beta/models','google')]:
    script=script.replace(original,f'http://127.0.0.1:{server.server_port}/{pv}')
   path.write_text(script)
   result=subprocess.run(argv,capture_output=True,timeout=5)
   assert result.returncode==0,result.stderr
   return result.stdout.decode()
  r.globals().reaper=r.table_from({'GetOS':lambda:'OSX64','GetResourcePath':lambda:d,'RecursiveCreateDirectory':lambda p,*_:Path(p).mkdir(exist_ok=True),
   'ExecProcess':execute,'time_precise':lambda:clock[0], 'GetExtState':lambda section,key:saved.get(key,''),'SetExtState':lambda section,key,value,*_:saved.__setitem__(key,value),
   'ShowMessageBox':lambda text,*_:messages.append(text)})
  api=r.execute('''
local EXT_SECTION="test";local SCRIPT_NAME="Studio";local busy=false;local update_status="";local provider="openai"
local KEY_NAMES={openai="key-openai",anthropic="key-anthropic",google="key-google"}
local MODELS={openai={{"Old","old"}},anthropic={{"Old","old"}},google={{"Old","old"}}}
local function get_key()return "FIXTURE-KEY" end
local function provider_name()return provider end
local function trim(s)return (s or ""):gsub("^%s+",""):gsub("%s+$","")end
local function enc(s)return s end
local workflow_adapter={}
'''+section('local IS_WINDOWS=','local function json_escape(s)')+
section('local function read_file(p)','local function version_parts(v)')+
section('local function decode_engine_json(src)','local function engine_translate_json(answer)')+
section('function workflow_adapter.encode(v)','function workflow_adapter.guard()')+
section('workflow_adapter.models={job=nil','-- End shared workflow host adapter.')+'''
return {models=workflow_adapter.models,lists=MODELS,provider=function(p)provider=p end}
''')
  def refresh(pv,quiet=False):
   api.provider(pv);api.models.refresh(quiet)
   for _ in range(5):
    if api.models.job is None:break
    api.models.poll()
   assert api.models.job is None
  for pv,expected in [('openai',1),('anthropic',2),('google',2)]:
   refresh(pv)
   assert len(api.lists[pv])==expected and 'future' in api.lists[pv][1][2]
   assert 'FIXTURE-KEY' not in saved['ModelCatalogV1-'+pv]
  assert len(requests)==5
  print('PASS macOS transport: real curl, quoted script path, three provider headers, 5 HTTP pages, filtering and persistent future model IDs')
  state['error']=True;refresh('openai');assert 'Zugriffsrechte' in api.models.message and messages
  assert api.lists.openai[1][2]=='gpt-future-2099'
  state['error']=False;state['invalid']=True;refresh('openai');assert 'nicht gelesen' in api.models.message
  state['invalid']=False;mode[0]='fail';refresh('openai');assert 'nicht gestartet' in api.models.message
  mode[0]='hang';api.models.refresh(False);assert api.models.job is not None
  clock[0]=31;api.models.poll();assert api.models.job is None and 'Zeitlimit' in api.models.message
  assert not list(folder.rglob('*.curl-config'))
  before=len(messages);api.models.refresh(True)
  assert api.models.job is None and 'API-Key' in api.models.message and len(messages)==before
  saved['key-openai']='FIXTURE-KEY';mode[0]='normal';refresh('openai',True)
  assert 'eingelesen' in api.models.message and len(messages)==before
  print('PASS model errors: HTTP 401, invalid response, process failure, timeout, old catalog retained, credentials cleaned')
finally:server.shutdown();server.server_close()
