"""Embed the pure version module in the existing single-file runtime."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
START = '-- BEGIN VERSION MODULE'
END = '-- END VERSION MODULE'


def embedded_block(module):
    body = ''.join(('  ' + line if line else '') + '\n' for line in module.splitlines())
    return (START + '\nlocal version_parts,version_is_newer\ndo\n'
            ' local function create_version_module()\n' + body +
            ' end\n local version=create_version_module()\n'
            ' version_parts,version_is_newer=version.parts,version.is_newer\n'
            'end\n' + END)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail on stale embedding without writing files')
    args = parser.parse_args()
    target = ROOT / 'Composition Studio.lua'
    source = target.read_text(encoding='utf-8')
    assert source.count(START) == source.count(END) == 1, 'Version module markers must be unique'
    first = source.index(START)
    last = source.index(END, first) + len(END)
    block = embedded_block((ROOT / 'src/core/version.lua').read_text(encoding='utf-8'))
    updated = source[:first] + block + source[last:]
    if args.check:
        if updated != source:
            raise SystemExit('Stale version module: run python tools/build_version_module.py')
        print('Version module embedding is current')
    else:
        target.write_text(updated, encoding='utf-8', newline='\n')
        print('Embedded src/core/version.lua in Composition Studio.lua')


if __name__ == '__main__':
    main()
