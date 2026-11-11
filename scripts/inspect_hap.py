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
    app = json.loads(archive.read('module.json'))['app']
    if app['bundleName'] != 'com.sdkdsd.dailynic.sust':
        raise SystemExit('Wrong bundle: this is not the SUST personal fork')
    for field in ('bundleName', 'versionName', 'compileSdkVersion', 'targetAPIVersion', 'minAPIVersion', 'apiReleaseType'):
        print(f'{field}: {app.get(field, "not recorded")}')
print('SHA-256:', hashlib.sha256(path.read_bytes()).hexdigest())
print('Manifest/ZIP only. Signature validity, HarmonyOS 7 compatibility, installation and features: NOT VERIFIED.')
