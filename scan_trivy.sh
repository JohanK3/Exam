#!/bin/bash
trivy image eureka-service:latest > trivy-eureka-service-report.txt
trivy image api-gateway-service:latest > trivy-api-gateway-report.txt
trivy image answer-service:latest > trivy-answer-service-report.txt
trivy image exam-service:latest > trivy-exam-service-report.txt
trivy image course-service:latest > trivy-course-service-report.txt
trivy image user-service:latest > trivy-user-service-report.txt
trivy image frontend:latest > trivy-frontend-report.txt