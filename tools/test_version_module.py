"""Compare the module and shipped copies to the original production comparator."""
from pathlib import Path
import subprocess
import sys
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = '4743491d7081cf009f144a88b70c373047febeab'
old = subprocess.check_output(['git', 'show', BASE + ':Composition Studio.lua'], cwd=ROOT, text=True)
legacy = old[old.index('local function version_parts(v)'):old.index('local update_job=nil')]
reference = LuaRuntime(unpack_returned_tuples=True).execute(
    legacy + '\nreturn {parts=version_parts,is_newer=version_is_newer}')

# Nothing outside the extracted version block may change in this first step.
runtime = (ROOT / 'Composition Studio.lua').read_text()
first = runtime.index('-- BEGIN VERSION MODULE')
last = runtime.index('local update_job=nil', first)
assert runtime[:first] + legacy + runtime[last:] == old, 'Unexpected runtime change outside version module'

subprocess.run([sys.executable, str(ROOT / 'tools/build_version_module.py'), '--check'], check=True)
variants = {'module': (ROOT / 'src/core/version.lua').read_text()}
for name in ('Composition Studio.lua', 'Composition-Studio-Update.lua', 'Composition-Studio-Offline-Install.lua'):
    source = (ROOT / name).read_text()
    first = source.index('-- BEGIN VERSION MODULE')
    last = source.index('-- END VERSION MODULE', first) + len('-- END VERSION MODULE')
    variants[name] = source[first:last] + '\nreturn {parts=version_parts,is_newer=version_is_newer}'

# Include malformed input, prerelease ordering, mixed formats and false/nil.
values = [None, False, True, 0, 110, '', 'invalid', '1', '1.2', 'v1.2.3',
          '1.2.3-beta', ' 1.2.3', '1.2.3\n', '-1.2.3', '1.2.3.4',
          '0.0.0', '1.1.9', '1.1.10', '1.2.0', '2.0.0', '01.02.003',
          '1.0-test2', '1.0-test10', '1.0.2', '1.0-test0', '1.0-test-1',
          '999.999.999']
for label, code in variants.items():
    api = LuaRuntime(unpack_returned_tuples=True).execute(code)
    for value in values:
        assert api.parts(value) == reference.parts(value), (label, value)
    for remote in values:
        for installed in values:
            assert api.is_newer(remote, installed) == reference.is_newer(remote, installed), (label, remote, installed)
    # Independently assert ordering and return shape rather than only parity.
    assert api.parts('1.2.3') == (1, 2, 3)
    assert api.parts(None) == (None, None, None)
    assert api.is_newer('1.0-test10', '1.0-test2') is True
    assert api.is_newer('1.1.10', '1.1.10') is False
    print(f'PASS {label}: {len(values)} parse cases and {len(values)**2} ordering comparisons against production {BASE[:7]}')

# The runtime must remain standalone: syntax-load the full shipped artifacts.
for name in ('Composition Studio.lua', 'Composition-Studio-Update.lua', 'Composition-Studio-Offline-Install.lua'):
    LuaRuntime().execute('assert(load(...))', (ROOT / name).read_text())
print('PASS full Lua 5.4 syntax for Studio, rescue updater and offline installer')
