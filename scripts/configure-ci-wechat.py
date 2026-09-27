"""Store only the public mobile AppID in CI. The AppSecret never leaves openwx.env."""
import base64
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / '.tools' / 'ci-crypto'))
from nacl.public import PublicKey, SealedBox

raw = (Path(__file__).resolve().parent.parent / 'openwx.env').read_text(encoding='utf-8-sig')
ids = set(re.findall(r'\bwx[a-zA-Z0-9]{16}\b', raw))
if len(ids) != 1:
    raise SystemExit('Expected exactly one mobile AppID in openwx.env; no values were printed.')
value = ids.pop().encode()
credential = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True, check=True)
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
token = fields['password']
base = 'https://api.github.com/repos/Khk-NL/Campus/actions/secrets'

def call(url, method='GET', body=None):
    request = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json'}, method=method)
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read()
        return json.loads(raw) if raw else None

key = call(base + '/public-key')
encrypted = base64.b64encode(SealedBox(PublicKey(base64.b64decode(key['key']))).encrypt(value)).decode()
call(base + '/CAMPUS_WECHAT_APP_ID', 'PUT', {'encrypted_value': encrypted, 'key_id': key['key_id']})
print('Mobile AppID configured in GitHub Actions. AppSecret was not uploaded.')
