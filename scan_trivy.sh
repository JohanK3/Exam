#!/bin/bash
set -e

# Récupérer les noms des images construites localement avec le préfixe exam-
echo "Récupération des images générées par docker-compose..."
images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^exam-" | sort -u)

if [ -z "$images" ]; then
    echo "[ERROR] Aucune image trouvée avec le préfixe 'exam-'. Assurez-vous que 'docker-compose build' a été exécuté."
    exit 1
fi

# Scanner les images avec un timeout plus long
for image_name in $images; do
    echo "Scan de l'image $image_name avec Trivy..."
    # Générer un nom de fichier basé sur le nom du service (par exemple, exam-eureka-service -> trivy-eureka-service.json)
    service_name=$(echo "$image_name" | sed 's/exam-//g' | cut -d':' -f1)
    # Utiliser --format json pour la sortie JSON
    # Le --exit-code 0 permet au pipeline de ne pas échouer même si des vulnérabilités sont trouvées,
    # pour le débogage. Retirez-le pour un comportement plus strict en production.
    trivy image --scanners vuln --exit-code 0 --timeout 15m0s --format json "$image_name" > "trivy-${service_name}.json"
done

echo "✅ Tous les scans Trivy sont terminés."
