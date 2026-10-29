import hashlib
import importlib.util
import lzma
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('verify_app', Path(__file__).parents[1] / 'verify-app.py')
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


class ImageArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.image = Path(self.temp.name) / 'InkyOS.img.xz'
        self.raw = b'synthetic public image bytes\0' * 8192
        self.pin = hashlib.sha256(self.raw).hexdigest()
        self.image.write_bytes(lzma.compress(self.raw))
        self.manifest = {'schemaVersion': 1, 'configurationFile': 'inky-imager.json',
                         'imageFile': self.image.name, 'imageBytes': len(self.raw),
                         'imageSHA256': self.pin, 'compressedSHA256': verifier.digest(self.image)}

    def test_real_xz_stream_and_raw_pin_are_verified(self):
        result = verifier.inspect_image(self.image, self.manifest, self.pin)
        self.assertEqual(result['raw_bytes'], len(self.raw))
        self.assertEqual(result['raw_sha256'], self.pin)

    def test_altered_compressed_resource_is_refused(self):
        self.image.write_bytes(self.image.read_bytes()[:-1] + b'X')
        with self.assertRaisesRegex(ValueError, 'Compressed image checksum'):
            verifier.inspect_image(self.image, self.manifest, self.pin)

    def test_consistent_but_wrong_image_does_not_replace_selected_release(self):
        other = b'a different valid compressed image'
        self.image.write_bytes(lzma.compress(other))
        self.manifest.update(imageBytes=len(other), imageSHA256=hashlib.sha256(other).hexdigest(),
                             compressedSHA256=verifier.digest(self.image))
        with self.assertRaisesRegex(ValueError, 'selected generic image'):
            verifier.inspect_image(self.image, self.manifest, self.pin)

    def test_wrong_raw_size_is_refused(self):
        self.manifest['imageBytes'] -= 1
        with self.assertRaisesRegex(ValueError, 'exceeds manifest size'):
            verifier.inspect_image(self.image, self.manifest, self.pin)

    def test_truncated_xz_even_with_matching_compressed_hash_is_refused(self):
        self.image.write_bytes(self.image.read_bytes()[:-12])
        self.manifest['compressedSHA256'] = verifier.digest(self.image)
        with self.assertRaises((EOFError, lzma.LZMAError)):
            verifier.inspect_image(self.image, self.manifest, self.pin)


if __name__ == '__main__':
    unittest.main()
