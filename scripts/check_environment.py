#!/usr/bin/env python3
"""Read-only preflight. Never reads signing profiles, keys, tokens or the whole environment."""
import os
import platform
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
print('OS:', platform.system(), platform.machine())
for name in ('node', 'java', 'ohpm', 'hvigorw', 'hdc'):
    print(f'{name}:', 'found' if shutil.which(name) else 'not found on PATH')
for name in ('DEVECO_SDK_HOME', 'JAVA_HOME', 'HVIGORW', 'DEVECO_HOME'):
    value = os.environ.get(name)
    print(f'{name}:', 'existing path' if value and Path(value).exists() else 'unset or missing')
for relative in ('build-profile.json5', 'oh_modules', 'entry/oh_modules'):
    print(f'{relative}:', 'present' if (root / relative).exists() else 'absent')
print('Cloud activation script:', 'present' if Path('/workspace/.cloud-tools/dailynic/activate.sh').is_file() else 'absent in this instance')
print('Signature/device/phone installation: NOT VERIFIED (this script does not sign or connect a device).')
