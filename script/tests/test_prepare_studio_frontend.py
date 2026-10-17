import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('frontend', Path(__file__).resolve().parents[1] / 'prepare_studio_frontend.py')
frontend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frontend)


def section(name, payload=b'body'):
    content = bytes([len(name)]) + name.encode() + payload
    return b'\0' + bytes([len(content)]) + content


class PlayerStripTests(unittest.TestCase):
    def test_preserves_code_data_exports_and_runtime_custom_sections(self):
        header = b'\0asm\x01\0\0\0'
        runtime = b'\x07\x01\0\x0a\x01\0\x0b\x01\0' + section('target_features') + section('swift_reflection')
        module = header + section('.debug_info') + runtime + section('name') + section('.swift_ast')
        self.assertEqual(frontend.strip_debug(module), header + runtime)
        self.assertEqual(frontend.strip_debug(header + runtime), header + runtime)

    def test_rejects_truncated_and_invalid_modules(self):
        for value in [b'html', b'\0asm\x01\0\0\0\x0a\x05\0', b'\0asm\x01\0\0\0\0\x01\x08']:
            with self.assertRaises(ValueError):
                frontend.strip_debug(value)


if __name__ == '__main__':
    unittest.main()
