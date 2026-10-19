"""Local-only inbox shortcut. Nothing is added to the distributable frontend."""
import json

MARKER = b'<script type="module" src="/__dev/inbox.js"></script>'


def inject_html(data):
    if MARKER in data:
        return data
    return data.replace(b'</body>', MARKER + b'\n</body>', 1) if b'</body>' in data else data + MARKER


def script(ui):
    key = 'Open test inbox'
    catalogs = ui.parent / 'Sources/AdaEditor/Assets/Localization'
    labels = {lang: json.loads((catalogs / (lang + '.json')).read_text())[key] for lang in ('en', 'ru')}
    return ('const inboxLabels = ' + json.dumps(labels, ensure_ascii=False) + ';\n' +
            (ui / 'scripts/dev-inbox.js').read_text()).encode()
