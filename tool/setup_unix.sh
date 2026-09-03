#!/usr/bin/env bash
set -euo pipefail
flutter create . --project-name juntai --org app.juntai --platforms android,ios
flutter pub get
echo "Juntaí preparado. Rode: flutter run"
