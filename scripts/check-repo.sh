#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import sys

paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
problems = []
for name in filter(None, paths):
    path = Path(name)
    if (name.startswith(('.build/', 'dist/')) or
        (name.startswith('SDK/') and name != 'SDK/README.md') or
        path.suffix.lower() in {'.dylib', '.dmg', '.mp4', '.mov', '.mkv', '.log', '.pem', '.p12'}):
        problems.append(f'Private/generated/vendor file tracked: {name}')
    if path.suffix == '.icns':
        continue
    try:
        text = path.read_text()
    except (UnicodeDecodeError, FileNotFoundError):
        continue
    if re.search('/' + r'(Users|home)/[^/\s]+/', text):
        problems.append(f'Personal absolute path: {name}')
    if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?' + r'PRIVATE KEY-----', text):
        problems.append(f'Private key material: {name}')
if problems:
    print('\n'.join(problems), file=sys.stderr)
    sys.exit(1)
print('PASS: tracked files exclude SDKs, private media, build artifacts and common private data')
PY
