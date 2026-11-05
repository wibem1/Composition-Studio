"""Run every existing Python/Lua regression without REAPER or paid provider calls."""
from pathlib import Path
import subprocess
import sys
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
syntax = lua.eval('function(s,name) local f,e=load(s,name,"t");return f~=nil,e end')
failed = []
for path in sorted(ROOT.rglob('*.lua')):
    valid, error = syntax(path.read_text(), '@' + str(path))
    if not valid:
        failed.append(str(path.relative_to(ROOT)))
        print(error, flush=True)
print('Lua 5.4: complete syntax check of all repository Lua files', flush=True)
for path in sorted((ROOT / 'tests').glob('*.lua')):
    # Separate runtime per suite, matching the standalone Lua CI invocation.
    try:
        LuaRuntime().execute('assert(loadfile(...))()', str(path))
        print('PASS', path.relative_to(ROOT), flush=True)
    except Exception as error:
        failed.append(str(path.relative_to(ROOT)))
        print(error, flush=True)
for path in sorted((ROOT / 'tools').glob('test_*.py')):
    result = subprocess.run([sys.executable, str(path)], cwd=ROOT)
    if result.returncode:
        failed.append(str(path.relative_to(ROOT)))
    print('FAIL' if result.returncode else 'PASS', path.relative_to(ROOT), flush=True)
if failed:
    print('FAILED:', ', '.join(failed), flush=True)
    sys.exit(1)
print('ALL REGRESSION SUITES PASSED. Host/UI mocks are not a REAPER acceptance test.', flush=True)
