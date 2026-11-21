"""Utilidades de versión y changelog.

  python3 tool/version.py version            -> imprime la versión de pubspec.yaml
  python3 tool/version.py check              -> falla si CHANGELOG.md no tiene esa versión
  python3 tool/version.py section <versión>  -> imprime la sección del CHANGELOG
"""
import re
import sys
from pathlib import Path


def pubspec_version() -> str:
    text = Path("pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.M)
    if not m:
        raise SystemExit("No se encontró 'version: X.Y.Z' en pubspec.yaml")
    return m.group(1)


def changelog_section(version: str) -> str | None:
    text = Path("CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(
        rf"^## {re.escape(version)}\b[^\n]*\n(.*?)(?=^## |\Z)", text, re.M | re.S
    )
    return m.group(1).strip() if m else None


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "version"
    if cmd == "version":
        print(pubspec_version())
    elif cmd == "check":
        v = pubspec_version()
        if changelog_section(v) is None:
            print(
                f"::error::CHANGELOG.md no tiene la sección '## {v}'. "
                "Anota los cambios de esta versión antes de publicarla."
            )
            raise SystemExit(1)
        print(f"CHANGELOG.md tiene la sección de la versión {v}")
    elif cmd == "section":
        print(changelog_section(sys.argv[2]) or "")
    else:
        raise SystemExit(f"Comando desconocido: {cmd}")


if __name__ == "__main__":
    main()
