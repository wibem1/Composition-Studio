from pathlib import Path
import sys, subprocess, tempfile, json, re
sys.path.insert(0, str(Path(__file__).parent / "python-deps"))
from lupa.lua54 import LuaRuntime

# Usage: python tools/test_lilypond_import.py [path/to/Composition Studio.lua]
# Requires Python and lupa (Lua 5.4); LilyPond is optional, see LILYPOND_EXE.
import os
script_dir = Path(__file__).resolve().parent
default_source = script_dir.parent / "Composition Studio.lua"
source_path = Path(sys.argv[1]) if len(sys.argv)>1 else default_source
source = source_path.read_text(encoding="utf-8")
source_version = re.search(r"-- @version (\S+)", source).group(1)
scratch = tempfile.TemporaryDirectory(prefix="composition-studio-tests-")
root = Path(scratch.name)
results = []
def check(name, body):
    body()
    results.append(name)
    print("PASS", name)

def section(start, end):
    return source[source.index(start):source.index(end)]

def assert_true(value):
    assert value

lua = LuaRuntime(unpack_returned_tuples=True)
syntax = lua.eval("function(s) local f,e=load(s,'@Composition Studio.lua','t'); return f~=nil,e end")
check("full script Lua 5.4 syntax", lambda: assert_true(syntax(source)[0]))
def startup_smoke():
    r=LuaRuntime(unpack_returned_tuples=True)
    r.execute("""
    writes={}
    io.open=function(path,mode)
      if mode=="rb" then return nil end
      return {write=function(_,s) writes[path]=s end,close=function() end}
    end
    reaper=setmetatable({
      GetExtState=function() return "" end,
      GetProjExtState=function() return 0,"" end,
      GetResourcePath=function() return "memory" end,
      GetOS=function() return "Win64" end,
      EnumProjects=function() return 1 end,
      ImGui_CreateContext=function() return {} end,
      ImGui_CreateFont=function() return {} end,
      ImGui_Begin=function(_,_,open) return true,open end,
      ImGui_BeginPopup=function() return false end,
      ImGui_Button=function() return false end,
      ImGui_MenuItem=function() return false end,
      ImGui_BeginChild=function() return false end,
      ImGui_GetContentRegionAvail=function() return 360,600 end,
      ImGui_InputTextMultiline=function(_,_,text) return false,text end,
      defer=function(fn) deferred=fn end
    },{__index=function() return function() return 0 end end})
    """)
    r.execute(source)
    assert r.globals().deferred is not None
check("full script startup and first visible UI frame with simulated REAPER/ImGui",startup_smoke)
header = r"""
local IS_WINDOWS=true
local EXT_SECTION="CompositionStudio"
local last_made={}
local diagnostics={}
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function shell_quote(s) return '"'..s..'"' end
local function diag_set(k,v) diagnostics[k]=v end
local function item_guid(it) return it.id end
local seq=0
local function temp_path(ext) seq=seq+1; return TEST_ROOT.."/fixture_"..seq..ext end
"""
files = section("local function read_file(p)", "local function version_parts(v)")
lily = section("local LILYPOND_PATH_KEY=", "local function lily_composition_prompt(")
exports = section(" local function process_result(raw)", " if not IS_WINDOWS then return nil,") + """
return {parse=process_result, score=midi_score, compile=lily_compile_import,
 diag=diagnostics, made=function() return last_made end}
"""

mock = r"""
reaper={}
state={tracks={{id="existingA",items={}},{id="existingB",items={}}}, cursor=9,
 raw="0\ncompiler output", midi=true, kind="midi", import=true, start=0, length=4,
 undo=0, imports=0, metadata="", insertAt=2}
function reaper.GetExtState() return "fixture-lily.exe" end
function reaper.SetExtState() end
function reaper.file_exists(p) return not p:match("%.mid$") or state.midi end
function reaper.ExecProcess() return state.raw end
function reaper.CountTracks() return #state.tracks end
function reaper.GetTrack(_,ix) return state.tracks[ix+1] end
function reaper.GetCursorPosition() return state.cursor end
function reaper.SetEditCurPos(n) state.cursor=n end
function reaper.Undo_BeginBlock2() end
function reaper.Undo_EndBlock2() end
function reaper.Undo_DoUndo2()
 state.undo=state.undo+1
 for i=#state.tracks,1,-1 do
  if state.tracks[i].id=="new" then table.remove(state.tracks,i) end
 end
end
function reaper.TimeMap2_QNToTime(_,qn) return qn end
function reaper.TimeMap2_timeToQN(_,t) return t end
function reaper.TimeMap_GetTimeSigAtTime() return 4,4,120 end
function reaper.InsertMedia()
 state.imports=state.imports+1
 if not state.import then return 0 end
 local items={}
 if state.kind~="empty" then
  items[1]={id="newItem",midi=state.kind=="midi",start=state.start,length=state.length}
 end
 table.insert(state.tracks,state.insertAt,{id="new",items=items})
 return 1
end
function reaper.CountTrackMediaItems(tr) return #tr.items end
function reaper.GetTrackMediaItem(tr,ix) return tr.items[ix+1] end
function reaper.GetActiveTake(it) return it end
function reaper.TakeIsMIDI(tk) return tk.midi end
function reaper.GetMediaItemInfo_Value(it,key)
 return key=="D_POSITION" and it.start or it.length
end
function reaper.SetProjExtState(_,_,_,v) state.metadata=v end
function reaper.UpdateArrange() end
"""
fixture = r"""\version "2.26.0" \score { \new Staff { c'1 } }"""
def env():
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().TEST_ROOT=root.as_posix()
    runtime.execute(mock)
    api=runtime.execute(header+files+lily+exports)
    return runtime,api,runtime.globals().state

for raw,code,output in [
    ("0\nOK",0,"OK"), ("0\r\nOK\nwarning",0,"OK\nwarning"),
    ("1\nerror",1,"error"), ("-1\n", -1, ""), ("0",0,""),
    ("",None,None), ("garbage\n",None,None), (None,None,None)]:
    def test(raw=raw,code=code,output=output):
        _,api,_=env()
        actual=api.parse(raw)
        assert actual[0]==code, actual
        if output is not None: assert actual[1]==output
    check("process result "+repr(raw),test)

def import_case(kind="midi", raw="0\nOK", midi=True, enabled=True, continuation=False, start=0, length=4):
    _,api,state=env()
    state.raw=raw; state.midi=midi; state.kind=kind; state["import"]=enabled
    state.start=start; state.length=length
    result=api.compile(fixture,8 if continuation else None,1 if continuation else None)
    return api,state,result

def success():
    api,state,result=import_case()
    assert result==1, result
    assert state.cursor==9 and len(api.made())==1 and state.metadata=="newItem"
    assert state.tracks[2].id=="new" and state.tracks[3].id=="existingB"
    assert api.diag.lilypond_log=="OK"
check("zero exit imports MIDI between existing tracks and preserves cursor/GUIDs/log",success)

for name,kwargs in [
    ("nonzero compiler exit",dict(raw="1\ncompiler failure")),
    ("missing/timeout process response",dict(raw=None)),
    ("malformed process response",dict(raw="invalid")),
    ("missing MIDI file",dict(midi=False)),
    ("InsertMedia produces no tracks",dict(enabled=False)),
    ("empty imported track",dict(kind="empty")),
    ("non-MIDI imported item",dict(kind="audio"))]:
    def test(kwargs=kwargs):
        api,state,result=import_case(**kwargs)
        assert isinstance(result,tuple) and result[0] is None, result
        assert len(api.made())==0 and state.metadata==""
        assert len(state.tracks)==2
        assert state.cursor==9
        if "raw" in kwargs or "midi" in kwargs: assert state.imports==0
    check(name,test)

def continuation_ok():
    _,state,result=import_case(continuation=True,start=8)
    assert result==1 and state.undo==0
check("one-bar continuation at QN 8 accepted",continuation_ok)
for name,start,length in [("wrong continuation start",7,4),("wrong continuation length",8,8)]:
    def test(start=start,length=length):
        api,state,result=import_case(continuation=True,start=start,length=length)
        assert result[0] is None and state.undo==1 and len(state.tracks)==2
        assert len(api.made())==0 and state.cursor==9
    check(name+" rolled back",test)

def score_tests():
    _,api,_=env()
    score=api.score(fixture)
    assert "\\midi { }" in score
    assert api.score(score)==score
    assert api.score("no score")[0] is None
check("MIDI block insertion, idempotence and invalid input",score_tests)

updater=section("local function version_parts(v)", "local function utf8(cp)")
def update_env(tmp):
    r=LuaRuntime(unpack_returned_tuples=True)
    r.globals().TEST_ROOT=tmp.as_posix()
    r.execute("reaper={SetExtState=function() end,defer=function(f) deferred=f end}")
    api=r.execute(header+files+"""
local VERSION="1.0.55"
local SCRIPT_PATH=TEST_ROOT.."/installed.lua"
local SCRIPT_NAME="Composition Studio"
local WINDOW_STATE_KEY="WindowOpen"
local busy,open,restarting=false,true,false
local update_status=""
"""+updater+"""
return {newer=version_is_newer,complete=complete_update,
 status=function() return update_status,busy,open,restarting end}
""")
    return r,api
for name,version,status,body,expected in [
    ("update same version","1.0.55","200",None,"Bereits aktuell"),
    ("update older version","1.0.54","200",None,"Kein neueres"),
    ("update HTTP failure","1.0.56","503",None,"fehlgeschlagen"),
    ("update invalid payload","1.0.56","200","x"*1200,"ungültig"),
    ("update syntax failure","1.0.56","200",None,"Syntaxfehler"),
    ("update installation and backup","1.0.56","200",None,"installiert")]:
    def test(version=version,status=status,body=body,expected=expected,name=name):
        with tempfile.TemporaryDirectory(dir=root) as d:
            p=Path(d); old="previous original"; (p/"installed.lua").write_text(old)
            r,api=update_env(p)
            fresh=body or source.replace(source_version,version)
            if name=="update syntax failure": fresh+="\nlocal =\n"
            api.complete(status,fresh)
            actual=api.status()
            assert expected in actual[0],actual
            assert actual[1] is False
            if expected=="installiert":
                assert (p/"installed.lua").read_text(encoding="utf-8")==fresh
                assert (p/"installed.lua.backup").read_text()==old
                assert actual[2] is False and actual[3] is True
            else: assert (p/"installed.lua").read_text()==old
    check(name,test)

def rollback():
    with tempfile.TemporaryDirectory(dir=root) as d:
        p=Path(d); (p/"installed.lua").write_text("original")
        r,api=update_env(p)
        r.execute("""
local rename=os.rename
os.rename=function(a,b) if a:match("%.pending$") then return nil,"simulated failure" end; return rename(a,b) end
""")
        api.complete("200",source)
        assert "fehlgeschlagen" in api.status()[0]
        assert (p/"installed.lua").read_text()=="original"
        assert (p/"installed.lua.backup").read_text()=="original"
check("update install rename failure restores original",rollback)

# Execute the unchanged compiler command through the actual installed LilyPond.
exe=Path(os.getenv("LILYPOND_EXE", str(Path.home()/"Downloads/lilypond-2.26.0-mingw-x86_64/lilypond-2.26.0/bin/lilypond.exe")))
def real_compiler():
    r,api,state=env()
    def execute(command, timeout):
        done=subprocess.run(command,capture_output=True,timeout=timeout/1000)
        return str(done.returncode)+"\n"+(done.stdout+done.stderr).decode("utf-8",errors="replace")
    r.globals().reaper.GetExtState=lambda *args: str(exe)
    r.globals().reaper.ExecProcess=execute
    r.globals().reaper.file_exists=lambda p: Path(p).is_file()
    result=api.compile(fixture)
    assert result==1,result
    midi=root/"fixture_1.mid"
    assert midi.read_bytes().startswith(b"MThd")
    (root/"real-lilypond.log").write_text(api.diag.lilypond_log,encoding="utf-8")
if exe.is_file():
    check("actual LilyPond compiles MIDI; production importer with simulated REAPER API",real_compiler)
else:
    print("SKIP actual LilyPond compilation: set LILYPOND_EXE to an installed compiler")
scratch.cleanup()
print(len(results),"tests passed")
