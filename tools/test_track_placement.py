"""Run production commit against shifting REAPER track identities, without AI calls."""
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def setup(choice=6, empty=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
local function track(name)return {name=name}end
order={track("Before"),track("Right"),track("Between"),track("Left"),track("After")}
right,left=order[2],order[4]
items={{guid="right",track=right},{guid="left",track=left}}
tracks={};writes=0;questions=0;undos=0;rolled_back=false;fail=false
reaper={
 ShowMessageBox=function(text,title,buttons)
  assert(writes==0 and undos==0,"Question must precede project changes")
  assert(buttons==3 and text:find("Ja:",1,true) and text:find("Nein:",1,true) and text:find("Abbrechen:",1,true))
  questions=questions+1;return choice
 end,
 GetMediaTrackInfo_Value=function(tr,key)
  assert(key=="IP_TRACKNUMBER");for i,t in ipairs(order)do if t==tr then return i end end;error("Missing track")
 end,
 Undo_BeginBlock2=function()undos=undos+1;backup={};for i,t in ipairs(order)do backup[i]=t end end,
 Undo_EndBlock2=function()end,
 Undo_DoUndo2=function()order=backup;rolled_back=true end,
 UpdateArrange=function()end,
 GetActiveTake=function()return nil end,
 CountTempoTimeSigMarkers=function()return 0 end,
 Master_GetTempo=function()return 120 end,
 TimeMap2_QNToTime=function(_,qn)return qn/2 end,
 SetTempoTimeSigMarker=function()writes=writes+1 end}
''')
    lua.globals().choice = choice
    text = lua.execute((ROOT / 'src/core/text.lua').read_text())
    notes = lua.execute((ROOT / 'src/music/cs_notes.lua').read_text())
    programs = lua.execute((ROOT / 'src/music/programs.lua').read_text())
    planner = lua.execute((ROOT / 'src/music/cs_plan.lua').read_text())(
        text.trim, notes.parse_notes, programs.program_for_name)
    lua.globals().plan_composition = planner.plan_composition
    # Helpers and production commit share a Lua chunk so native mocks stay local.
    source = (ROOT / 'src/host/reaper/commit.lua').read_text()
    source = source[source.index('local function apply_composition'):source.index('export_last_midi=function()')]
    helpers = '''local function create_track(name,index)
 writes=writes+1;local t={name=name};table.insert(order,(index or #order)+1,t);return t end
local function existing_program()return nil end
local function create_midi(tr,name,notes,program)
 writes=writes+1;if fail then return nil end
 assert(#notes==1 and notes[1].pitch==60);return {track=tr,name=name} end
'''
    apply = lua.execute(helpers + source + '\nreturn apply_composition')
    if empty:
        lua.execute('items={};order={}')
    return lua, lambda payload: apply(payload, lua.globals()["items"], lua.globals()["tracks"], False)


def job(kind, guid, name):
    return f'CS|{kind}|{guid}|{name}|0|0,1,60,90,0'


def names(lua):
    return [t.name for _, t in sorted(lua.globals().order.items())]


payload = '\n'.join([job('revised','right','Synth'), job('revised','left','Bass'), job('new','-','Drums')])
lua, apply = setup(6)
assert len(apply(payload)) == 3
assert names(lua) == ['Before','Right','Synth [Variante]','Between','Left','Bass [Variante]','After','Drums']
assert lua.globals().questions == 1 and lua.globals().undos == 1
lua, apply = setup(7)
assert len(apply(payload)) == 3
assert names(lua) == ['Before','Right','Between','Left','Synth [Variante]','Bass [Variante]','Drums','After']
# Block starts below the last bound original, even if jobs are reversed and source tracks have gaps.
lua, apply = setup(7)
assert len(apply('\n'.join([job('revised','left','Bass'),job('new','-','Drums'),job('revised','right','Synth')]))) == 3
assert names(lua) == ['Before','Right','Between','Left','Bass [Variante]','Drums','Synth [Variante]','After']
# Multiple variants retain their response order beneath the same original.
lua, apply = setup(6)
assert len(apply('\n'.join([job('revised','right','A'),job('revised','right','B')]))) == 2
assert names(lua)[1:4] == ['Right','A [Variante]','B [Variante]']
# Track-only context anchors additional voices; no source item is required.
lua, apply = setup(7);lua.execute('items={};tracks={{guid="left-track",track=left}}')
assert len(apply(job('new','-','Drums'))) == 1
assert names(lua) == ['Before','Right','Between','Left','Drums','After']
# Cancel does not open an undo block or write MIDI, tracks or tempo markers; retry is possible.
lua, apply = setup(2)
before = names(lua)
result = apply('CSMETA|tempo|0|96\n'+payload)
assert result[0] is None and result[2] == 'cancelled'
assert names(lua) == before and lua.globals().writes == 0 and lua.globals().undos == 0
lua.globals().choice = 7
assert len(apply(payload)) == 3
# Existing target actions are never relocated; a mixed result only places newly created tracks.
lua, apply = setup(7)
result = apply('\n'.join([job('new','-','Drums'),job('target','right','Existing')]))
assert len(result)==2 and lua.eval("function(a,b)return a==b end")(result[2].track, lua.globals().right)
assert names(lua) == ['Before','Right','Between','Left','Drums','After']
lua, apply = setup(2)
assert len(apply(job('target','right','Existing'))) == 1
assert lua.globals().questions == 0
# Pure new projects and invalid proposals do not ask irrelevant placement questions.
lua, apply = setup(2,empty=True)
assert len(apply(job('new','-','Synth'))) == 1 and lua.globals().questions == 0
lua, apply = setup(7)
assert apply(job('revised','missing','Bad'))[0] is None
assert lua.globals().questions == 0 and lua.globals().writes == 0
# MIDI failure still rolls back all newly created tracks in block mode.
lua, apply = setup(7);before=names(lua);lua.globals().fail=True
assert apply(payload)[0] is None
assert lua.globals().rolled_back and names(lua) == before
print('PASS track placement: individual/block, gaps, response order, repeated sources, track-only context, cancel/retry, existing targets, invalid input and rollback')
