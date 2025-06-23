pipeline {
    agent any
    tools {
        maven 'Maven3'
        jdk 'Java17'
    }
    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'
        ZAP_REPORT_FILE = 'zap_report.json'
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'
        DOCKER_HUB_USER = 'johankarl'
        DOCKER_HUB_CRED_ID = 'dockerhub'
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Linting des Dockerfiles') {
            steps {
                script {
                    def dockerfiles = [
                        'backend/eureka-service/Dockerfile',
                        'backend/api-gateway-service/Dockerfile',
                        'backend/answer-service/Dockerfile',
                        'backend/exam-service/Dockerfile',
                        'backend/course-service/Dockerfile',
                        'backend/user-service/Dockerfile',
                        'frontend/Dockerfile'
                    ]
                    for (dockerfile in dockerfiles) {
                        echo "Lancement du linting pour ${dockerfile}"
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || echo 'Problèmes détectés dans ${dockerfile}'"
                    }
                }
            }
        }

        stage('Validation docker-compose') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} config --quiet || (echo "Erreur dans docker-compose.yml" && exit 1)'
            }
        }

        stage('Compilation Maven') {
            steps {
                script {
                    def modules = [
                        'backend/common-exam',
                        'backend/common-service',
                        'backend/common-student',
                        'backend/eureka-service',
                        'backend/api-gateway-service',
                        'backend/answer-service',
                        'backend/exam-service',
                        'backend/course-service',
                        'backend/user-service'
                    ]
                    def parallelJobs = [:]
                    for (module in modules) {
                        def moduleName = module
                        parallelJobs[moduleName] = {
                            dir(moduleName) {
                                sh 'mvn clean install -DskipTests'
                            }
                        }
                    }
                    parallel parallelJobs
                }
            }
        }

        stage('Construction des Images Docker') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build --no-cache'
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    sh '''
                        chmod +x scan_trivy.sh
                        ./scan_trivy.sh
                        for report in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$report" | grep -q .; then
                                echo "ERREUR: Vulnérabilités critiques dans $report"
                                # exit 1
                            fi
                        done
                    '''
                    archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: false
                }
            }
        }

        stage('Publication sur Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: env.DOCKER_HUB_CRED_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh '''
                            echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                            
                            for service in eureka-service api-gateway-service answer-service exam-service course-service user-service frontend; do
                                original_image="exam-${service}"
                                new_image="$DOCKER_USERNAME/exam-${service}"
                                
                                docker tag "$original_image" "$new_image"
                                docker push "$new_image" || {
                                    echo "Échec du push pour $new_image"
                                    exit 1
                                }
                                echo "Image $new_image publiée avec succès"
                            done
                            
                            docker logout
                        '''
                    }
                }
            }
        }

        stage('Déploiement Kubernetes') {
            steps {
                script {
                    sh '''
                        # Configuration explicite pour éviter les problèmes de permissions
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        kubectl config use-context minikube

                        # Déploiement structuré selon votre architecture
                        echo "=== Déploiement Eureka ==="
                        kubectl apply -f k8s/eureka/
                        
                        echo "=== Déploiement API Gateway ==="
                        kubectl apply -f k8s/api-gateway/
                        
                        echo "=== Déploiement Frontend ==="
                        kubectl apply -f k8s/frontend/
                        
                        echo "=== Déploiement Ingress ==="
                        kubectl apply -f k8s/ingress.yaml

                        # Vérification complète
                        echo "=== Résumé du déploiement ==="
                        echo "1. Pods:"
                        kubectl get pods -o wide
                        echo "\n2. Services:"
                        kubectl get svc
                        echo "\n3. Ingress:"
                        kubectl get ingress
                        
                        # Génération des URLs d'accès
                        MINIKUBE_IP=$(minikube ip)
                        FRONTEND_PORT=$(kubectl get svc frontend-service -o jsonpath='{.spec.ports[0].nodePort}')
                        echo "🌐 Frontend URL: http://${MINIKUBE_IP}:${FRONTEND_PORT}"
                    '''
                }
            }
        }

        stage('Tests de charge JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l results.jtl -e -o report"
                archiveArtifacts artifacts: 'report/**,results.jtl', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                script {
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                        if jq '.alerts[] | select(.risk == "High" or .risk == "Critical")' "${ZAP_REPORT_FILE}" | grep -q .; then
                            echo "ERREUR: Vulnérabilités dans ${ZAP_REPORT_FILE}"
                            exit 1
                        fi
                    '''
                    archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: false
                }
            }
        }
    }

    post {
        always {
            sh '''
                # Nettoyage Kubernetes
                kubectl delete -f k8s/ 2>/dev/null || true
                
                # Archivage des logs et état final
                kubectl get all > k8s-final-state.log
                docker-compose logs > docker-compose.log
            '''
            archiveArtifacts artifacts: 'k8s-final-state.log,docker-compose.log,**/target/*.jar', allowEmptyArchive: true
        }
        success {
            echo '✅ Pipeline exécuté avec succès!'
            sh '''
                echo "=== RAPPORT FINAL ==="
                echo "Applications déployées:"
                kubectl get svc -o wide
            '''
        }
        failure {
            echo '❌ Échec du pipeline!'
            sh 'kubectl describe pods | grep -A 20 "Events:"'
        }
    }
}
