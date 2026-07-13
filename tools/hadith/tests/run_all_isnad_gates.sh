#!/usr/bin/env bash
# Required before merging Isnad Engine / narrator parser changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT/tools/hadith:${PYTHONPATH:-}"
python3 -m unittest discover -s tools/hadith/tests -p 'test_*.py' -v
python3 tools/hadith/tests/run_isnad_regression.py
python3 tools/hadith/tests/run_isnad_gold.py
python3 tools/hadith/verify_sanad_only_narrators.py
echo "All isnad gates passed."
