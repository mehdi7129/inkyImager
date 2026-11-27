#!/usr/bin/env python3
"""Verify a local app candidate without launching it or opening an SD device."""
import argparse
import hashlib
import json
import lzma
import os
from pathlib import Path
import plistlib
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
LOCALES = {'ar', 'de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pt', 'zh-Hans', 'zh-Hant'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def inspect_image(path, manifest, expected_raw_sha256):
    require(manifest['schemaVersion'] == 1 and manifest['configurationFile'] == 'inky-imager.json',
            'Unexpected manifest contract')
    require(manifest['imageFile'] == 'InkyOS.img.xz', 'Unexpected resource name')
    require(manifest['imageSHA256'] == expected_raw_sha256, 'This is not the selected generic image')
    expected_size = manifest['imageBytes']
    require(type(expected_size) is int and 0 < expected_size <= 32 * 1024**3, 'Image size out of bounds')
    require(not path.is_symlink() and path.is_file(), 'Ordinary compressed image required')
    require(digest(path) == manifest['compressedSHA256'], 'Compressed image checksum differs')
    value, size = hashlib.sha256(), 0
    with lzma.open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            size += len(block)
            require(size <= expected_size, 'Decompressed image exceeds manifest size')
            value.update(block)
    require(size == expected_size and value.hexdigest() == expected_raw_sha256,
            'Decompressed image size or checksum differs')
    return {'raw_bytes': size, 'raw_sha256': value.hexdigest(),
            'compressed_sha256': manifest['compressedSHA256']}


def inspect_executable(binary):
    require(binary.is_file() and not binary.is_symlink() and os.access(binary, os.X_OK),
            'Missing ordinary executable')
    architectures = subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).split()
    require(set(architectures) == {'arm64', 'x86_64'},
            'Universal arm64/x86_64 executable required: ' + binary.name)
    linked = subprocess.check_output(['/usr/bin/otool', '-arch', 'all', '-L', str(binary)], text=True)
    require('/opt/homebrew/' not in linked and '/usr/local/' not in linked,
            'Executable requires a developer-only dynamic library')
    return sorted(architectures)


def inspect_localizations(resources, info):
    require(info.get('CFBundleDevelopmentRegion') == 'fr' and set(info.get('CFBundleLocalizations', [])) == LOCALES,
            'Bundle language declaration differs')
    source = ROOT / 'Sources/ImagerCore/Localization'
    bundle = resources / 'inkyImager_ImagerCore.bundle/Contents/Resources'
    for container in (bundle, resources, source):
        require({path.stem for path in container.glob('*.lproj')} == LOCALES, 'Unexpected localized folders')
    french = plistlib.loads((source / 'fr.lproj/Localizable.strings').read_bytes())
    permission = info['NSRemovableVolumesUsageDescription']
    placeholder = re.compile(r'%(?:\d+\$)?[@d]')
    hashes = {}
    for language in sorted(LOCALES):
        relative = Path(f'{language}.lproj/Localizable.strings')
        expected = plistlib.loads((source / relative).read_bytes())
        installed = bundle / relative
        require(expected.keys() == french.keys() and
                all(type(text) is str and text.strip() and sorted(placeholder.findall(text)) == sorted(placeholder.findall(key))
                    for key, text in expected.items()),
                f'Invalid source strings for {language}')
        require(plistlib.loads(installed.read_bytes()) == expected, f'Packaged catalog differs for {language}')
        localized_info = plistlib.loads((resources / f'{language}.lproj/InfoPlist.strings').read_bytes())
        require(localized_info == {'NSRemovableVolumesUsageDescription': expected[permission]},
                f'Removable-volume prompt differs for {language}')
        hashes[language] = digest(installed)
    return hashes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--app-version', required=True)
    parser.add_argument('--build-number', required=True)
    parser.add_argument('--raw-sha256', required=True)
    parser.add_argument('--studio-commit', required=True)
    parser.add_argument('--os-commit', required=True)
    parser.add_argument('--personalization-schema', type=int, choices=(1, 2))
    args = parser.parse_args()
    app = args.app.resolve()
    contents = app / 'Contents'
    info = plistlib.loads((contents / 'Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'fr.mehdiguiard.inkyimager' and
            info['CFBundleExecutable'] == 'inkyImager' and
            info['CFBundleShortVersionString'] == args.app_version and
            info['CFBundleVersion'] == args.build_number and info['LSMinimumSystemVersion'] == '14.0',
            'App identity/version differs')
    require(bool(info['NSRemovableVolumesUsageDescription']), 'Removable-volume purpose is absent')
    for name in ('inkyImager', 'inkyImagerHelper'):
        binary = contents / 'MacOS' / name
        inspect_executable(binary)
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    resources = contents / 'Resources'
    manifest = json.loads((resources / 'InkyOS.json').read_text())
    personalization_schema = manifest.get('personalizationSchemaVersion', 1)
    require(type(personalization_schema) is int and personalization_schema in (1, 2) and
            (args.personalization_schema is None or personalization_schema == args.personalization_schema),
            'Image personalization schema differs')
    require(manifest['studioCommit'] == args.studio_commit and manifest['osCommit'] == args.os_commit,
            'Selected backend/OS provenance differs')
    require((resources / 'AppIcon.icns').is_file() and (resources / 'NOTICE.txt').is_file(),
            'Icon or notice is absent')
    result = inspect_image(resources / 'InkyOS.img.xz', manifest, args.raw_sha256)
    localization_sha256 = inspect_localizations(resources, info)
    print(json.dumps({'status': 'PASS', 'app_version': args.app_version, 'build_number': args.build_number,
                      'studio_commit': args.studio_commit, 'os_commit': args.os_commit, **result,
                      'personalization_schema_version': personalization_schema, 'localization_sha256': localization_sha256,
                      'architectures': ['arm64', 'x86_64'], 'signature_verified': True, 'app_launched': False, 'SD_accessed': False,
                      'notarization_or_Gatekeeper_approval_claimed': False}, sort_keys=True))


if __name__ == '__main__':
    main()
