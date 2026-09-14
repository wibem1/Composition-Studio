#!/usr/bin/env python3
"""Apply the Composition Studio V0.2 identity and approved light palette to MAGDA.

This deliberately leaves the audio/MIDI/project engine untouched.  It changes only
branding and the UI theme used by the prototype build.
"""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else "upstream").resolve()


def replace(path, old, new, required=True):
    p = root / path
    text = p.read_text(encoding="utf-8")
    if old not in text:
        if required:
            raise SystemExit(f"Expected text not found in {p}: {old!r}")
        return False
    p.write_text(text.replace(old, new), encoding="utf-8")
    return True


# ---------------------------------------------------------------------------
# Product identity. Keep source/target names unchanged so upstream functionality
# and helper binaries stay intact; only the user-facing macOS application changes.
# ---------------------------------------------------------------------------
cmake = root / "magda/daw/CMakeLists.txt"
text = cmake.read_text(encoding="utf-8")
text = text.replace('COMPANY_NAME "Conceptual Machines"', 'COMPANY_NAME "Klangwerke"')
text = text.replace('PRODUCT_NAME "MAGDA"', 'PRODUCT_NAME "Composition Studio"')
text = text.replace('BUNDLE_ID "com.MAGDA.MAGDA"', 'BUNDLE_ID "net.klangwerke.CompositionStudio"')
text = text.replace('MAGDA needs microphone access to record audio.', 'Composition Studio needs microphone access to record audio.')
text = text.replace('MAGDA needs access to your Documents folder', 'Composition Studio needs access to your Documents folder')
text = text.replace('MAGDA needs access to your Desktop', 'Composition Studio needs access to your Desktop')
text = text.replace('MAGDA needs access to your Downloads folder', 'Composition Studio needs access to your Downloads folder')
text = text.replace('MAGDA needs access to external drives', 'Composition Studio needs access to external drives')
cmake.write_text(text, encoding="utf-8")

main = root / "magda/daw/magda_daw_main.cpp"
text = main.read_text(encoding="utf-8")
text = text.replace('return "MAGDA";', 'return "Composition Studio";', 1)
# V0.2 is a visual shell. Force the approved light base regardless of an old
# MAGDA config so a test build always opens in the intended design.
text = text.replace('magda::applyThemeById(magda::Config::getInstance().getTheme());',
                    'magda::applyThemeById("light");')
text = text.replace('"MAGDA v" + getApplicationVersion()', '"Composition Studio v" + getApplicationVersion()')
text = text.replace('"=== MAGDA " + getApplicationVersion() + " starting ==="',
                    '"=== Composition Studio " + getApplicationVersion() + " starting ==="')
main.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------------
# Approved V0.2 light palette.  Only presentation roles are changed; semantic
# behaviour and the existing theme machinery remain untouched.
# ---------------------------------------------------------------------------
theme = root / "magda/daw/ui/themes/DarkTheme.cpp"
text = theme.read_text(encoding="utf-8")
start = text.find("constexpr DarkTheme::Palette lightPalette = [] {")
end_marker = "    return palette;\n}();"
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit("Could not locate upstream lightPalette block")
end += len(end_marker)
block = text[start:end]

palette = {
    "E0": "0xFFFFFFFF",
    "E1": "0xFFF4F7FA",
    "E2": "0xFFE8EEF3",
    "E3": "0xFFD9E2EA",
    "HAIRLINE": "0xFFB8C5CF",
    "BACKGROUND": "0xFFF1F5F8",
    "BACKGROUND_ALT": "0xFFE5ECF2",
    "PANEL_BACKGROUND": "0xFFF7F9FB",
    "SURFACE": "0xFFFFFFFF",
    "SURFACE_HOVER": "0xFFEAF2F8",
    "TRANSPORT_BACKGROUND": "0xFFEAF0F5",
    "BUTTON_NORMAL": "0xFFF7FAFC",
    "BUTTON_HOVER": "0xFFE3EDF6",
    "BUTTON_PRESSED": "0xFFD2E2EF",
    "BUTTON_ACTIVE": "0xFF2F80ED",
    "BUTTON_STROKE": "0xFFA9BBC9",
    "CONTROL_VALUE_FILL": "0x243080ED",
    "CONTROL_SLIDER_THUMB": "0xFF34495A",
    "TEXT_PRIMARY": "0xFF13233A",
    "TEXT_SECONDARY": "0xFF40556B",
    "TEXT_DIM": "0xFF6F8192",
    "TEXT_DISABLED": "0xFF9CA8B4",
    "ACCENT_PRIMARY": "0xFF2F80ED",
    "ACCENT_PRIMARY_SOFT": "0xFF78A9E8",
    "ACCENT_INFO": "0xFF268BA5",
    "ACCENT_POSITIVE": "0xFF16A36A",
    "ACCENT_ATTENTION": "0xFFF19A38",
    "ACCENT_MODULATION": "0xFF7657D8",
    "TRACK_BACKGROUND": "0xFFF8FAFB",
    "TRACK_SELECTED": "0xFFDCECF8",
    "TRACK_HEADER_SELECTED": "0xFF397DB2",
    "TRACK_HEADER_SELECTED_TEXT": "0xFFFFFFFF",
    "TRACK_SEPARATOR": "0xFFB5C2CD",
    "TIMELINE_BACKGROUND": "0xFFFBFCFD",
    "GRID_LINE": "0xFFE1E7EC",
    "BEAT_LINE": "0xFFC5D0D9",
    "BAR_LINE": "0xFF8798A5",
    "BORDER": "0xFFAEBBC6",
    "SEPARATOR": "0xFFC2CDD6",
    "RESIZE_HANDLE": "0xFF94A6B4",
    "WAVEFORM_NORMAL": "0xFF55758D",
    "WAVEFORM_SELECTED": "0xFF246FB5",
    "INSTRUMENT_BACKGROUND": "0xFFF7F9FB",
    "INSTRUMENT_PANEL": "0xFFFFFFFF",
    "INSTRUMENT_BORDER": "0xFFBAC6D0",
    "INSTRUMENT_TEXT": "0xFF17283A",
    "INSTRUMENT_TEXT_DIM": "0xFF65798B",
    "INPUT_BACKGROUND": "0xFFFFFFFF",
    "ICON_NEUTRAL": "0xFF465A6C",
    "ICON_TRANSPORT": "0xFF23394E",
    "ICON_ON_ACCENT": "0xFFFFFFFF",
    "PIANO_ROLL_BACKGROUND": "0xFFF7F9FB",
    "PIANO_ROLL_KEY_WHITE": "0xFFFFFFFF",
    "PIANO_ROLL_KEY_HIGHLIGHT": "0xFF4A8FD1",
    "PIANO_ROLL_KEY_SEPARATOR": "0xFFC5D0D9",
    "PIANO_ROLL_PITCH_HIGHLIGHT": "0xFF73A4CF",
    "PIANO_ROLL_GRID_BACKGROUND": "0xFFF3F7FA",
    "PIANO_ROLL_GRID_BLACK_KEY": "0xFFE7EDF2",
    "PIANO_ROLL_GRID_SUBDIVISION": "0xFFDCE4EA",
    "PIANO_ROLL_GRID_BEAT": "0xFFBDC9D2",
    "PIANO_ROLL_GRID_BAR": "0xFF899AA7",
    "ICON_BACKGROUND": "0xFFE8EEF3",
    "ICON_BRIGHT": "0xFF20364A",
    "ICON_SUBTLE": "0xFF708395",
    "ICON_BRAND": "0xFF1D4D8F",
    "MIXER_FADER_THUMB": "0xFF6D8BA2",
    "MIXER_KNOB_OUTER": "0xFFD8E1E8",
    "MIXER_KNOB_OUTER_STROKE": "0xFFA4B4C1",
    "MIXER_KNOB_INNER": "0xFFF7F9FB",
    "MIXER_KNOB_GUIDE": "0xFF7E92A2",
}

for role, colour in palette.items():
    pattern = rf"(set\(ColourRole::{role},\s*)0x[0-9A-Fa-f]+(\);)"
    block, n = re.subn(pattern, rf"\g<1>{colour}\g<2>", block)
    if n != 1:
        raise SystemExit(f"Expected exactly one light palette role {role}, found {n}")

text = text[:start] + block + text[end:]
theme.write_text(text, encoding="utf-8")

print("Composition Studio V0.2 overlay applied successfully")
