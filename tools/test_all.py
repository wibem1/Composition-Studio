"""Run all offline Studio regressions; preserve failed/skipped outcomes."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    failures = []
    suites = sorted(path for path in (ROOT / 'tools').glob('test_*.py')
                    if path.name != Path(__file__).name)
    for suite in suites:
        print('\nRUN ' + suite.name, flush=True)
        result = subprocess.run([sys.executable, str(suite)], cwd=ROOT)
        if result.returncode:
            failures.append(suite.name)
    # Each file runs in a fresh Lua 5.4 state, matching separate CLI invocations.
    from lupa.lua54 import LuaRuntime
    for suite in sorted((ROOT / 'tests').glob('*.lua')):
        print('\nRUN ' + suite.name, flush=True)
        try:
            LuaRuntime().execute(suite.read_text(encoding='utf-8'))
        except Exception as error:
            print(error, file=sys.stderr)
            failures.append(suite.name)
    print(f'\nCompleted {len(suites)} Python suites and 3 Lua files; failed: {failures}', flush=True)
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
