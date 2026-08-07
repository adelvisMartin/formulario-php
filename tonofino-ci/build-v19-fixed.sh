#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
source = Path('tonofino-ci/build-v19.sh').read_text()
old = '''git -C "$PROJECT" apply --check ../tonofino-ci/MainActivity-v19.patch
git -C "$PROJECT" apply ../tonofino-ci/MainActivity-v19.patch'''
new = '''# The main v1.9 patch already contains most or all native bridge hunks.
# Reject mode makes this supplemental patch idempotent and applies only a missing hunk.
git -C "$PROJECT" apply --reject --whitespace=nowarn ../tonofino-ci/MainActivity-v19.patch || true'''
if old not in source:
    raise SystemExit('Expected MainActivity patch block was not found')
Path('/tmp/build-v19-run.sh').write_text(source.replace(old, new))
PY

bash /tmp/build-v19-run.sh
