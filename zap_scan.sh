#!/bin/bash
TARGET_URL=${1:-http://localhost:8090}   # URL par défaut
REPORT_FILE_JSON=${2:-zap_report.json}   # Fichier de rapport par défaut

echo "🔍 Démarrage du scan ZAP sur ${TARGET_URL}..."

docker run --rm \
  --network host \
  -v "$(pwd):/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t "$TARGET_URL" -J "$REPORT_FILE_JSON" # Sans -g gen.conf

echo "✅ Scan terminé. Rapport disponible: ${REPORT_FILE_JSON}"