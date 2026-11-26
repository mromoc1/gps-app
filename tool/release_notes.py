"""Arma las notas de un release a partir del CHANGELOG y de los commits.

Uso: python3 tool/release_notes.py <versión> <compilación> <apk> <sha256> \
         <huella_certificado> <firma: oficial|depuracion> <tag_anterior|-> <salida>
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from version import changelog_section  # noqa: E402

(version, build, apk, sha256, cert, signing, prev_tag, out) = sys.argv[1:9]

repo_url = "https://github.com/mromoc1/gps-app"
section = changelog_section(version) or "_Sin notas en CHANGELOG.md para esta versión._"

rev_range = f"{prev_tag}..HEAD" if prev_tag != "-" else "HEAD"
try:
    log = subprocess.run(
        ["git", "log", rev_range, "--no-merges", "--pretty=format:- %h %s"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
except subprocess.CalledProcessError:
    log = ""
if not log:
    log = "- Sin cambios de código desde la versión anterior."

firma = (
    "Firma oficial de SIRV GPS"
    if signing == "oficial"
    else "⚠️ Firma de depuración (faltan los secretos de la llave oficial)"
)

notes = f"""## Novedades de la versión {version}

{section}

## Descarga

- **{apk}** (esta versión)
- **gps-app.apk**: misma app; el enlace fijo [{repo_url}/releases/latest/download/gps-app.apk]({repo_url}/releases/latest/download/gps-app.apk) siempre baja la última versión.

Para instalar en Android: descarga el APK, ábrelo y permite instalar apps de este origen.

## Verificación

| Dato | Valor |
| --- | --- |
| Versión | {version} (compilación {build}) |
| SHA-256 del APK | `{sha256}` |
| Firma | {firma} |
| Huella del certificado (SHA-256) | `{cert or 'no disponible'}` |

## Cambios técnicos{f' desde {prev_tag}' if prev_tag != '-' else ''}

{log}
"""
Path(out).write_text(notes, encoding="utf-8")
print(notes)
