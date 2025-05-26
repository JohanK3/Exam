#!/bin/bash
set -e

services=(
    "eureka-service"
    "api-gateway-service"
    "answer-service"
    "exam-service"
    "course-service"
    "user-service"
    "frontend"
)

for service in "${services[@]}"; do
    if docker image inspect "${service}:latest" >/dev/null 2>&1; then
        trivy image --scanners vuln --exit-code 0 "${service}:latest" > "trivy-${service}.txt"
    else
        echo "[ERROR] Image ${service}:latest non trouvée. Lancez d'abord 'docker-compose build'." > "trivy-${service}.txt"
        exit 1
    fi
done