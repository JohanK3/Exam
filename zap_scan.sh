#!/bin/bash
TARGET_URL=${1:-http://localhost:8090}  # URL par défaut si non spécifiée
REPORT_FILE=${2:-zap_report.html}      # Fichier de rapport par défaut

echo "🔍 Démarrage du scan ZAP sur ${TARGET_URL}..."

docker run --rm \
  --network host \
  -v $(pwd):/zap/wrk/:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t "$TARGET_URL" -r "$REPORT_FILE" -g gen.conf

echo "✅ Scan terminé. Rapport disponible: ${REPORT_FILE}"