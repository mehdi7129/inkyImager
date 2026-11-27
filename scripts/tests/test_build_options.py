import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('build_app', Path(__file__).parents[1] / 'build-app.py')
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class OfflineSigningTests(unittest.TestCase):
    def arguments(self, *extra):
        # Deliberately absent resources: rejecting the signing options must
        # precede reading resources, compiling, or contacting Apple.
        return ['build-app.py', '--image', '/absent/image.xz',
                '--manifest', '/absent/manifest.json', *extra]

    def test_developer_identity_requires_explicit_timestamp_permission(self):
        with patch('sys.argv', self.arguments('--sign-identity', 'Developer ID Application: fixture')):
            with self.assertRaisesRegex(ValueError, 'explicit --timestamp'):
                builder.main()

    def test_local_adhoc_mode_cannot_request_an_apple_timestamp(self):
        with patch('sys.argv', self.arguments('--timestamp')):
            with self.assertRaisesRegex(ValueError, 'ad-hoc signing stays offline'):
                builder.main()



class LocalizationPackagingTests(unittest.TestCase):
    def test_swiftpm_lowercase_directories_are_packaged_under_canonical_names(self):
        source = builder.ROOT / 'Sources/ImagerCore/Localization'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            products = {arch: root / arch for arch in ('arm64', 'x86_64')}
            for product in products.values():
                catalogs = product / builder.RESOURCE_BUNDLE / 'Contents/Resources'
                catalogs.mkdir(parents=True)
                for path in source.glob('*.lproj'):
                    shutil.copytree(path, catalogs / path.name.lower())
            resources = root / 'packaged'
            resources.mkdir()
            builder.install_localizations(products, resources)
            catalogs = resources / builder.RESOURCE_BUNDLE / 'Contents/Resources'
            self.assertEqual({path.stem for path in catalogs.glob('*.lproj')}, builder.LOCALES)
            self.assertEqual(builder.load_catalogs(catalogs), builder.load_catalogs(source))


if __name__ == '__main__':
    unittest.main()
