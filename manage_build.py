import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
import zipfile
import io
import hashlib
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = 'Kh1zSn0w/astra-arcade-ios-20261011'
PYFLAG = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
ENV = dict(os.environ, GCM_INTERACTIVE='Never', GIT_TERMINAL_PROMPT='0')

def git(*args):
    proc = subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, text=True, env=ENV, creationflags=PYFLAG)
    if proc.returncode:
        print('GIT_ERROR', proc.stderr[-1400:])
        raise SystemExit(proc.returncode)
    return proc.stdout.strip()

def credential():
    proc = subprocess.run(['git', 'credential', 'fill'],
        input='protocol=https\nhost=github.com\nusername=Kh1zSn0w\n\n',
        capture_output=True, text=True, env=ENV, creationflags=PYFLAG)
    if proc.returncode:
        raise SystemExit('GitHub Credential Manager authentication unavailable')
    pairs = dict(s.split('=', 1) for s in proc.stdout.splitlines() if '=' in s)
    if 'password' not in pairs:
        raise SystemExit('No GitHub credential found')
    return pairs['password']

TOKEN = credential()
HEADERS = {'Authorization': 'Bearer ' + TOKEN, 'Accept': 'application/vnd.github+json', 'User-Agent': 'Atmos-Weather-Build'}

def api(url, payload=None, method=None, binary=False):
    address = url if url.startswith('http') else 'https://api.github.com' + url
    req = urllib.request.Request(address, data=None if payload is None else json.dumps(payload).encode('utf-8'), headers=HEADERS, method=method)
    with urllib.request.urlopen(req, timeout=90) as response:
        body = response.read()
    return body if binary else (json.loads(body) if body else None)

def ensure_repo():
    try:
        x = api('/repos/' + REPO)
        print('REPOSITORY_EXISTS', x['html_url'])
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise SystemExit('GitHub repository inspection HTTP ' + str(exc.code))
        try:
            x = api('/user/repos', {'name': REPO.split('/')[1], 'private': False, 'description': 'Astra original SpriteKit vertical arcade shooter, source only', 'auto_init': False})
            print('REPOSITORY_CREATED', x['html_url'])
        except urllib.error.HTTPError as err:
            raise SystemExit('GitHub repository create HTTP ' + str(err.code))
    return x

def publish():
    ensure_repo()
    if not (ROOT / '.git').exists():
        git('init', '-b', 'main')
    git('add', '.')
    status = git('status', '--short')
    print('STAGED_FILES', len(status.splitlines()))
    if status:
        git('-c', 'user.name=Kh1zSn0w', '-c', 'user.email=Kh1zSn0w@users.noreply.github.com', 'commit', '-m', 'Build original Astra retro plane shooter')
    remotes = git('remote')
    if 'origin' not in remotes.splitlines():
        git('remote', 'add', 'origin', 'https://github.com/' + REPO + '.git')
    git('push', '-u', 'origin', 'main')
    print('PUSH_OK', git('rev-parse', 'HEAD'))

def status():
    data = api('/repos/' + REPO + '/actions/runs?per_page=6')
    runs = [{'id': a['id'], 'status': a['status'], 'result': a['conclusion'], 'url': a['html_url'], 'sha': a['head_sha'][:8]} for a in data['workflow_runs']]
    print(json.dumps(runs, indent=2))
    return runs

def download():
    runs = status()
    run = next((a for a in runs if a['result'] == 'success'), None)
    if not run:
        raise SystemExit('NO_SUCCESSFUL_BUILD')
    response = api('/repos/' + REPO + '/actions/runs/' + str(run['id']) + '/artifacts')
    matches = [a for a in response['artifacts'] if a['name'] == 'Astra-Retro-Sky-iOS-v1.0' and not a['expired']]
    if not matches:
        raise SystemExit('BUILD_ARTIFACT_NOT_FOUND')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, url):
            return None
    try:
        urllib.request.build_opener(NoRedirect()).open(urllib.request.Request(matches[0]['archive_download_url'], headers=HEADERS), timeout=90)
        raise SystemExit('EXPECTED_ARTIFACT_REDIRECT')
    except urllib.error.HTTPError as exc:
        if exc.code not in (301, 302, 303, 307, 308):
            raise SystemExit('ARTIFACT_DOWNLOAD_HTTP_' + str(exc.code))
        download_url = exc.headers.get('Location')
        if not download_url or not download_url.startswith('https://'):
            raise SystemExit('INVALID_ARTIFACT_REDIRECT')
        with urllib.request.urlopen(download_url, timeout=120) as response:
            blob = response.read()
    archive = zipfile.ZipFile(io.BytesIO(blob))
    if archive.testzip():
        raise SystemExit('ARTIFACT_ZIP_FAILED_VERIFICATION')
    ipa_name = next((name for name in archive.namelist() if name.endswith('.ipa')), None)
    if not ipa_name:
        raise SystemExit('IPA_NOT_IN_ARTIFACT')
    ipa = archive.read(ipa_name)
    with zipfile.ZipFile(io.BytesIO(ipa)) as package:
        if package.testzip():
            raise SystemExit('IPA_ZIP_FAILED_VERIFICATION')
        names = package.namelist()
        info_name = next((n for n in names if n.startswith('Payload/Astra.app/') and n.endswith('/Info.plist')), None)
        if not info_name:
            info_name = 'Payload/Astra.app/Info.plist'
        info = plistlib.loads(package.read(info_name))
        assert info['CFBundleIdentifier'] == 'io.github.kh1zsn0w.astraarcade'
        assert 'Payload/Astra.app/Astra' in names
        print('IPA_VERIFIED', info['CFBundleIdentifier'], info.get('CFBundleShortVersionString'))
    downloads = Path.home() / 'Downloads'
    downloads.mkdir(exist_ok=True)
    output = downloads / 'Astra-Retro-Sky-v1.0-unsigned.ipa'
    if output.exists():
        output = downloads / ('Astra-Retro-Sky-v1.0-' + str(run['id']) + '-unsigned.ipa')
    output.write_bytes(ipa)
    assert output.stat().st_size == len(ipa)
    print('SAVED_TO_DOWNLOADS', str(output))
    print('BYTES', len(ipa), 'SHA256', hashlib.sha256(ipa).hexdigest())
    print('SUCCESS_RUN', run['url'])

def diagnostics():
    runs = status()
    if not runs:
        return
    rid = runs[0]['id']
    try:
        data = api('/repos/' + REPO + '/actions/runs/' + str(rid) + '/logs', binary=True)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for name in z.namelist():
                if not name.endswith('.txt'):
                    continue
                content = z.read(name).decode('utf-8', 'replace')
                relevant = [line for line in content.splitlines() if 'error:' in line or 'BUILD FAILED' in line or 'Error:' in line or 'failed' in line.lower()]
                if relevant:
                    print('LOG', name)
                    for line in relevant[-25:]: print(line[-600:])
    except Exception as exc:
        print('LOG_READ_ERROR', type(exc).__name__, str(exc)[:200])

if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'publish': publish()
    elif action == 'status': status()
    elif action == 'download': download()
    elif action == 'diagnostics': diagnostics()
    else: raise SystemExit('Unknown action')
