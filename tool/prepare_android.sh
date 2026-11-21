#!/usr/bin/env bash
# Genera el proyecto Android, lo ajusta y deja todo listo para compilar.
set -euo pipefail

flutter create --org cl.gpsapp --project-name gps_app --platforms android .
rm -rf test
python3 tool/patch_android.py
flutter pub get
dart run flutter_launcher_icons
