"""Exercise standalone portable modules, dependency contracts and artifact parity."""
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

from lupa.lua54 import LuaRuntime
from build_studio import ROOT, artifacts, inline, load_manifest, render

manifest = load_manifest()
subprocess.run([sys.executable, str(ROOT / 'tools/build_studio.py'), '--check'], check=True)

# The full extraction must preserve the audited M2 runtime byte for byte.
# Later deliberate behavior changes require a reviewed update of this reference.
baseline = subprocess.check_output(['git', 'show', 'b35301c:Composition Studio.lua'], cwd=ROOT).decode('utf-8')
runtime = render()
# Feature integration is explicit; the pre-existing 1.1.11 musical paths stay intact.
legacy_runtime = runtime
for unit in manifest['units']:
    if unit['id'] in ('music/model', 'music/memory', 'workflow/music_workspace'):
        legacy_runtime = legacy_runtime.replace(inline(unit), '', 1)
legacy_runtime = re.sub(r'-- BEGIN MUSIC WORKSPACE ([A-Z]+)\n.*?-- END MUSIC WORKSPACE \1\n', '', legacy_runtime, flags=re.S)
legacy_runtime = legacy_runtime.replace('if stage=="engine_json" or stage=="song_construction" then', 'if stage=="engine_json" then', 1)
legacy_runtime = legacy_runtime.replace('add("Arbeitsstand",r.song_summary or workflow_core.readable(r.raw_response))', 'add("Arbeitsstand",workflow_core.readable(r.raw_response))', 1)
planner = next(unit for unit in manifest['units'] if unit['id'] == 'music/cs_plan')
signature = 'local function apply_composition(text,items,tracks,force_single_piano)'
commit = ' reaper.Undo_BeginBlock2(0); local made'
old_prefix = baseline[baseline.index(signature):baseline.index(commit, baseline.index(signature))]
assert inline(planner) == old_prefix.replace('local function apply_composition(', 'local function plan_composition(', 1) + ' return jobs,musical_map,controls,src,targets\nend\n\n'
restored = legacy_runtime.replace(inline(planner), '', 1)
first = restored.index(signature)
last = restored.index(commit, first)
assert restored[first:last] == signature + ' local jobs,musical_map,controls,src,targets=plan_composition(text,items,tracks,force_single_piano); if not jobs then return nil,musical_map end;'
restored = restored[:first] + old_prefix + restored[last:]
# Release metadata may change, but header and actual runtime must agree.
release = re.search(r'^-- @version (\S+)', runtime, re.M).group(1)
assert re.search(r'^local VERSION="([^"]+)"', runtime, re.M).group(1) == release
old_release = re.search(r'^-- @version (\S+)', baseline, re.M).group(1)
restored = restored.replace('-- @version ' + release + '\n', '-- @version ' + old_release + '\n', 1)
restored = restored.replace('local VERSION="' + release + '"', 'local VERSION="' + old_release + '"', 1)
assert restored == baseline, 'Unexpected runtime change outside planner extraction and release metadata'

lua = LuaRuntime(unpack_returned_tuples=True)
load_portable = lua.eval('''function(source)
 local allowed={assert=assert,error=error,ipairs=ipairs,pairs=pairs,pcall=pcall,
 tostring=tostring,tonumber=tonumber,type=type,math=math,string=string,table=table,
 _G={utf8=utf8}}
 local env=setmetatable({}, {__index=function(_,key)
  assert(allowed[key]~=nil, "Undeclared dependency: "..tostring(key));return allowed[key]
 end,__newindex=function(_,key)error("Global write: "..tostring(key))end})
 return assert(load(source,"@portable-module","t",env))()
end''')
modules = {}
for unit in manifest['units']:
    if unit['kind'] in ('portable', 'factory', 'version'):
        modules[unit['id']] = load_portable((ROOT / unit['path']).read_text())

text = modules['core/text']
assert text.trim('  probe \n')[0] == 'probe'
assert text.safe_work_title('../Probe: A/B') == '-Probe- A-B'
assert modules['core/version'].is_newer('1.0-test10', '1.0-test2')
request = modules['music/continuation_request']
assert request.continuation_bars('Verlängere um sechzehn Takte') == 16
assert request.request_transition('Verlängere um 16 Takte und gestalte die letzten zwei Takte neu') == 2
assert request.request_transition('Verlängere um 16 Takte und erhalte den Schluss') == 0
assert modules['music/cs_notes'].parse_notes('0,1,60,90,0')[1].pitch == 60
assert modules['music/cs_notes'].parse_notes('0,-1,60,90,0') is None
assert modules['music/programs'].program_for_name('Violoncello', 0) == 42
assert modules['music/programs'].program_for_name('unbekannt', 7) == 7

decoder = modules['music/json_codec'].decode_engine_json
score = modules['music/json_score'](decoder)
fixture = {'title': 'ä', 'bpm': 96, 'timeSignature': [3, 4],
           'tempoEvents': [{'at': 6, 'bpm': 72}],
           'pedalEvents': [{'at': 0, 'value': 127}, {'at': 3, 'value': 0}],
           'tracks': [{'name': 'Cello', 'program': 42, 'channel': 1,
                       'notes': [[0, 1.5, 48, 80]],
                       'ccEvents': [{'at': 0, 'controller': 11, 'value': 90}]}]}
decoded = decoder(json.dumps(fixture))
assert decoded.title == 'ä'
cs = score.engine_translate_json(json.dumps(fixture))
for expected in ('CSMETA|timesig|0|3|4', 'CSMETA|tempo|6.000000|72.000000',
                 'CSCTRL|Cello|0.000000|1|cc|64|127',
                 'CSCTRL|Cello|0.000000|1|cc|11|90',
                 '0.000000,1.500000,48,80,1'):
    assert expected in cs, (expected, cs)
fixture['tracks'][0]['notes'][0][2] = 128
assert score.engine_translate_json(json.dumps(fixture))[0] is None
core = modules['shared/workflow'].workflow_core
assert core.advance('draft', 'propose') == 'ready'
assert core.advance('ready', 'apply') == 'applied'
assert core.readable(r'$\sharp$') == '♯'

# All factory dependencies are supplied as ports; no REAPER, IO or model call.
ports = modules['music/prompts'](
    lua.eval('function() return "SNAPSHOT" end'),
    modules['music/cs_notes'].parse_notes, text.trim)
assert 'SNAPSHOT' in ports.analysis_prompt('Analyse', lua.table(), lua.table())
assert ports.check_translation_chunk('CS|new|-|Cello|42|0,1,48,80,1')[0]
patch = modules['editing/selected_notes_prompt'](
    lua.eval('function() return "READ ONLY REFERENCE" end'))
assert 'READ ONLY REFERENCE' in patch.notation_patch_prompt('Probe', lua.table())
assert '\\score' in modules['music/lilypond_prompt'].lily_composition_prompt('Probe')
assert modules['ai/response'].read_json_string('"\\u00e4"', 1) == 'ä'
labels = lua.table_from({'low': 'Kurz', 'medium': 'Mittel', 'high': 'Hoch', 'auto': 'Automatisch'})
reasoning = modules['ai/reasoning'](labels)
assert '"effort":"medium"' in reasoning.reasoning_parameters('openai', 'test', 'medium')[0]
assert reasoning.reasoning_parameters('openai', 'test', 'auto') == ('', 'provider_default')
assert 'Probe' in modules['music/json_direct_prompt'].engine_json_prompt('Probe')
assert 'Rahmen' in modules['music/json_framework_prompts'].composed_json_prompt('Probe', 'Rahmen')
continuation = modules['music/continuation_prompt'](lua.eval('function() return "SOURCE EXCERPT" end'))
assert 'SOURCE EXCERPT' in continuation.continuation_prompt('Probe', lua.table(), lua.table(), 8, 16)
plan = modules['music/cs_plan'](text.trim, modules['music/cs_notes'].parse_notes,
                              modules['music/programs'].program_for_name)
jobs, musical_map, controls, sources, targets = plan.plan_composition(
    cs, lua.table(), lua.table(), False)
assert len(jobs) == 1 and jobs[1].notes[1].pitch == 48 and len(controls) == 3
print(f'PASS {len(modules)} standalone modules without REAPER, files, network or global writes')

original = artifacts()
assert original == artifacts(), 'Nondeterministic build'
with TemporaryDirectory() as temporary:
    root = Path(temporary)
    shutil.copytree(ROOT / 'src', root / 'src')
    assert artifacts(root) == original
    # Editing a real source changes runtime and both installers, not a dead copy.
    module = root / 'src/core/version.lua'
    module.write_text(module.read_text().replace('Pure version comparison', 'Changed development source'))
    updated = artifacts(root)
    assert all(updated[name] != original[name] for name in original)
    unknown = root / 'src/unlisted.lua'
    unknown.write_text('return {}\n')
    try:
        render(root)
        raise AssertionError('Unlisted module accepted')
    except ValueError as error:
        assert 'Unlisted' in str(error)
    unknown.unlink()
    data = json.loads((root / 'src/manifest.json').read_text())
    data['units'][0]['requires'] = ['not_declared']
    (root / 'src/manifest.json').write_text(json.dumps(data))
    try:
        render(root)
        raise AssertionError('Missing dependency accepted')
    except ValueError as error:
        assert 'Imports before declaration' in str(error)
print('PASS full-source coverage, dependency failures, source-to-artifact propagation and deterministic build')
