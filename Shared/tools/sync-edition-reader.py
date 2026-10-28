#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Copy the canonical offline edition text layout into each independently built port."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
source=(root/'Shared/reader/edition-reader.html').read_bytes()
for relative in ('iOS/Prosary/Resources/edition-reader.html','Android/app/src/main/assets/edition-reader.html','Windows/Prosary/Assets/edition-reader.html'):
    path=root/relative
    if '--check' in sys.argv:
        if not path.exists() or path.read_bytes()!=source: raise SystemExit(f'Out of sync: {relative}')
    else:
        path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(source)
print('Edition layout is identical on all three platforms.')
