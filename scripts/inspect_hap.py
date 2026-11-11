#!/usr/bin/env python3
"""Inspect manifest identity, never signing material. A ZIP check is not installation."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'entry/build/default/outputs/default/entry-default-unsigned.hap'
if not path.is_file():
    raise SystemExit('Expected unsigned HAP not found. A signed build needs an explicit path for inspection; no installation is claimed.')
with zipfile.ZipFile(path) as archive:
    if archive.testzip() is not None:
        raise SystemExit('HAP ZIP integrity check failed')
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise SystemExit('Duplicate ZIP entries are not allowed')
    for required in ('module.json', 'resources.index', 'ets/modules.abc', 'ets/widgets.abc'):
        if required not in names or archive.getinfo(required).file_size == 0:
            raise SystemExit('Incomplete HAP: missing or empty ' + required)
    if any(name.lower().endswith(('.p12', '.pfx', '.pem', '.key', '.keystore')) for name in names):
        raise SystemExit('Signing/key material must not be packaged')
    app = json.loads(archive.read('module.json'))['app']
    if app['bundleName'] != 'com.sdkdsd.dailynic.sust':
        raise SystemExit('Wrong bundle: this is not the SUST personal fork')
    if app['versionName'] != '2.3.0-sust.1' or app['versionCode'] != 2003001:
        raise SystemExit('Unexpected application version')
    for field in ('bundleName', 'versionName', 'versionCode', 'compileSdkVersion', 'targetAPIVersion', 'minAPIVersion', 'apiReleaseType'):
        print(f'{field}: {app.get(field, "not recorded")}')
print('File:', path.name)
print('Bytes:', path.stat().st_size)
print('ZIP entries:', len(names))
print('SHA-256:', hashlib.sha256(path.read_bytes()).hexdigest())
print('Manifest/ZIP only. Signature validity, HarmonyOS 7 compatibility, installation and features: NOT VERIFIED.')
