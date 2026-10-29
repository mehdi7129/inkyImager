import importlib.util
from pathlib import Path
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


if __name__ == '__main__':
    unittest.main()
