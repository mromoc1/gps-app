"""Ajusta el proyecto Android generado por `flutter create`.

- Agrega el permiso de INTERNET al manifiesto principal (necesario en release).
- Pone el nombre visible de la app.
"""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")

perm = '<uses-permission android:name="android.permission.INTERNET"/>'
if perm not in text:
    start = text.index("<manifest")
    end = text.index(">", start) + 1
    text = text[:end] + "\n    " + perm + text[end:]

text = text.replace('android:label="alerto_gps"', 'android:label="Alerto GPS"')
manifest.write_text(text, encoding="utf-8")
print(text)
