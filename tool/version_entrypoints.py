"""Rinomina main.dart.js e flutter_bootstrap.js con la versione del commit.

I browser tengono in cache questi file: con un nome nuovo a ogni pubblicazione
gli utenti ricevono sempre la versione aggiornata.

Uso: python3 tool/version_entrypoints.py build/web <sha-del-commit>
"""

import sys
from pathlib import Path


def main(build_dir: str, sha: str) -> None:
    root = Path(build_dir)
    version = sha[:12]
    main_name = f"main.{version}.dart.js"
    bootstrap_name = f"flutter_bootstrap.{version}.js"

    (root / "main.dart.js").rename(root / main_name)
    bootstrap = (root / "flutter_bootstrap.js").read_text()
    updated = bootstrap.replace(
        '"mainJsPath":"main.dart.js"', f'"mainJsPath":"{main_name}"'
    )
    if updated == bootstrap:
        sys.exit("mainJsPath non trovato in flutter_bootstrap.js")
    (root / bootstrap_name).write_text(updated)
    (root / "flutter_bootstrap.js").unlink()

    index = root / "index.html"
    index.write_text(
        index.read_text().replace("flutter_bootstrap.js", bootstrap_name)
    )


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
