#!/usr/bin/env python3
"""
fix_top_refs.py - OpenEMR Sandstorm cross-origin top. reference fixer

This script patches OpenEMR's JavaScript (both .js files and PHP-embedded JS)
to replace direct 'top.' references with a safe IIFE that walks up the frame
hierarchy while respecting Sandstorm's cross-origin iframe boundary.

Key design decisions:
1. Use 'globalThis' (not 'window' or 'self') to avoid variable shadowing:
   - 'window' is commonly used as a function parameter (e.g., set_opener(window, opener))
   - 'self' is commonly used as 'var self = this' in OOP patterns
   - 'globalThis' (ES2020) is always the actual global object, never shadowed
2. Apply IIFE to both .js and .php files (PHP files' inline JS also has top. refs)
3. Handle dialog.js and dialog_utils.js specially (opener_list initialization)
"""
import os
import re
import sys

OPENEMR_DIR = '/opt/openemr-7.0.3/openemr'

# Safe-top IIFE using globalThis (cannot be shadowed)
SAFE_TOP = (
    '((function(){'
    'try{if(globalThis[String.fromCharCode(116,111,112)].location.href)'
    'return globalThis[String.fromCharCode(116,111,112)];}catch(e){}'
    'var c=globalThis;while(c.parent&&c.parent!==c){'
    'try{if(c.parent.document)c=c.parent;else break;}catch(e){break;}}'
    'return c;'
    '})()'
    ')'
)

# Patterns to replace (order matters — more specific first)
REPLACEMENTS = [
    # window.top. -> SAFE_TOP.
    (re.compile(r'(?<![a-zA-Z0-9_])window\.top\.'), SAFE_TOP + '.'),
    # opener.top. -> opener-based SAFE_TOP.
    (re.compile(r'(?<![a-zA-Z0-9_])opener\.top\.'),
     '((function(){try{if(globalThis[String.fromCharCode(116,111,112)].location.href)'
     'return globalThis[String.fromCharCode(116,111,112)];}catch(e){}'
     'var c=globalThis;while(c.parent&&c.parent!==c){'
     'try{if(c.parent.document)c=c.parent;else break;}catch(e){break;}}'
     'return c;})()'
     ').'),
    # parent.top. -> SAFE_TOP.
    (re.compile(r'(?<![a-zA-Z0-9_])parent\.top\.'), SAFE_TOP + '.'),
    # bare top. -> SAFE_TOP. (not preceded by letter/digit/underscore/dot)
    (re.compile(r'(?<![a-zA-Z0-9_.])top\.'), SAFE_TOP + '.'),
]

def patch_file(fpath, ext):
    try:
        with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except Exception as e:
        return False, str(e)

    new_content = content
    for pattern, replacement in REPLACEMENTS:
        new_content = pattern.sub(replacement, new_content)

    if new_content == content:
        return False, None  # no changes

    try:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True, None
    except Exception as e:
        return False, str(e)


def fix_dialog_js(path):
    """Special handling for dialog.js: fix opener_list initialization."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = content.replace(
            'var opener_list = [];',
            SAFE_TOP + '.opener_list = ' + SAFE_TOP + '.opener_list || [];'
        )
        content = content.replace('var wframe = top;', 'var wframe = ' + SAFE_TOP + ';')
        content = content.replace('? top : window', '? ' + SAFE_TOP + ' : window')

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    except Exception as e:
        print(f'ERROR fixing dialog.js: {e}', file=sys.stderr)
        return False


def fix_dialog_utils_js(path):
    """Special handling for dialog_utils.js: fix opener_list initialization."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = content.replace(
            'var opener_list=[];',
            SAFE_TOP + '.opener_list = ' + SAFE_TOP + '.opener_list || [];'
        )

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    except Exception as e:
        print(f'ERROR fixing dialog_utils.js: {e}', file=sys.stderr)
        return False


# --- Phase 1: Fix dialog.js and dialog_utils.js first ---
dialog_js = os.path.join(OPENEMR_DIR, 'library/dialog.js')
dialog_utils_js = os.path.join(OPENEMR_DIR, 'interface/main/tabs/js/dialog_utils.js')

print(f'Fixing dialog.js opener_list...')
fix_dialog_js(dialog_js)
print(f'Fixing dialog_utils.js opener_list...')
fix_dialog_utils_js(dialog_utils_js)

# --- Phase 2: Replace all top. references in .js and .php files ---
js_patched = 0
php_patched = 0
errors = []

for root, dirs, files in os.walk(OPENEMR_DIR):
    dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ('vendor',)]
    for fname in files:
        ext = os.path.splitext(fname)[1].lower()
        if ext not in ('.js', '.php', '.inc'):
            continue

        fpath = os.path.join(root, fname)
        changed, err = patch_file(fpath, ext)

        if err:
            errors.append(f'{fpath}: {err}')
        elif changed:
            if ext == '.js':
                js_patched += 1
            else:
                php_patched += 1

print(f'JS  files patched: {js_patched}')
print(f'PHP files patched: {php_patched}')

if errors:
    print(f'Errors ({len(errors)}):')
    for e in errors[:10]:
        print(f'  {e}', file=sys.stderr)
    sys.exit(1)
else:
    print('All done, no errors.')
