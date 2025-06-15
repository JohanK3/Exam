#!/bin/bash
TARGET_URL=${1:-http://localhost:8090}   # URL par défaut si non spécifiée
REPORT_FILE_JSON=${2:-zap_report.json}   # Fichier de rapport par défaut (maintenant .json)

echo "🔍 Démarrage du scan ZAP sur ${TARGET_URL}..."

docker run --rm \
  --network host \
  -v "$(pwd):/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t "$TARGET_URL" -J "$REPORT_FILE_JSON" -g gen.conf # -J pour JSON

echo "✅ Scan terminé. Rapport disponible: ${REPORT_FILE_JSON}"
