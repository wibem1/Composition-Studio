"""Real local HTTP plus production polling: bounded waits, no retry, honest usage."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading
import time
from tempfile import TemporaryDirectory

from lupa.lua54 import LuaRuntime
from build_studio import ROOT, inline, load_manifest

units = {unit['id']: unit for unit in load_manifest()['units']}


def source(name):
    return inline(units[name])


def environment(folder, windows, fast=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = str(folder)
    lua.globals().WINDOWS = windows
    code = '''
local provider="google";local model="gemini-3.8-flash";local reasoning_mode="high"
local EXT_SECTION="test";local SCRIPT_NAME="test";local busy=false
local last_diag={};local settings={};local launches={}
local reaper={GetOS=function()return WINDOWS and "Win64" or "OSX64" end,
 GetResourcePath=function()return ROOT end,RecursiveCreateDirectory=function()end,
 GetExtState=function(_,key)return settings[key] or "" end,
 SetExtState=function(_,key,value)settings[key]=value end,
 time_precise=function()return 10 end,ExecProcess=function()return "" end}
local function diag_set(key,value)last_diag[key]=value end
local function trim(value)return (value or ""):match("^%s*(.-)%s*$")end
local REASONING_LABELS={low="Kurz",medium="Mittel",high="Hoch",auto="Automatisch"}
local function add()end
local workflow_core={prompt=function()return "" end}
local workflow_adapter_guard=function()return "guard"end
local function first_text_field(raw)return raw:match('"text"%s*:%s*"([^\"]+)"')end
local function response_text(raw)return first_text_field(raw)end
local launch
'''
    code += source('platform/process') + source('platform/files') + source('ai/response') + source('ai/reasoning') + source('ai/costs')
    requests = source('ai/requests')
    if fast:
        assert requests.count('local timeout=600') == 1
        requests = requests.replace('local timeout=600', 'local timeout=1', 1)
    code += '''
ps_launch=function(path)launches[#launches+1]=path;return true end
local execute=os.execute
os.execute=function(command)launches[#launches+1]=command;return execute(command)end
'''
    code += requests
    code += '''
return {command=ai_command,poll=ai_poll,diagnostics=last_diag,costs=costs,launches=launches,
 set_provider=function(value)provider=value end,
 set_reasoning=function(value)reasoning_mode=value end,
 scripts=function()return launches end}
'''
    return lua, lua.execute(code)


with TemporaryDirectory() as temporary:
    folder = Path(temporary)
    (folder / 'CompositionStudioTemp').mkdir()
    lua, api = environment(folder, True)
    # Bounded output requests use each provider's actual wire parameter.
    for provider in ('google', 'openai', 'anthropic'):
        api.set_provider(provider)
        for effort in ('high', 'auto'):
            api.set_reasoning(effort)
            request, error = api.command('bounded fixture', 'FIXTURE-KEY', 2048)
            assert request.timeout_seconds == 120 and request.deadline == 150
            body = json.loads(Path(request.rq).read_text())
            if provider == 'google':
                assert body['generationConfig']['maxOutputTokens'] == 2048
                if effort == 'high': assert body['generationConfig']['thinkingConfig']['thinkingLevel'] == 'high'
            elif provider == 'openai': assert body['max_output_tokens'] == 2048
            else: assert body['max_tokens'] == 2048
    api.set_provider('google'); api.set_reasoning('high')
    fixture_launches = len(api.launches)
    api.costs.total.calls = 0
    api.costs.total.unknown = 0
    for provider, ending in (
        ('google', {'finishReason': 'MAX_TOKENS'}),
        ('anthropic', {'stop_reason': 'max_tokens'}),
        ('openai', {'status': 'incomplete', 'incomplete_details': {'reason': 'max_output_tokens'}}),
        ('openai', {'finish_reason': 'length'}),
    ):
        api.set_provider(provider)
        request, error = api.command('incomplete fixture', 'FIXTURE-KEY', 8192)
        Path(request.cd).write_text('200')
        Path(request.rs).write_text(json.dumps(dict(ending, text='partial notes')))
        result, error, done = api.poll(request)
        assert result is None and done and 'Tokenlimit' in error
    api.set_provider('google')
    fixture_launches = len(api.launches)
    api.costs.total.calls = 0
    api.costs.total.unknown = 0
    first, error = api.command('fixture', 'FIXTURE-KEY')
    assert error is None and first.timeout_seconds == 600 and first.deadline == 630
    script = Path(api.launches[fixture_launches + 1]).read_text(encoding='utf-8-sig')
    assert '[TimeSpan]::FromSeconds(600)' in script
    assert '$cause.InnerException' in script and '[System.OperationCanceledException]' in script
    assert "$code = 'TIMEOUT'" in script and 'finally' in script
    assert 'ServicePointManager' in script and 'ServerCertificateValidationCallback' not in script
    # An actual first provider response has usage; the following request times out.
    Path(first.cd).write_text('200')
    Path(first.rs).write_text(json.dumps({'text': 'ok', 'usageMetadata': {
        'promptTokenCount': 1140, 'candidatesTokenCount': 530}}))
    assert api.poll(first)[0] == 'ok'
    assert api.diagnostics.usage_input_tokens == '1140'
    assert api.diagnostics.usage_estimated_usd != ''
    second, error = api.command('next fixture', 'FIXTURE-KEY')
    assert api.diagnostics.usage_input_tokens == '' and api.diagnostics.usage_estimated_usd == ''
    Path(second.cd).write_text('TIMEOUT')
    Path(second.rs).write_text('Request was cancelled')
    text, error, done = api.poll(second)
    assert text is None and done and '600 Sekunden' in error and 'unbekannt' in error
    assert api.diagnostics.api_status == 'TIMEOUT'
    for key in ('usage_input_tokens', 'usage_output_tokens', 'usage_estimated_usd', 'usage_reasoning_tokens'):
        assert api.diagnostics[key] == '', key
    assert api.costs.total.calls == 2 and api.costs.total.unknown == 1
    # Prior known usage remains in aggregate totals, not in the failed call's fields.
    assert api.costs.total.input == 1140 and api.costs.total.output == 530
    assert len(api.launches) == fixture_launches + 2
    assert not Path(second.cd).exists() and not Path(second.rq).exists()
    missing, error = api.command('missing status', 'FIXTURE-KEY')
    missing.deadline = 0
    assert api.poll(missing)[0] is None and api.diagnostics.usage_input_tokens == ''
    assert api.diagnostics.api_status == 'TIMEOUT'
    known, error = api.command('timeout with reported usage', 'FIXTURE-KEY')
    Path(known.cd).write_text('TIMEOUT')
    Path(known.rs).write_text(json.dumps({'usageMetadata': {'promptTokenCount': 2, 'candidatesTokenCount': 1}}))
    text, error, done = api.poll(known)
    assert text is None and done and 'Vorliegende Verbrauchsdaten' in error
    assert api.diagnostics.usage_input_tokens == '2' and api.costs.total.input == 1142
    print('PASS Windows generated timeout policy, nested cancellation classification, no retry and per-call/aggregate usage separation')


state = {'delay': 0, 'requests': 0}
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass
    def do_POST(self):
        state['requests'] += 1
        self.rfile.read(int(self.headers['Content-Length']))
        time.sleep(state['delay'])
        self.send_response(200)
        self.end_headers()
        try:
            self.wfile.write(json.dumps({'text': 'complete', 'usageMetadata': {
                'promptTokenCount': 10, 'candidatesTokenCount': 5}}).encode())
        except (BrokenPipeError, ConnectionResetError):
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with TemporaryDirectory() as temporary:
        folder = Path(temporary)
        (folder / 'CompositionStudioTemp').mkdir()
        lua, api = environment(folder, False, fast=True)
        # Keep the actual generated shell/curl path, redirect only the test endpoint.
        lua.globals().LOCAL_URL = 'http://127.0.0.1:' + str(server.server_port) + '/fixture'
        lua.execute('''local execute=os.execute;os.execute=function(command)
         command=command:gsub("https://generativelanguage.googleapis.com/[^']+",LOCAL_URL)
         return execute(command)
        end''')
        # Only loopback fixtures bypass the inherited external network proxy.
        old = {name: os.environ.get(name) for name in ('NO_PROXY', 'no_proxy')}
        for name in old:
            os.environ[name] = ','.join(filter(None, [old[name], '127.0.0.1', 'localhost']))
        try:
            for delay in (0, 2):
                state['delay'] = delay
                request, error = api.command('local HTTP fixture', 'FIXTURE-KEY')
                assert request.deadline == 31
                deadline = time.monotonic() + 5
                while not Path(request.cd).exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                assert Path(request.cd).exists()
                result, error, done = api.poll(request)
                assert done
                if delay:
                    assert result is None and 'Zeitlimit' in error
                    assert api.diagnostics.api_status == 'TIMEOUT'
                    assert api.diagnostics.usage_input_tokens == ''
                else:
                    assert result == 'complete' and api.diagnostics.usage_input_tokens == '10'
            assert state['requests'] == 2, 'Unexpected retry'
        finally:
            for name, value in old.items():
                if value is None:
                    os.environ.pop(name, None)
                else:
                    os.environ[name] = value
    print('PASS real Unix HTTP success/timeout with fast fault injection, atomic status publication and no retry')
finally:
    server.shutdown()
    server.server_close()
