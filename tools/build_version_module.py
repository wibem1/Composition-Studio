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
    # Preserve the M1 command; src is now authoritative for the complete runtime.
    from build_studio import main as build_all
    build_all()


if __name__ == '__main__':
    main()
