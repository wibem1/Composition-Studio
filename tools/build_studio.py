"""Build all standalone Lua artifacts from the ordered development sources.

No downloads or runtime module loader. --check never modifies an artifact.
"""
import argparse
import json
from pathlib import Path

from build_version_module import embedded_block
from build_update_helper import build as build_updater
from build_offline_installer import build as build_offline

ROOT = Path(__file__).resolve().parents[1]
EXPORTS = '-- BEGIN MODULE EXPORTS\n'


def load_manifest(root=ROOT):
    manifest = json.loads((root / 'src/manifest.json').read_text(encoding='utf-8'))
    if manifest['schema'] != 1:
        raise ValueError('Unsupported source manifest')
    units = manifest['units']
    paths = [unit['path'] for unit in units]
    if len(paths) != len(set(paths)) or len({unit['id'] for unit in units}) != len(units):
        raise ValueError('Duplicate source unit')
    actual = {str(p.relative_to(root)) for p in (root / 'src').rglob('*.lua')}
    if set(paths) != actual:
        raise ValueError(f'Unlisted or missing Lua sources: {set(paths) ^ actual}')
    available = set()
    portable_globals = {'assert', 'error', 'ipairs', 'pairs', 'pcall', 'tostring',
                        'tonumber', 'type', 'math', 'string', 'table', '_G'}
    for unit in units:
        path = (root / unit['path']).resolve()
        if not path.is_relative_to((root / 'src').resolve()):
            raise ValueError('Source path must stay inside src')
        missing = set(unit['requires']) - available
        if missing:
            raise ValueError(f"Imports before declaration in {unit['id']}: {sorted(missing)}")
        available.update(unit['provides'])
        if unit['kind'] in ('portable', 'factory'):
            if unit['host_apis'] or unit['writes'] or set(unit['globals']) - portable_globals:
                raise ValueError(f"Portable module has host/state dependencies: {unit['id']}")
        if unit['kind'] == 'factory' and set(unit['parameters']) != set(unit['requires']):
            raise ValueError(f"Factory imports must be explicit: {unit['id']}")
    return manifest


def inline(unit, root=ROOT):
    source = (root / unit['path']).read_text(encoding='utf-8')
    if unit['kind'] == 'version':
        return embedded_block(source) + unit['trailing']
    if unit['exports']:
        if source.count(EXPORTS) != 1:
            raise ValueError(f"Missing or duplicate export marker: {unit['path']}")
        source, exports = source.split(EXPORTS)
        expected = ('return {' + ','.join(name + '=' + name for name in unit['exports']) +
                    '}\n' + ('end\n' if unit['kind'] == 'factory' else ''))
        if exports != expected:
            raise ValueError(f"Exports disagree with manifest: {unit['path']}")
    if unit['kind'] == 'factory':
        prefix = 'return function(' + ','.join(unit['parameters']) + ')\n'
        if not source.startswith(prefix):
            raise ValueError(f"Factory dependencies disagree with manifest: {unit['path']}")
        source = source[len(prefix):]
    return source


def render(root=ROOT):
    manifest = load_manifest(root)
    return ''.join(inline(unit, root) for unit in manifest['units'])


def artifacts(root=ROOT):
    runtime = render(root)
    return {'Composition Studio.lua': runtime,
            'Composition-Studio-Update.lua': build_updater(runtime),
            'Composition-Studio-Offline-Install.lua': build_offline(runtime)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify all artifacts without writing')
    args = parser.parse_args()
    outputs = artifacts()
    stale = [name for name, output in outputs.items()
             if not (ROOT / name).exists() or (ROOT / name).read_bytes() != output.encode('utf-8')]
    if args.check:
        if stale:
            raise SystemExit('Stale generated artifacts: ' + ', '.join(stale))
        print('PASS all standalone artifacts match src/manifest.json and module sources')
    else:
        for name, output in outputs.items():
            (ROOT / name).write_text(output, encoding='utf-8', newline='\n')
        print('Built Studio, rescue updater and offline installer from modular sources')


if __name__ == '__main__':
    main()
