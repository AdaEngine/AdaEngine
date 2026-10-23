"""Static selection shared by the local edge and its route contract checks."""
from pathlib import Path
from urllib.parse import unquote, urlsplit

PUBLIC = ('/games', '/create', '/projects', '/account', '/publications', '/legal', '/cloud')


def redirect(path):
    clean = urlsplit(path).path
    return '/games' if clean in ('/', '/studio', '/studio/') else None


def target(path, website, ui):
    clean = urlsplit(path).path
    if clean == '/studio' or clean.startswith('/studio/'):
        root, relative = ui, unquote(clean.removeprefix('/studio/'))
    elif any(clean == prefix or clean.startswith(prefix + '/') for prefix in PUBLIC):
        return ui / 'index.html'
    else:
        root, relative = website, unquote(clean.lstrip('/'))
    result = (root / relative).resolve()
    if not result.is_relative_to(root.resolve()):
        return root / '__missing__'
    if root == website and not result.is_file() and not result.is_dir():
        return ui / 'index.html'
    return result
