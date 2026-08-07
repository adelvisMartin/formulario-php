#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
source = Path('tonofino-ci/build-v19.sh').read_text()
old = '''git -C "$PROJECT" apply --check ../tonofino-ci/MainActivity-v19.patch
git -C "$PROJECT" apply ../tonofino-ci/MainActivity-v19.patch'''
new = '''# The complete v1.9 patch already contains the native feedback bridge.
# Only normalize its delayed ToneGenerator release for the activity field name used by this project.
python3 tonofino-ci/fix-mainactivity-v19.py "$PROJECT/app/src/main/java/com/tonofino/studio/MainActivity.java"'''
if old not in source:
    raise SystemExit('Expected MainActivity patch block was not found')
Path('/tmp/build-v19-run.sh').write_text(source.replace(old, new))
PY

bash /tmp/build-v19-run.sh
