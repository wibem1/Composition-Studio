"""Lossless musical transport, bounded expansion and exact legacy planning semantics."""
import math
import random
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
model=lua.execute((ROOT/'src/music/model.lua').read_text()).music_model
codec=model.compact
text=lua.execute((ROOT/'src/core/text.lua').read_text())
notes=lua.execute((ROOT/'src/music/cs_notes.lua').read_text())
programs=lua.execute((ROOT/'src/music/programs.lua').read_text())
planner=lua.execute((ROOT/'src/music/cs_plan.lua').read_text())(text.trim,notes.parse_notes,programs.program_for_name)

def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x) for x in v])
    return v

def expanded(s):
    value=codec.decode(s)
    assert isinstance(value,str),value
    return value

def invalid(s):
    value=codec.decode(s)
    assert isinstance(value,tuple) and value[0] is None,value

def state(s):
    result=planner.plan_composition(s,table([{'guid':'source','track':'src-track'}]),table([{'guid':'target-track','track':'target-track'}]),False)
    assert result[0] is not None,result
    jobs,maps,controls,*_=result
    def plain(v):
        if hasattr(v,'items'):
            d=dict(v.items())
            return [plain(d[i]) for i in range(1,len(d)+1)] if d and set(d)==set(range(1,len(d)+1)) else {k:plain(x) for k,x in d.items()}
        return v
    return plain(jobs),plain(maps),plain(controls)

# A complete 72-bar, three-voice work; this is one composition, no output windows.
compact='''CS2|1
T|s|new|-|Synth|80|0
T|b|new|-|Bass|38|1
T|d|new|-|Drums|0|9
P|theme|32|0,1,60,90;4,0.5,64,80;8,1,67,85;12,1,65,82
P|bass|4|0,0.75,36,90;1,0.75,36,88;2,0.75,43,86;3,0.75,36,89
P|kick|1|0,0.125,36,100
R|s|theme|0|9
R|b|bass|0|72
R|d|kick|0|288
N|s|287,1,72,95
END'''
cs=expanded(compact)
expected=[]
for name,program,ch,pattern,span,count in [
 ('Synth',80,0,[(0,1,60,90),(4,.5,64,80),(8,1,67,85),(12,1,65,82)],32,9),
 ('Bass',38,1,[(0,.75,36,90),(1,.75,36,88),(2,.75,43,86),(3,.75,36,89)],4,72),
 ('Drums',0,9,[(0,.125,36,100)],1,288)]:
    values=[f'{at+i*span:g},{duration:g},{pitch},{vel},{ch}' for i in range(count) for at,duration,pitch,vel in pattern]
    if name=='Synth':values.append('287,1,72,95,0')
    expected.append(f'CS|new|-|{name}|{program}|'+ ';'.join(values))
legacy='\n'.join(expected)
assert state(cs)==state(legacy)
assert len(compact)<len(legacy)*.1
print(f'PASS 72-bar/three-voice fixture: {len(legacy)} legacy -> {len(compact)} compact characters ({100*(1-len(compact)/len(legacy)):.1f}% less), identical expanded operations')

# Non-repeating material can use only explicit notes; patterns are never mandatory.
unique=[(i/7,.12345,48+i%40,40+i%80,2 if i%5 else 3) for i in range(500)]
compact_unique='CS2|1\nT|v|new|-|Voice|40|2\nN|v|'+ ';'.join(','.join(map(str,n[:4]))+(','+str(n[4]) if n[4]!=2 else '') for n in unique)+'\nEND'
legacy_unique='CS|new|-|Voice|40|'+ ';'.join(','.join(map(str,n)) for n in unique)
assert state(expanded(compact_unique))==state(legacy_unique)
print(f'PASS 500 non-repeating expressive notes/mixed channels: {len(legacy_unique)} -> {len(compact_unique)} wire characters, identical operations without patterns')

# All operation kinds, source bindings, per-note channels, controllers and metadata.
for kind,source in [('new','-'),('revised','source'),('target','source'),('track','target-track')]:
    wire=f'''CS2|1
T|v|{kind}|{source}|Voice|40.0|2.0
N|v|0.33333,0.12345,60.0,90.0;2,0.25,64,85,3
C|v|0.5|2.0|cc|11.0|90.0
C|v|0.75|2|program|41
U|source
CSMETA|tempo|0|120
CSMETA|timesig|0|4|4
END'''
    expected=f'''CS|{kind}|{source}|Voice|40|0.33333,0.12345,60,90,2;2,0.25,64,85,3
CSCTRL|Voice|0.5|2|cc|11|90
CSCTRL|Voice|0.75|2|program|41
CS|unchanged|source
CSMETA|tempo|0|120
CSMETA|timesig|0|4|4'''
    assert state(expanded(wire))==state(expected)
# A sustain/legato note may ring beyond a pattern span; expansion does not clip it.
assert '0,2,60,90,0;1,2,60,90,0' in expanded('CS2|1\nT|v|new|-|Voice|0|0\nP|p|1|0,2,60,90\nR|v|p|0|2\nEND')
# The existing planner still rejects unknown source/target identities after transport decode.
for kind in ['revised','target','track']:
    s=expanded(f'CS2|1\nT|v|{kind}|unknown|Voice|0|0\nN|v|0,1,60,90\nEND')
    assert planner.plan_composition(s,table([]),table([]),False)[0] is None

# Decimal spelling changes do not change numerical values, including exponent inputs.
rng=random.Random(553)
for n in [0,1e-20,1e-9,.1,.3333333333333333,1000000]+[rng.random()*1e5 for _ in range(300)]:
    spelling=codec.number(n)
    assert 'e' not in spelling.lower() and float(spelling)==n,(n,spelling)
for value in ['nan','inf','1e309','0x1','1e-325']:
    invalid(f'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,{value},60,90\nEND')
for s in [compact.replace('\nEND',''),compact+'\nN|s|0,1,60,90',
 'CS2|1\nT|v|new|-|Voice|0|0\nR|v|missing|0|2\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nP|p|1|0,1,60,90\nR|v|p|0|20001\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,1,128,90\nEND',
 'CS2|1\nT|v|new|-|Voice|0|16\nN|v|0,1,60,90\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,0,60,90\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,1,60,90;\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,1,60,90\nT|v|new|-|Other|0|0\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nP|p|1|1,1,60,90\nR|v|p|0|2\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nN|v|0,1,60,90\nC|v|0|0|cc|128|10\nEND',
 'CS2|1\nT|v|new|-|Voice|0|0\nEND', 'CS2|1\nEND']:
    invalid(s)
invalid('CS2|1\n'+' '*2000001+'END')
invalid('CS2|1\nT|v|new|-|Voice|0|0\n'+'\n'.join(f'P|p{i}|1|0,1,60,90' for i in range(129))+'\nN|v|0,1,60,90\nEND')

# Entire expressive source survives unchanged at the previous prompt's 5-decimal precision.
items=[];legacy_rows=[];expected_source=[]
for i,count in enumerate([415,134]):
    ns=[];guid='{'+str(i)*36+'}'
    for j in range(count):
        n={'start_qn':1.50208+j/8,'duration_qn':.25000 if j%2 else .93751,'pitch':48+j%30,'velocity':50+j%65,'channel':i}
        ns.append(n);legacy_rows.append(f'N {guid} {n["start_qn"]:.5f} {n["duration_qn"]:.5f} {n["pitch"]} {n["velocity"]} {n["channel"]}')
        expected_source.append((i+1,float(f'{n["start_qn"]:.5f}'),float(f'{n["duration_qn"]:.5f}'),n['pitch'],n['velocity'],n['channel']))
    items.append({'guid':guid,'notes':ns})
short=codec.input(table(items));restored=[];source=None
for line in short.splitlines():
    if line.startswith('NOTES ITEM '):source=int(line.split()[-1])
    elif source is not None and line:
        for token in line.split(';'):restored.append((source,*map(float,token.split(','))))
assert restored==expected_source and all(it['guid'] not in short for it in items)
old='\n'.join(legacy_rows)
print(f'PASS synthetic 549-note input: {len(old)} -> {len(short)} characters, all source/value/channel/order tuples identical')
print('PASS compact MIDI transport: 72 bars, exact legacy operations, source protections, 306 numeric round trips, malformed/truncated/oversized expansion rejected; no provider requests')
