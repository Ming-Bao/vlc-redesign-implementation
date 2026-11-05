#!/usr/bin/env python3
"""Check the settings window's option names against the options VLC defines.

usage: check-settings-options.py [SettingsData.js]

Every `option:`, `list:`, `requires:` and `enabledBy:` value in the data file must be defined by an add_*("name", ...) call in src/ or
modules/ (add_obsolete_* doesn't count: an obsolete option is reported as such). Exits 1 listing the unknown
names, 0 when all are known.

It also checks HotkeysData.js: every add_key("key-*") option of src/libvlc-module.c must appear there exactly once.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]

# options defined in a way the grep below can't see; platform-only options are found by the grep
# whatever their #ifdef, and hide at run time through SettingsBridge.exists()
# postproc-q is FILTER_PREFIX "q"; the conversion quality is a macro (renderer_common.hpp) used with sout-chromecast-
ALLOW = {'postproc-q', 'sout-chromecast-conversion-quality'}

# prefix macros, add_*(SOUT_CFG_PREFIX "name": the file's own #define, plus these
NAMED_PREFIXES = ('sout-chromecast-', 'sout-x264-')

DEF_RE = re.compile(r'\badd_(\w+)\s*\(\s*(?:(\w+)\s+)?"([^"]+)"')
PREFIX_RE = re.compile(r'#\s*define\s+SOUT_CFG_PREFIX\s+"([^"]+)"')
USE_RE = re.compile(r'\b(?:option|list|requires|enabledBy)\s*:\s*"([^"]+)"')


def defined_options():
    known, obsolete = set(), set()
    for top in ('src', 'modules'):
        for path in (ROOT / top).rglob('*'):
            if path.suffix not in ('.c', '.cpp', '.h', '.m'):
                continue
            text = path.read_text(errors='replace')
            if 'add_' not in text:
                continue
            prefixes = set(PREFIX_RE.findall(text)) | set(NAMED_PREFIXES)
            for kind, macro, name in DEF_RE.findall(text):
                if kind in ('shortcut', 'submodule'):
                    continue
                names = [name] if not macro else [p + name for p in prefixes] if macro == 'SOUT_CFG_PREFIX' else []
                (obsolete if kind.startswith('obsolete') else known).update(names)
    return known, obsolete - known


HOTKEYS = ROOT / 'modules/gui/qt/dialogs/hotkeys/qml/HotkeysData.js'
SETTINGS = ROOT / 'modules/gui/qt/dialogs/settings/qml/SettingsData.js'
KEY_RE = re.compile(r'\badd_key\s*\(\s*"([^"]+)"')


def check_hotkeys():
    """Missing or duplicated key-* rows; returns the number of problems."""
    defined = set(KEY_RE.findall((ROOT / 'src/libvlc-module.c').read_text()))
    listed = USE_RE.findall(HOTKEYS.read_text())
    bad = 0
    for n in sorted(defined - set(listed)):
        print(f'{n}: missing from HotkeysData.js')
        bad += 1
    for n in sorted({n for n in listed if listed.count(n) > 1}):
        print(f'{n}: listed more than once in HotkeysData.js')
        bad += 1
    for n in sorted(set(listed) - defined):
        print(f'{n}: not a key option')
        bad += 1
    print(f'{len(defined)} key options, {len(listed)} listed, {bad} bad')
    return bad


def main():
    if len(sys.argv) > 2:
        sys.exit(__doc__)
    settings = pathlib.Path(sys.argv[1]) if len(sys.argv) == 2 else SETTINGS
    used = sorted(set(USE_RE.findall(settings.read_text())))
    known, obsolete = defined_options()
    bad = [n for n in used if n not in known and n not in ALLOW]
    for n in bad:
        print(f'{n}: {"obsolete" if n in obsolete else "unknown"} option')
    print(f'{len(used)} option names checked, {len(bad)} bad')
    sys.exit(1 if bad or check_hotkeys() else 0)


if __name__ == '__main__':
    main()
