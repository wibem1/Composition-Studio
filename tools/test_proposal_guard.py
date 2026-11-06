"""Saved proposals survive arrangement selection changes, never real source edits."""
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory
from lupa.lua54 import LuaRuntime
from build_studio import ROOT,inline,load_manifest

units={u['id']:u for u in load_manifest()['units']}
def unit(name):return inline(units[name])
old=subprocess.check_output(['git','show','4da4862a10223ca6255f57ffb5c28aac4c1c925b:src/workflow/proposals.lua'],cwd=ROOT,text=True)
old_guard=old[old.index('function workflow_adapter.guard()'):old.index('function workflow_adapter.history_path()')].replace('workflow_adapter.guard()','workflow_adapter.legacy_guard()',1)

def setup(folder):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().ROOT=folder
    lua.globals().MKDIR=lambda p:Path(p).mkdir(parents=True,exist_ok=True)
    code=r'''
local EXT_SECTION="guard-test";local TITLE_KEY="title";local provider="test";local model="test"
local busy=false;local update_status="";local work_title="";local input="";local last_made={};local swam_last_made={}
local messages={};local diagnostics={};local saved={};local writes=0;local deleted=false;local tempo=120;local track_name="Source";local marker=false
local chunk="<ITEM\nPOSITION 1\nLENGTH 144\nSEL 1\nMUTE 0\n<SOURCE MIDI\nHASDATA 1 960 QN\nE 0 90 3c 50\nSEL 1\n>\n>\n"
local reaper={GetResourcePath=function()return ROOT end,RecursiveCreateDirectory=function(p)MKDIR(p)end,
 GetProjExtState=function(_,_,k)return 1,saved[k] or ""end,SetProjExtState=function(_,_,k,v)saved[k]=v;return 1 end,
 genGuid=function()return "project-one"end,EnumProjects=function()return 1 end,
 CountTracks=function()return 1 end,GetTrack=function()return 1 end,GetTrackName=function()return true,track_name end,
 CountTrackMediaItems=function()return deleted and 0 or 1 end,GetTrackMediaItem=function()return 1 end,
 GetItemStateChunk=function()return true,chunk end,Master_GetTempo=function()return tempo end,
 CountTempoTimeSigMarkers=function()return marker and 1 or 0 end,GetTempoTimeSigMarker=function()return true,0,0,0,120,3,4,false end,
 CountMediaItems=function()return deleted and 0 or 1 end,GetMediaItem=function()return 1 end,
 GetActiveTake=function()return 1 end,GetMediaItem_Track=function()return 1 end}
local function add(_,s)messages[#messages+1]=s end
local function diag_set(k,v)diagnostics[k]=v end
local function item_guid()return "item1"end
local function track_guid()return "track1"end
local function read_file(p)local f=io.open(p,"rb");if not f then return nil end;local s=f:read("*a");f:close();return s end
local function write_file(p,s)local f=io.open(p,"wb");if not f then return false end;f:write(s);f:close();return true end
local function apply_composition()if CANCEL_APPLY then return nil,"Einfügen abgebrochen; der Vorschlag bleibt erhalten.","cancelled" end;writes=writes+1;return {1}end
local function initialize_halion_project()end
local function launch()error("Recovery must never call a provider")end
local function get_key()error("Recovery must not request an API key")end
'''
    for name in ['shared/workflow','core/text','music/json_codec','music/model','workflow/proposals','workflow/apply_review']:
        code+=unit(name)
    code+=old_guard
    code+=r'''
return {a=workflow_adapter,diagnostics=diagnostics,messages=messages,
 offer=function()
  local wire="CS2|1\nT|v|revised|item1|Synth|80|0\nP|p|4|0,1,60,90\nR|v|p|1|36\nEND"
  workflow_adapter.offer("composition",wire,{request="Techno cover",full={{guid="item1"}},workflow_guard=workflow_adapter.legacy_guard()})
 end,
 select=function(value)chunk=chunk:gsub("\nSEL [01]\n","\nSEL "..value.."\n",1)end,
 change=function(what)
  if what=="position" then chunk=chunk:gsub("POSITION 1","POSITION 2")
  elseif what=="length" then chunk=chunk:gsub("LENGTH 144","LENGTH 145")
  elseif what=="pitch" then chunk=chunk:gsub("3c 50","3d 50")
  elseif what=="velocity" then chunk=chunk:gsub("3c 50","3c 60")
  elseif what=="nested_selection" then chunk=chunk:gsub("3c 50\nSEL 1","3c 50\nSEL 0")
  elseif what=="mute" then chunk=chunk:gsub("MUTE 0","MUTE 1")
  elseif what=="tempo" then tempo=121
  elseif what=="marker" then marker=true
  elseif what=="name" then track_name="Renamed"
  elseif what=="delete" then deleted=true end
 end,
 writes=function()return writes end,normalize=workflow_adapter.normalize_guard}
'''
    return lua,lua.execute(code)

# Cancelling placement retains the paid proposal, including across reload, without writes or retry calls.
with TemporaryDirectory() as folder:
    lua,api=setup(folder);api.offer();lua.globals().CANCEL_APPLY=True
    api.a.apply()
    assert api.writes()==0 and api.a.pending.state=='ready'
    assert api.diagnostics.apply_result.startswith('CANCELLED')
    api.a.load();assert api.a.pending.state=='ready'
    lua.globals().CANCEL_APPLY=False;api.a.apply()
    assert api.writes()==1 and api.a.pending is None

with TemporaryDirectory() as folder:
    lua,api=setup(folder);api.offer()
    assert api.a.pending is not None and api.a.pending.source_guard==api.a.legacy_guard()
    api.select(0)
    assert api.a.pending.source_guard!=api.a.guard()
    assert api.normalize(api.a.pending.source_guard)==api.normalize(api.a.guard())
    api.a.load();assert api.a.pending is not None # latest ready record restored automatically
    api.a.apply();assert api.writes()==1 and api.diagnostics.apply_guard_status=='MATCH'
    assert api.diagnostics.apply_result.startswith('SUCCESS')
    api.a.load();assert api.a.pending is None
    api.a.pending=api.a.records[1];api.a.apply();assert api.writes()==1
    assert 'ERROR' in api.diagnostics.apply_result
# A genuinely new Lua session can recover the old, already paid proposal from disk.
with TemporaryDirectory() as folder:
    lua,api=setup(folder);api.offer()
    lua,api=setup(folder);api.select(0)
    assert api.a.pending is not None
    api.a.apply();assert api.writes()==1
for mutation in ['position','length','pitch','velocity','nested_selection','mute','tempo','marker','name','delete']:
    with TemporaryDirectory() as folder:
        lua,api=setup(folder);api.offer();api.select(0);api.change(mutation)
        api.a.apply()
        assert api.writes()==0,mutation
        assert api.diagnostics.apply_guard_status=='SOURCE_CHANGED',mutation
        assert api.diagnostics.apply_result.startswith('ERROR')
        assert 'Abweichung' in api.diagnostics.apply_guard_difference
        assert api.a.pending.state=='ready' # result retained, not silently discarded
        assert '3d 50' not in api.diagnostics.apply_guard_difference
        assert 'Renamed' not in api.diagnostics.apply_guard_difference
# Only the exact native top-level SEL 0/1 is ignored; nested or unknown data stays protected.
with TemporaryDirectory() as folder:
    lua,api=setup(folder)
    a='<ITEM\nSEL 1\n<SOURCE MIDI\nSEL 1\n>\n>\n'
    b='<ITEM\nSEL 0\n<SOURCE MIDI\nSEL 1\n>\n>\n'
    assert api.normalize(a)==api.normalize(b)
    assert api.normalize(a)!=api.normalize(b.replace('MIDI\nSEL 1','MIDI\nSEL 0'))
    assert api.normalize('<ITEM\nSEL 2\n>')!=api.normalize('<ITEM\nSEL 0\n>')
    assert api.normalize('ORIGINAL')=='ORIGINAL'
print('PASS saved 1.4.0 raw-guard proposal after item selection and fresh restart, zero provider calls, apply once; real MIDI/position/length/mute/identity/tempo changes blocked with diagnosis')

# Execute the actual UI loop with a scrolled-conversation stand-in; action must be outside it.
ui=(ROOT/'src/ui/reaper.lua').read_text()
status=ui[ui.index('local function draw_workflow_status()'):ui.index('local function draw_history()')]
loop=ui[ui.index('local function loop()'):]
for state in ['ready','applied']:
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().STATE=state
    result=lua.execute(r'''
local ctx=0;local VERSION="test";local open=true;local restarting=false;local busy=false;local font_size=14;local input="";local update_status="saved";local reasoning_mode="medium"
local REASONING_LABELS={medium="Mittel"};local EXT_SECTION="test";local buttons={};local inside=false
local workflow_adapter={pending={stage="composition",state=STATE},labels={composition="Überarbeitung"},states={ready="Vorschlag"},models={poll=function()end},apply=function()end}
local function noop()end
local focused_or_last_notation_editor,poll_update,poll_job,finish_save_panel,check_project_change=noop,noop,noop,noop,noop
local selected_items,selected_tracks=function()return {}end,function()return {}end
local push_font,pop_font=function()return false end,noop
local draw_model_picker,draw_history,remember_closed,set_font_size,submit=noop,noop,noop,noop,noop
local function text_context_menu(_,s)return s end
local costs={amount=function()return "0"end}
local reaper={ImGui_Begin=function()return true,true end,ImGui_GetContentRegionAvail=function()return 360,480 end,
 ImGui_Button=function(_,label)buttons[#buttons+1]={label=label,inside=inside};return false end,
 ImGui_GetStyleVar=function()return 4,4 end,ImGui_GetFrameHeight=function()return 20 end,
 ImGui_BeginChild=function()inside=true;return true end,ImGui_EndChild=function()inside=false end,
 ImGui_BeginPopup=function()return false end,ImGui_InputTextMultiline=function()return false,""end,defer=noop}
setmetatable(reaper,{__index=function()return function()return 0 end end})
''' + status + loop + '\nreturn buttons')
    matches=[v for v in result.values() if v.label=='Änderungen anwenden']
    assert (len(matches)==1 and not matches[0].inside) if state=='ready' else not matches
print('PASS actual UI result/apply control outside scrolling chat; already applied results have no apply button')
