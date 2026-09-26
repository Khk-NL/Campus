"""Upload the existing preview key as an encrypted GitHub secret; never print credentials."""
import base64
import json
import os
import subprocess
import sys
import urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.tools', 'ci-crypto'))
from nacl.public import PublicKey, SealedBox
credential = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True, check=True)
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
token = fields['password']
base = 'https://api.github.com/repos/Khk-NL/Campus/actions/secrets'
def call(url, method='GET', body=None):
    headers={'Authorization': 'Bearer '+token, 'Accept':'application/vnd.github+json', 'X-GitHub-Api-Version':'2022-11-28'}
    data=json.dumps(body).encode() if body else None
    request=urllib.request.Request(url,data=data,headers=headers,method=method)
    with urllib.request.urlopen(request, timeout=20) as response:
        raw=response.read()
        return json.loads(raw) if raw else None
key=call(base+'/public-key')
with open(os.path.join(os.environ['USERPROFILE'],'.android','debug.keystore'),'rb') as file:
    value=base64.b64encode(file.read())
encrypted=base64.b64encode(SealedBox(PublicKey(base64.b64decode(key['key']))).encrypt(value)).decode()
call(base+'/CAMPULSE_PREVIEW_KEYSTORE_BASE64','PUT',{'encrypted_value':encrypted,'key_id':key['key_id']})
print('Stable preview signing key saved as encrypted GitHub Actions secret.')
