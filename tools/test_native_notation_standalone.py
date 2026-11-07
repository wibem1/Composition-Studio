"""Offline standalone regression: Lua 5.4 + real Unix wrapper, no network.
Run from any directory: python tools/test_native_notation_standalone.py
Requires liblua5.4 (ctypes), or lua5.4/lua/texlua in PATH. No pip packages.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
def run_lua(path):
    exe = shutil.which('lua5.4') or shutil.which('lua') or shutil.which('texlua')
    command = [exe, str(path)] if exe else [sys.executable, str(ROOT / 'tools/run_lua54.py'), str(path)]
    subprocess.run(command, check=True)

run_lua(ROOT / 'tests/test_native_notation_standalone.lua')
if os.name == 'posix' and Path('/bin/sh').exists():
    with tempfile.TemporaryDirectory(prefix='nns-offline-') as d:
        root = Path(d)
        base = root / "Ü space ' $` ;$(touch INJECTION)"
        generator = root / 'generate.lua'
        generator.write_text('''reaper={EnumProjects=function() return 42 end}
NATIVE_NOTATION_TEST=true
local api=assert(loadfile('Native-Notation-Studio.lua'))()
api.transport_files(''' + json.dumps(str(base), ensure_ascii=False) + ''',false,'expressive MIDI fixture','test-model')
''', encoding='utf-8')
        run_lua(generator)
        request = json.loads(Path(str(base) + '.json').read_text())
        assert request['input'] == 'expressive MIDI fixture' and request['store'] is False
        wrapper = Path(str(base) + '.sh')
        original = wrapper.read_text()
        fake = root / 'offline-curl.py'
        fake.write_text('#!' + sys.executable + '''
import sys,os,json
args=sys.argv[1:]
assert args[0]=='-q'
assert args[args.index('--retry')+1]=='0'
assert 'Authorization: Bearer fixture-key-$`' in args
assert args[-1]=='https://api.openai.com/v1/responses'
req=args[args.index('--data-binary')+1]
assert req.startswith('@')
assert json.load(open(req[1:]))['input']=='expressive MIDI fixture'
open(args[args.index('-o')+1],'w').write('{"status":"completed"}')
sys.exit(int(os.environ['FIXTURE_EXIT']))
''')
        fake.chmod(0o700)
        wrapper.write_text(original.replace('/usr/bin/curl', "'" + str(fake) + "'", 1))
        for code in (0, 22, 28):
            env = dict(os.environ, OPENAI_API_KEY='fixture-key-$`', FIXTURE_EXIT=str(code))
            subprocess.run(['/bin/sh', str(wrapper)], env=env, cwd=root, check=True, timeout=5)
            assert Path(str(base) + '.done').read_text() == str(code)
            assert not Path(str(base) + '.done.pending').exists()
            assert not (root / 'INJECTION').exists()
            print(f'PASS real Unix wrapper: literal paths, header, request and exit {code}')
else:
    print('SKIP real Unix wrapper: /bin/sh unavailable')
print('PASS standalone offline suite; no external requests, no paid API calls')
