"""Optional real REAPER regression in a separate instance and temporary profile.
Usage: python tools/test_native_notation_reaper.py /path/to/reaper
No download, no API request, no interaction with an existing REAPER instance.
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
exe = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else None
if not exe or not exe.is_file():
    raise SystemExit('Supply the path to a locally installed REAPER executable')
with tempfile.TemporaryDirectory(prefix='nns-native-') as directory:
    root = Path(directory)
    config = root / 'reaper.ini'
    config.write_text('[REAPER]\n', encoding='utf-8')
    log = root / 'test.log'
    env = dict(os.environ, NNS_NATIVE_TEST_LOG=str(log))
    with (root / 'process.log').open('wb') as output:
        proc = subprocess.Popen([str(exe), '-newinst', '-new', '-nosplash', '-ignoreerrors',
                                 '-cfgfile', str(config), str(ROOT / 'tests/test_native_notation_reaper.lua')],
                                env=env, cwd=root, stdout=output, stderr=output)
        try:
            deadline = time.monotonic() + 25
            while time.monotonic() < deadline:
                result = log.read_text(encoding='utf-8') if log.exists() else ''
                if 'ALL PASSED' in result or '\nFAIL ' in result:
                    print(result, end='')
                    if 'ALL PASSED' not in result:
                        raise SystemExit(1)
                    break
                if proc.poll() is not None:
                    raise SystemExit('REAPER exited before completing the test')
                time.sleep(0.1)
            else:
                raise SystemExit('Timed out before REAPER completed the isolated regression')
        finally:
            # Terminate only the newly spawned, isolated test process we own.
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=3)
