"""Ajusta el proyecto Android generado por `flutter create`.

- Agrega el permiso de INTERNET al manifiesto principal (necesario en release).
- Pone el nombre visible de la app.
- Configura la firma oficial: si existe la variable ANDROID_KEYSTORE_PATH al
  compilar, el APK se firma con la llave oficial; si no, con la de depuración.
"""
from pathlib import Path

# ------------------------------------------------------------------ manifiesto
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")

perm = '<uses-permission android:name="android.permission.INTERNET"/>'
if perm not in text:
    start = text.index("<manifest")
    end = text.index(">", start) + 1
    text = text[:end] + "\n    " + perm + text[end:]

text = text.replace('android:label="gps_app"', 'android:label="GPS App"')
manifest.write_text(text, encoding="utf-8")
print("Manifiesto listo")

# ----------------------------------------------------------------------- firma
SIGNING_BLOCK = """    signingConfigs {
        create("release") {
            val storePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (storePath != null) {
                storeFile = file(storePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "gpsapp"
                keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

"""
OLD_SIGN = 'signingConfig = signingConfigs.getByName("debug")'
NEW_SIGN = (
    'signingConfig = if (System.getenv("ANDROID_KEYSTORE_PATH") != null) '
    'signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
)

gradle = Path("android/app/build.gradle.kts")
if not gradle.exists():
    raise SystemExit("No se encontró android/app/build.gradle.kts")

g = gradle.read_text(encoding="utf-8")
if 'create("release")' not in g:
    if OLD_SIGN not in g or "    buildTypes {" not in g:
        print(g)
        raise SystemExit(
            "La plantilla de Gradle cambió: no se pudo configurar la firma. "
            "Revisar tool/patch_android.py"
        )
    g = g.replace("    buildTypes {", SIGNING_BLOCK + "    buildTypes {", 1)
    g = g.replace(OLD_SIGN, NEW_SIGN)
    gradle.write_text(g, encoding="utf-8")
print("Firma configurada")
