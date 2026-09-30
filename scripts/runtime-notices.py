import importlib.metadata as metadata
import json
from pathlib import Path
import shutil
import sys

output = Path(sys.argv[1])
versions = {'Python': sys.version.split()[0]}
for name in ('pyinstaller','cryptography','certifi','cffi','pycparser'):
    distribution = metadata.distribution(name)
    versions[name] = distribution.version
    destination = output / name
    destination.mkdir(exist_ok=True)
    for file in distribution.files:
        if 'license' in str(file).lower() or str(file).endswith('COPYING.txt'):
            source = Path(distribution.locate_file(file))
            if source.is_file(): shutil.copy2(source,destination / source.name)
python_license = Path(sys.base_prefix) / 'lib/python3.14/LICENSE.txt'
if not python_license.is_file():
    python_license = Path(sys.base_prefix) / 'LICENSE'
if not python_license.is_file():
    raise RuntimeError('Python licence notice not found in the build runtime')
shutil.copy2(python_license,output / 'Python-LICENSE.txt')
(output / 'versions.json').write_text(json.dumps(versions,indent=2)+'\n')
(output / '1Password.txt').write_text('The official 1Password CLI is bundled for this personal local build. Copyright AgileBits/1Password. It retains its original vendor signature. Requires your installed 1Password application and subscription. Terms: https://1password.com/legal/terms-of-service/\n')
