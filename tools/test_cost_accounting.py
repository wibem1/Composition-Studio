"""Run with Python + lupa (Lua 5.4). No paid API calls."""
from pathlib import Path
import sys, json, tempfile
sys.path.insert(0,str(Path(__file__).parent/"python-deps"))
from lupa.lua54 import LuaRuntime

here=Path(__file__).resolve().parent
path=Path(sys.argv[1]) if len(sys.argv)>1 else here.parent/"Composition Studio.lua"
source=path.read_text(encoding="utf-8")
def section(a,b): return source[source.index(a):source.index(b)]
module=section("-- Local token-cost estimates,","-- End cost accounting.")+"-- End cost accounting.\n"
json_helpers=section("local function utf8(cp)","local function provider_name()")
files=section("local function read_file(p)","local function version_parts(v)")
ai=section("local job=nil","-- The official LilyPond compiler")
passed=[]
def test(name,fn):
    fn(); passed.append(name); print("PASS",name)
scratch=tempfile.TemporaryDirectory(prefix="cs-cost-tests-")
def env(saved=None):
    r=LuaRuntime(unpack_returned_tuples=True)
    r.globals().TEST_ROOT=scratch.name.replace("\\","/")
    r.globals().saved=r.table_from(saved or {})
    r.execute("""
    provider="openai"; model="gpt-5.6-sol"; busy=false
    reaper={GetExtState=function(_,k) return saved[k] or "" end,
     SetExtState=function(_,k,v) saved[k]=v end,
     time_precise=function() return 10 end,
     EnumProjects=function() return 1 end,
     ShowMessageBox=function(text) shown=text end,
     GetUserInputs=function() return false,"" end}
    """)
    api=r.execute("""
    local EXT_SECTION="CompositionStudio"
    local SCRIPT_NAME="Composition Studio"
    local update_status=""
    local IS_WINDOWS=true
    local diagnostics={}
    local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
    local function shell_quote(s) return '"'..s..'"' end
    local function json_escape(s) return s end
    local function diag_set(k,v) diagnostics[k]=v end
    local function add() end
    local seq=0
    local function temp_path(ext) seq=seq+1; return TEST_ROOT.."/cost_"..seq..(ext or "") end
    local function windows_curl_script() return "mock.ps1" end
    local function ps_launch() return true end
    """+json_helpers+files+"""
    local function first_text_field(raw)
     local _,e=raw:find('"text"%s*:'); local q=e and raw:find('"',e+1,true)
     return q and read_json_string(raw,q)
    end
    """+module+ai+"""
    return {costs=costs,command=ai_command,poll=ai_poll,launch=launch,
      job=function() return job end,status=function() return update_status end}
    """)
    return r,api,api.costs

fixtures={
 "openai":{"usage":{"input_tokens":1000,"output_tokens":100,"input_tokens_details":{"cached_tokens":400,"cache_write_tokens":200},"output_tokens_details":{"reasoning_tokens":50}}},
 "anthropic":{"usage":{"input_tokens":400,"output_tokens":100,"cache_read_input_tokens":300,"cache_creation_input_tokens":300,"cache_creation":{"ephemeral_5m_input_tokens":200,"ephemeral_1h_input_tokens":100}}},
 "google":{"usageMetadata":{"promptTokenCount":1000,"candidatesTokenCount":60,"thoughtsTokenCount":40,"cachedContentTokenCount":400}}
}
for pv,expected in [
 ("openai",dict(input=1000,output=100,cached=400,write5=200,write1=0)),
 ("anthropic",dict(input=1000,output=100,cached=300,write5=200,write1=100)),
 ("google",dict(input=1000,output=100,cached=400,write5=0,write1=0))]:
    def run(pv=pv,expected=expected):
        _,_,c=env(); n=c.usage(pv,json.dumps(fixtures[pv]))
        assert n is not None
        assert {k:n[k] for k in expected}==expected
    test(pv+" token categories without double-counted thinking/cache",run)

for name,pv,raw in [
 ("missing usage","openai",'{"output":[{"text":"usage: 100"}]}'),
 ("null usage","openai",'{"usage":null}'),
 ("negative tokens","openai",'{"usage":{"input_tokens":-1,"output_tokens":10}}'),
 ("fractional tokens","openai",'{"usage":{"input_tokens":1.5,"output_tokens":10}}'),
 ("cache exceeds input","openai",'{"usage":{"input_tokens":1,"output_tokens":10,"input_tokens_details":{"cached_tokens":2}}}'),
 ("missing output count","google",'{"usageMetadata":{"promptTokenCount":100}}'),
 ("conflicting cache writes","anthropic",'{"usage":{"input_tokens":10,"output_tokens":10,"cache_creation_input_tokens":4,"cache_creation":{"ephemeral_5m_input_tokens":2,"ephemeral_1h_input_tokens":3}}}'),
 ("quoted fake usage","openai",json.dumps({"output":[{"text":json.dumps(fixtures["openai"])}]})),
 ("nested fake usage","openai",json.dumps({"output":[fixtures["openai"]]})),
 ("no response","openai",None),
]:
    def run(pv=pv,raw=raw):
        _,_,c=env(); assert c.usage(pv,raw) is None
    test(name+" remains unknown",run)

def priced():
    _,_,c=env()
    n=c.usage("openai",json.dumps(fixtures["openai"]))
    assert abs(c.price(n,c.rate("openai","gpt-5.6-sol"))-0.00476)<1e-12
test("OpenAI cache read/write price",priced)
def long_context():
    _,_,c=env()
    n=c.usage("openai",'{"usage":{"input_tokens":272001,"output_tokens":1000}}')
    assert abs(c.price(n,c.rate("openai","gpt-5.6-terra"))-(272001*4+1000*18)/1e6)<1e-12
test("OpenAI long-context price threshold",long_context)
def claude_price():
    _,_,c=env(); n=c.usage("anthropic",json.dumps(fixtures["anthropic"]))
    assert abs(c.price(n,c.rate("anthropic","claude-fable-5"))-0.0138)<1e-12
test("Anthropic 5m/1h write prices",claude_price)
def google_price():
    _,_,c=env(); n=c.usage("google",json.dumps(fixtures["google"]))
    assert abs(c.price(n,c.rate("google","gemini-3.8-flash"))-0.000855)<1e-12
test("Gemini thinking and cached price",google_price)
def nullable_optional_counts():
    _,_,c=env()
    n=c.usage("openai",'{"usage":{"input_tokens":10,"output_tokens":2,"input_tokens_details":{"cached_tokens":null,"cache_write_tokens":null}}}')
    assert n.input==10 and n.cached==0 and n.write5==0
test("nullable optional cache counts",nullable_optional_counts)

def persistence():
    r,api,c=env()
    c.begin(); a=r.table_from({"provider":"openai","model":"gpt-5.6-sol"})
    c.start(a); assert c.total.calls==1 and c.total.unknown==1
    c.record(a,json.dumps(fixtures["openai"]))
    c.record(a,json.dumps(fixtures["openai"]))
    assert c.total.calls==1 and c.total.unknown==0 and c.order.input==1000
    saved={k:v for k,v in r.globals().saved.items()}
    _,_,restored=env(saved)
    assert restored.total.calls==1 and abs(restored.total.usd-c.total.usd)<1e-10
    assert restored.order.input==1000
    c.begin(); assert c.order.calls==0 and c.total.calls==1
test("persistent totals/order and idempotent accounting",persistence)
def pending():
    r,_,c=env(); a=r.table_from({"provider":"openai","model":"gpt-5.6-sol"})
    c.start(a)
    _,_,restored=env({k:v for k,v in r.globals().saved.items()})
    assert restored.total.calls==1 and restored.total.unknown==1
test("interrupted request stays visible after restart",pending)
def unknown_price():
    r,_,c=env(); a=r.table_from({"provider":"google","model":"unpriced-model"})
    c.start(a); c.record(a,json.dumps(fixtures["google"]))
    assert c.total.input==1000 and c.total.usd==0 and c.total.unknown==1
    assert "ohne vollständige" in c.text(c.total)
test("unpriced model tracks usage and marks incomplete cost",unknown_price)
def model_snapshot():
    r,_,c=env(); a=r.table_from({"provider":"openai","model":"gpt-5.6-sol"})
    c.start(a); r.globals().model="gpt-5.6-luna"
    r.globals().saved["CostRateV1:openai/gpt-5.6-sol"]="99,99,99,99,99"
    c.record(a,json.dumps(fixtures["openai"]))
    assert abs(c.total.usd-0.00476)<1e-12
test("request retains model and tariff snapshot",model_snapshot)
def zero_rate():
    r,_,c=env({"CostRateV1:google/gemini-3.8-flash":"0,0,0,0,0"})
    a=r.table_from({"provider":"google","model":"gemini-3.8-flash"})
    c.start(a); c.record(a,json.dumps(fixtures["google"]))
    assert c.total.usd==0 and c.total.unknown==0
test("explicit free-tier zero prices",zero_rate)
def invalid_rate():
    _,_,c=env({"CostRateV1:openai/gpt-5.6-sol":"1,,2,3,4,5"})
    assert c.rate("openai","gpt-5.6-sol")[1]==4
test("invalid custom price is rejected",invalid_rate)
def price_dialog():
    r,api,c=env()
    r.globals().reaper.GetUserInputs=r.eval('function() return true,"-1,2,3,4,5" end')
    c.edit_rate()
    assert "nicht gespeichert" in api.status()
    assert r.globals().saved["CostRateV1:openai/gpt-5.6-sol"] is None
    r.globals().reaper.GetUserInputs=r.eval('function() return true,"1,2,3,4,5" end')
    c.edit_rate(); assert c.rate("openai","gpt-5.6-sol")[1]==1
test("price settings validation and persistence",price_dialog)
def expiry():
    r,_,c=env()
    r.execute('os.date=function() return "2027-01-02" end')
    assert c.rate("openai","gpt-5.6-sol") is None
    assert c.rate("google","gemini-3.8-flash")[1]==1.5
test("promotional price expiration",expiry)

def integrated_poll(status="200",payload=None,timeout=False):
    r,api,c=env()
    a=api.command("test prompt","fake-test-key")[0]
    if not timeout:
        Path(a.cd).write_text(status)
        Path(a.rs).write_text(json.dumps(payload or (fixtures["openai"] | {"output":[{"type":"output_text","text":"ok"}]})))
    else: a.deadline=0
    result=api.poll(a)
    assert result[2] is True
    return r,api,c,a,result
def success_poll():
    _,_,c,_,result=integrated_poll()
    assert result[0]=="ok" and c.total.calls==1 and c.total.input==1000 and c.total.unknown==0
test("actual ai_command/ai_poll integration records usage",success_poll)
def malformed_output():
    _,_,c,_,result=integrated_poll(payload=fixtures["openai"])
    assert result[0] is None and c.total.input==1000 and c.total.unknown==0
test("paid usage counted even when answer text cannot be read",malformed_output)
def error_response():
    _,_,c,_,result=integrated_poll(status="429",payload={"error":{"message":"quota"}})
    assert result[0] is None and c.total.calls==1 and c.total.unknown==1
test("HTTP error without usage is never reported as known zero cost",error_response)
def timeout():
    _,_,c,_,result=integrated_poll(timeout=True)
    assert result[0] is None and c.total.calls==1 and c.total.unknown==1
test("timeout remains incomplete",timeout)
def multi_stage():
    r,api,c=env()
    api.launch("controller","prompt","fake",r.table())
    a=api.job().ai
    Path(a.cd).write_text("200"); Path(a.rs).write_text(json.dumps(fixtures["openai"] | {"output":[{"type":"output_text","text":"ok"}]}))
    api.poll(a)
    api.launch("lily_composition","prompt","fake",r.table())
    assert c.order.calls==2 and c.total.calls==2 and c.order.input==1000
    api.launch("swam_interpretation","prompt","fake",r.table())
    assert c.order.calls==1 and c.total.calls==3
test("root requests reset order while follow-up stages accumulate",multi_stage)
def overview():
    r,_,c=env(); c.show()
    assert "Gesamt seit" in r.globals().shown and "keine Anbieterrechnung" in r.globals().shown
test("cost overview text and estimate label",overview)
scratch.cleanup()
print(len(passed),"cost tests passed")
