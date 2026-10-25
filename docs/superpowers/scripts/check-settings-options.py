#!/usr/bin/env python3
"""Check the settings window's option names against the options VLC defines.

usage: check-settings-options.py SettingsData.js

Every `option:`, `list:`, `requires:` and `enabledBy:` value in the data file must be defined by an add_*("name", ...) call in src/ or
modules/ (add_obsolete_* doesn't count: an obsolete option is reported as such). Exits 1 listing the unknown
names, 0 when all are known.
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


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    used = sorted(set(USE_RE.findall(pathlib.Path(sys.argv[1]).read_text())))
    known, obsolete = defined_options()
    bad = [n for n in used if n not in known and n not in ALLOW]
    for n in bad:
        print(f'{n}: {"obsolete" if n in obsolete else "unknown"} option')
    print(f'{len(used)} option names checked, {len(bad)} bad')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
