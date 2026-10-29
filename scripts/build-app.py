#!/usr/bin/env python3
"""Build the self-contained local macOS app from an explicitly selected InkyOS image."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import plistlib
import re
import struct

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path.home() / 'Applications/inkyImager.app')
    parser.add_argument('--scratch-path', type=Path, default=Path.home() / 'Library/Caches/inkyImager-build')
    parser.add_argument('--jobs', type=int, default=2, help='Limit compiler concurrency on the build Mac.')
    parser.add_argument('--app-version', default='0.1.2')
    parser.add_argument('--build-number', default='3')
    parser.add_argument('--sign-identity', default='-', help='Default: local ad-hoc signature.')
    parser.add_argument('--timestamp', action='store_true',
                        help='Explicitly permit Apple timestamp requests for Developer ID signing.')
    args = parser.parse_args()
    require(1 <= args.jobs <= 16, 'Compiler jobs must be 1..16')
    require(re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', args.app_version),
            'App version must have three numeric components')
    require(re.fullmatch(r'[1-9][0-9]{0,3}', args.build_number), 'Build number must be 1..9999')
    require((args.sign_identity == '-') != args.timestamp,
            'Developer ID requires explicit --timestamp; ad-hoc signing stays offline')
    destination = args.destination.resolve()
    require(destination.suffix == '.app' and destination.name == 'inkyImager.app', 'Expected inkyImager.app')
    require(not destination.exists(), 'Choose a new destination; do not overwrite an installed app')
    manifest = json.loads(args.manifest.read_text())
    require(manifest['schemaVersion'] == 1 and manifest['configurationFile'] == 'inky-imager.json',
            'Unexpected manifest schema or Wi-Fi configuration file')
    require(manifest['imageFile'] == 'InkyOS.img.xz', 'Unexpected image filename')
    require(type(manifest['imageBytes']) is int and manifest['imageBytes'] > 0 and
            all(re.fullmatch(r'[0-9a-f]{64}', manifest[key]) for key in ('imageSHA256', 'compressedSHA256')),
            'Manifest size and SHA-256 pins are required')
    require(digest(args.image) == manifest['compressedSHA256'], 'Selected image checksum mismatch')
    scratch = args.scratch_path.resolve()
    scratch.mkdir(parents=True, exist_ok=True)
    temporary = scratch / 'tmp'
    temporary.mkdir(mode=0o700, exist_ok=True)
    environment = dict(os.environ, TMPDIR=str(temporary))
    command = ['swift', 'build', '--scratch-path', str(scratch),
               '--cache-path', str(scratch / 'shared-cache'), '--config-path', str(scratch / 'config'),
               '--security-path', str(scratch / 'security'), '--manifest-cache', 'local',
               '--jobs', str(args.jobs), '-c', 'release']
    subprocess.run(command, cwd=ROOT, env=environment, check=True)
    products = Path(subprocess.check_output(command + ['--show-bin-path'], cwd=ROOT, env=environment).decode().strip())
    destination.parent.mkdir(parents=True, exist_ok=True)
    contents = destination / 'Contents'
    macos = contents / 'MacOS'
    resources = contents / 'Resources'
    macos.mkdir(parents=True)
    resources.mkdir()
    for executable in ('inkyImager', 'inkyImagerHelper'):
        shutil.copyfile(products / executable, macos / executable)
        (macos / executable).chmod(0o755)
        linked = subprocess.check_output(['/usr/bin/otool', '-L', str(macos / executable)]).decode()
        require('/opt/homebrew/' not in linked and '/usr/local/' not in linked, 'Developer-only dynamic dependency')
    # APFS clone avoids another physical copy of the large image on the development Mac.
    target_image = resources / 'InkyOS.img.xz'
    clone = subprocess.run(['/bin/cp', '-c', str(args.image.resolve()), str(target_image)], capture_output=True)
    if clone.returncode:
        require(not target_image.exists(), 'Partial resource copy exists')
        shutil.copyfile(args.image, target_image)
    require(digest(target_image) == manifest['compressedSHA256'], 'Copied resource checksum mismatch')
    (resources / 'InkyOS.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    (resources / 'NOTICE.txt').write_text('inkyImager uses the macOS system liblzma for XZ decoding.\nInkyOS includes Raspberry Pi OS and Inky Studio; copyright notices are retained in the image.\n')
    # The unchanged reviewed icon is versioned. Regenerating it through the
    # Swift interpreter during every package build needlessly spikes memory.
    icon = ROOT / 'Resources/AppIcon.icns'
    icon_data = icon.read_bytes()
    require(8 <= len(icon_data) <= 8 * 1024**2 and icon_data[:4] == b'icns' and
            struct.unpack('>I', icon_data[4:8])[0] == len(icon_data), 'Invalid reviewed ICNS resource')
    shutil.copyfile(icon, resources / 'AppIcon.icns')
    info = {'CFBundleName': 'inkyImager', 'CFBundleDisplayName': 'inkyImager',
            'CFBundleIdentifier': 'fr.mehdiguiard.inkyimager', 'CFBundleExecutable': 'inkyImager',
            'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': args.app_version,
            'CFBundleVersion': args.build_number, 'LSMinimumSystemVersion': '14.0',
            'CFBundleIconFile': 'AppIcon',
            'NSHighResolutionCapable': True,
            'NSRemovableVolumesUsageDescription': 'inkyImager prépare uniquement la carte SD que vous sélectionnez.',
            'NSHumanReadableCopyright': 'Copyright © 2026 Mehdi Guiard'}
    with (contents / 'Info.plist').open('wb') as stream:
        plistlib.dump(info, stream)
    signing = ['/usr/bin/codesign', '--force', '--sign', args.sign_identity]
    signing += ['--options', 'runtime', '--timestamp'] if args.timestamp else ['--timestamp=none']
    subprocess.run(signing + [str(macos / 'inkyImagerHelper')], check=True)
    subprocess.run(signing + [str(destination)], check=True)
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(destination)], check=True)
    print(json.dumps({'app': str(destination), 'image_sha256': manifest['imageSHA256'],
                      'compressed_sha256': manifest['compressedSHA256'], 'signed_local': True,
                      'app_version': args.app_version, 'build_number': args.build_number,
                      'signature_kind': 'ad_hoc' if args.sign_identity == '-' else 'developer_id',
                      'timestamped': args.timestamp, 'notarized': False, 'sd_written': False}, sort_keys=True))


if __name__ == '__main__':
    main()
