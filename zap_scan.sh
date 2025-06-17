#!/bin/bash
TARGET_URL=${1:-http://localhost:8090}
REPORT_FILE_JSON=${2:-zap_report.json}

echo "🔍 Démarrage du scan ZAP sur ${TARGET_URL}..."

# Ajuster les permissions du répertoire courant
chmod -R a+w "$(pwd)"

docker run --rm \
  --network host \
  -v "$(pwd):/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd -autorun /zap/wrk/zap-automation.yml

echo "✅ Scan terminé. Rapport disponible: ${REPORT_FILE_JSON}"