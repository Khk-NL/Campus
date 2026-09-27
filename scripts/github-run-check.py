"""Read a bounded CI status and compiler errors without exposing credentials."""
import io
import json
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile

sys.stdout.reconfigure(encoding='utf-8')

credential = subprocess.run(
    ['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n',
    text=True, capture_output=True, check=True,
)
token = dict(line.split('=', 1) for line in credential.stdout.splitlines()
             if '=' in line)['password']
base = 'https://api.github.com/repos/Khk-NL/Campus/actions/runs/' + sys.argv[1]
headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json'}
with urllib.request.urlopen(urllib.request.Request(base + '/jobs', headers=headers), timeout=20) as response:
    jobs = json.load(response)['jobs']
print(json.dumps([{'status': job['status'], 'conclusion': job['conclusion'],
                   'steps': [{'name': step['name'], 'status': step['status'],
                              'conclusion': step['conclusion']}
                             for step in job['steps'] if step['status'] != 'queued']}
                  for job in jobs], ensure_ascii=False))

if any(job['conclusion'] == 'failure' for job in jobs):
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, response_headers, newurl):
            return None
    try:
        urllib.request.build_opener(NoRedirect).open(
            urllib.request.Request(base + '/logs', headers=headers), timeout=20)
    except urllib.error.HTTPError as error:
        if error.code != 302:
            raise SystemExit('Unable to retrieve CI logs: HTTP ' + str(error.code))
        # The signed download URL needs no GitHub Authorization header.
        with urllib.request.urlopen(error.headers['Location'], timeout=30) as response:
            archive = zipfile.ZipFile(io.BytesIO(response.read()))
        for name in archive.namelist():
            if 'Build APK' not in name and 'Check mobile' not in name:
                continue
            lines = archive.read(name).decode('utf-8-sig', errors='replace').splitlines()
            indexes = [index for index, line in enumerate(lines) if any(marker in line for marker in (
                ' e: ', 'error:', 'What went wrong', 'Execution failed', 'FAILURE:',
                'Unresolved reference', 'Compilation error', 'Missing WeChat',
            ))]
            selected = sorted({position for index in indexes
                               for position in range(index, min(index + 9, len(lines)))})
            relevant = [lines[position] for position in selected]
            print(name)
            print('\n'.join(relevant[-30:]))
