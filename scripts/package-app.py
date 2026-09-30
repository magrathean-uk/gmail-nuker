#!/usr/bin/env python3
"""Build a local macOS app without embedding credentials.

Pass --config only for a private personalised build; it contains mailbox and
1Password field references, never a service-account private key. Requires Swift,
uv, the installed official 1Password CLI, and macOS iconutil/codesign/ditto.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]

def run(*command):
    subprocess.run([str(c) for c in command], cwd=REPO, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--output', type=Path, default=REPO / 'dist')
    args = parser.parse_args()
    config = {'mailbox': '', 'secretReference': '', 'serviceAccount': ''}
    if args.config:
        supplied = json.loads(args.config.read_text())
        if (not set(config).issubset(supplied) or set(supplied) - {*config, 'opConfigDirectory'}
                or any(not isinstance(v,str) for v in supplied.values())):
            parser.error('Configuration requires mailbox, secretReference, serviceAccount; optionally opConfigDirectory. All are strings.')
        if not supplied['secretReference'].startswith('op://') or 'PRIVATE KEY' in json.dumps(supplied):
            parser.error('Configuration must contain a 1Password reference, never a private key.')
        config = supplied
    op = shutil.which('op')
    if not op:
        parser.error('Install the official 1Password CLI before building.')
    output = args.output.resolve()
    output.mkdir(parents=True,exist_ok=True)
    work = REPO / 'app' / '.build' / 'packaging'
    work.mkdir(parents=True,exist_ok=True)
    os.environ.setdefault('PYINSTALLER_CONFIG_DIR', str(work / 'cache'))
    source = work / 'source'
    source.mkdir(exist_ok=True)
    shutil.copy2(REPO / 'bin/gmail-block', source / 'gmail_engine.py')
    shutil.copy2(REPO / 'app/engine_launcher.py', source / 'engine_launcher.py')
    run('swift','build','-c','release','--package-path',REPO / 'app')
    run('uv','run','--with-requirements',REPO / 'app/runtime-requirements.txt',
        'pyinstaller','--noconfirm','--clean','--onedir','--noupx',
        '--name','gmail-nuker-engine','--paths',source,
        '--distpath',work / 'runtime','--workpath',work / 'pyinstaller',
        '--specpath',work,source / 'engine_launcher.py')
    app = output / 'Gmail Nuker.app'
    if app.exists():
        shutil.rmtree(app)
    contents = app / 'Contents'
    macos = contents / 'MacOS'
    resources = contents / 'Resources'
    helpers = contents / 'Helpers'
    for folder in (macos,resources,helpers): folder.mkdir(parents=True,exist_ok=True)
    binary_dir = subprocess.check_output(['swift','build','-c','release','--package-path',str(REPO / 'app'),'--show-bin-path'],text=True).strip()
    shutil.copy2(Path(binary_dir) / 'GmailBlockApp',macos / 'GmailBlockApp')
    shutil.copytree(work / 'runtime/gmail-nuker-engine',resources / 'Engine',symlinks=True)
    shutil.copy2(Path(op).resolve(),helpers / 'op')
    # Preserve the official helper's vendor signature for 1Password integration.
    run('codesign','--verify','--strict',helpers / 'op')
    (resources / 'AccountConfiguration.json').write_text(json.dumps(config,indent=2)+'\n')
    (contents / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleName':'Gmail Nuker','CFBundleDisplayName':'Gmail Nuker',
        'CFBundleIdentifier':'uk.magrathean.gmail-nuker',
        'CFBundleExecutable':'GmailBlockApp','CFBundlePackageType':'APPL',
        'CFBundleIconFile':'AppIcon','CFBundleShortVersionString':'1.0',
        'CFBundleVersion':'1','LSMinimumSystemVersion':'14.0',
        'LSApplicationCategoryType':'public.app-category.productivity',
        'NSHighResolutionCapable':True,
        'NSHumanReadableCopyright':'© 2026 MAGRATHEAN UK LTD. Independent of Google.'
    }))
    run('swift',REPO / 'scripts/make-icon.swift',work / 'AppIcon.iconset')
    run('iconutil','-c','icns',work / 'AppIcon.iconset','-o',resources / 'AppIcon.icns')
    licenses = resources / 'Licenses'
    licenses.mkdir()
    for name in ('LICENSE','NOTICE','PRIVACY.md'):
        shutil.copy2(REPO / name,licenses / name)
    # Obtain runtime licence notices from the same pinned environment that built it.
    run('uv','run','--with-requirements',REPO / 'app/runtime-requirements.txt',
        'python',REPO / 'scripts/runtime-notices.py',licenses)
    run('codesign','--force','--sign','-',macos / 'GmailBlockApp')
    run('codesign','--force','--sign','-',app)
    run('codesign','--verify','--deep','--strict',app)
    archive = output / 'Gmail Nuker.zip'
    if archive.exists(): archive.unlink()
    run('ditto','-c','-k','--sequesterRsrc','--keepParent',app,archive)
    print(f'App: {app}\nArchive: {archive}')

if __name__ == '__main__': main()
