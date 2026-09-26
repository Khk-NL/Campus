#!/usr/bin/env bash
# Run interactively on the server. The user enters the key, never the agent.
set -euo pipefail
if [[ $EUID -ne 0 ]]; then
  echo 'Run with sudo bash /opt/campus/source/deploy/configure-ai.sh' >&2
  exit 1
fi
test -f /etc/campus/ai.env
read -r -s -p 'ChatECNU API key (input hidden): ' campus_key
printf '\n'
if [[ -z "$campus_key" || "$campus_key" == *[[:space:]]* || "$campus_key" == *\"* || "$campus_key" == *\'* || "$campus_key" == *\\* ]]; then
  echo 'Key must be nonempty and contain no whitespace, quotes or backslashes.' >&2
  exit 1
fi
export CAMPUS_MODEL_KEY="$campus_key"
python3 - <<'PY'
import os
from pathlib import Path
path = Path('/etc/campus/ai.env')
lines = path.read_text().splitlines()
if sum(line.startswith('CHATECNU_API_KEY=') for line in lines) != 1:
    raise SystemExit('Expected exactly one CHATECNU_API_KEY setting')
lines = ['CHATECNU_API_KEY=' + os.environ['CAMPUS_MODEL_KEY']
         if line.startswith('CHATECNU_API_KEY=') else line for line in lines]
path.write_text('\n'.join(lines) + '\n')
PY
unset CAMPUS_MODEL_KEY campus_key
systemctl restart campus-ai
systemctl is-active campus-ai
echo 'Key saved privately. Verify with an authenticated real question.'
