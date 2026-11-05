"""Compare the pure planning boundary and host commit with the old implementation."""
from pathlib import Path
import re
import subprocess

from lupa.lua54 import LuaRuntime
from build_studio import ROOT, render

old = subprocess.check_output(['git', 'show', 'b35301c:Composition Studio.lua'], cwd=ROOT, text=True)
new = render()
signature = 'local function apply_composition(text,items,tracks,force_single_piano)'


def commit(source):
    return source[source.index(signature):source.index('export_last_midi=function()')]


def environment(source, use_module):
    lua = LuaRuntime(unpack_returned_tuples=True)
    # All native writes are logged; validation failures must never reach them.
    lua.execute('''
events={};fail_midi=false;fail_track=false
local function log(...) local values={...};for i,v in ipairs(values)do values[i]=tostring(v)end;events[#events+1]=table.concat(values,":") end
reaper={
 Undo_BeginBlock2=function()log("begin")end,
 Undo_EndBlock2=function(_,label)log("end",label)end,
 Undo_DoUndo2=function()log("rollback")end,
 UpdateArrange=function()log("arrange")end,
 CountTempoTimeSigMarkers=function()return 2 end,
 DeleteTempoTimeSigMarker=function(_,i)log("delete-map",i)end,
 Master_GetTempo=function()return 120 end,
 TimeMap2_QNToTime=function(_,qn)return qn/2 end,
 SetTempoTimeSigMarker=function(_,_,time,_,_,bpm,num,den)log("map",time,bpm,num,den)end,
 GetMediaTrackInfo_Value=function()return 1 end,
 GetActiveTake=function(item)return item.name end,
 MIDI_GetPPQPosFromProjTime=function(_,t)return t*960 end,
 MIDI_InsertCC=function(_,_,_,ppq,kind,ch,a,b)log("cc",ppq,kind,ch,a,b)end,
 MIDI_Sort=function(take)log("sort",take)end}
function create_track(name,index)log("track",name,index or "append");if fail_track then error("track failure")end;return name end
function existing_program(track)if track=="target-track"then return 73 end end
function create_midi(track,name,notes,program)
 log("midi",track,name,program,#notes)
 for _,n in ipairs(notes)do log("note",n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel)end
 if fail_midi then return nil end;return {name=name}
end
items={{guid="src1",track="source-track"}}
tracks={{guid="track1",track="target-track"}}
''')
    text = lua.execute((ROOT / 'src/core/text.lua').read_text())
    notes = lua.execute((ROOT / 'src/music/cs_notes.lua').read_text())
    programs = lua.execute((ROOT / 'src/music/programs.lua').read_text())
    lua.globals().trim = text.trim
    lua.globals().parse_notes = notes.parse_notes
    lua.globals().program_for_name = programs.program_for_name
    if use_module:
        plan = lua.execute((ROOT / 'src/music/cs_plan.lua').read_text())(text.trim, notes.parse_notes, programs.program_for_name)
        lua.globals().plan_composition = plan.plan_composition
    apply = lua.execute(commit(source) + '\nreturn apply_composition')
    return lua, apply


cases = [
    ('CS|new|-|Cello|0|0,1,48,80,0', False),
    ('CS|revised|src1|Cello|42|0,1,48,80,0', False),
    ('CS|target|src1|Cello|42|0,1,48,80,0', False),
    ('CS|track|track1|Flöte|1|0,1,72,80,1', False),
    ('CS|unchanged|src1', False),
    ('CS|new|-|Right|0|0,1,60,80,0\nCS|new|-|Left|0|0,1,48,70,1', True),
    ('CS|new|-|Cello|42|0,1,48,80,0\nCS|new|-|Cello|42|1,1,50,80,0\nCSCTRL|Cello|0|0|cc|11|90', False),
    ('CSMETA|tempo|0|96\nCSMETA|timesig|0|3|4\nCSMETA|tempo|6|72\nCS|new|-|Cello|42|0,1,48,80,0\nCSCTRL|Cello|0|0|program|42', False),
    ('CS|new|-|Cello|42|0,1,48,80,0\nCSCTRL|Unknown|0|0|cc|11|90', False),
    ('CS|target|missing|Cello|42|0,1,48,80,0', False),
    ('CS|track|missing|Cello|42|0,1,48,80,0', False),
    ('CS|new|wrong|Cello|42|0,1,48,80,0', False),
    ('CS|new|-|Cello|42|0,-1,48,80,0', False),
    ('CS|new|-|Cello|128|0,1,48,80,0', False),
    ('CS|revised|src1|Cello|42|0,1,48,80,0', True),
    ('CS|new|-|Cello|42|0,1,48,80,0\nCSCTRL|Cello|0|0|cc|11|128', False),
    ('CSMETA|tempo|0|-1', False),
    ('CSMETA|timesig|0|0|4', False),
    ('invalid response', False),
    ('', True),
]


def run(source, use_module, payload, piano, failure):
    lua, apply = environment(source, use_module)
    lua.globals().fail_midi = failure == 'midi'
    lua.globals().fail_track = failure == 'track'
    result = apply(payload, lua.globals()["items"], lua.globals()["tracks"], piano)
    if isinstance(result, tuple):
        made, error = result
        # Debug trace locations differ when a pure function moves into a module.
        error = str(error).split('\nstack traceback:')[0]
        error = re.sub(r'\[string "[^"]*"\]:\d+: ', '', error)
        outcome = (None, error)
    else:
        outcome = (len(result), None)
    events = [value for _, value in sorted(lua.globals().events.items())]
    return outcome, events


for payload, piano in cases:
    for failure in ('none', 'midi', 'track'):
        before = run(old, False, payload, piano, failure)
        after = run(new, True, payload, piano, failure)
        assert before == after, (payload, piano, failure, before, after)
        if after[0][0] is None and not any(event.startswith('begin') for event in after[1]):
            assert not after[1], 'Validation wrote native data'

print(f'PASS {len(cases)*3} differential planning/commit cases: source targets, variants, piano merge, tempo/CC, errors and rollback')
