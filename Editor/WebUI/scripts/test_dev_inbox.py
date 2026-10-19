from pathlib import Path
import unittest
from dev_inbox import inject_html, MARKER, script


class InboxTests(unittest.TestCase):
    def test_injection_preserves_markup_and_only_adds_one_module(self):
        original = '<html><body>Привет</body></html>'.encode()
        injected = inject_html(original)
        self.assertEqual(injected.count(MARKER), 1)
        self.assertIn('Привет'.encode(), injected)
        self.assertEqual(inject_html(injected), injected)
        self.assertNotIn(MARKER, original)

    def test_shortcut_uses_shared_language_preference_and_local_inbox(self):
        ui = Path(__file__).resolve().parents[1]
        module = script(ui).decode()
        self.assertIn('Open test inbox', module)
        self.assertIn('Открыть тестовую почту', module)
        self.assertIn('from "/__dev/localization.js"', module)
        self.assertIn('http://127.0.0.1:28088/', module)
        self.assertNotIn(MARKER, (ui / 'index.html').read_bytes())
