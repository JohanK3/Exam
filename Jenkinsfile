pipeline {
    agent any

    tools {
        maven 'Maven3' // Vérifiez le nom exact de votre installation Maven
        jdk 'Java17'   // Vérifiez le nom exact de votre installation JDK
    }

    environment {
        // Variables d'environnement pour Docker Hub
        DOCKER_HUB_USERNAME = 'johankarl' // Votre nom d'utilisateur Docker Hub
        DOCKER_HUB_CRED_ID = 'dockerhub' // ID de vos identifiants Docker Hub configurés dans Jenkins

        // Variables pour SonarQube (à vérifier avec votre configuration Jenkins)
        // Elles sont conservées pour quand vous décommenterez la stage SonarQube
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Nom de votre SonarQube Scanner Tool
        SONAR_HOST_URL = 'http://sonarqube-service:9000' // URL du service SonarQube dans le cluster Kubernetes (interne)
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // ID de votre Secret Token SonarQube dans Jenkins

        // Variables pour ZAP
        ZAP_TARGET_URL = 'http://localhost:8090' // À adapter pour K8s si vous y faites des scans dynamiques
        ZAP_REPORT_FILE = 'zap_report.json'
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
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || true"
                    }
                }
            }
        }

        stage('Compilation Maven') {
            steps {
                script {
                    def commonModules = [
                        'backend/common-exam',
                        'backend/common-service',
                        'backend/common-student'
                    ]
                    for (module in commonModules) {
                        dir(module) {
                            sh 'mvn clean install -DskipTests'
                        }
                    }

                    def serviceModules = [
                        'backend/eureka-service',
                        'backend/api-gateway-service',
                        'backend/answer-service',
                        'backend/exam-service',
                        'backend/course-service',
                        'backend/user-service'
                    ]
                    def parallelJobs = [:]
                    for (module in serviceModules) {
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
                script {
                    echo "Construction des images Docker..."
                    def servicesToBuild = [
                        'eureka-service': 'exam-eureka-service',
                        'api-gateway-service': 'exam-api-gateway',
                        'answer-service': 'exam-answer-service',
                        'exam-service': 'exam-exam-service',
                        'course-service': 'exam-course-service',
                        'user-service': 'exam-user-service',
                        'frontend': 'exam-frontend'
                    ]

                    for (serviceDir, imageNameSuffix in servicesToBuild) {
                        // Utilise la base du chemin 'backend/' si le service n'est pas 'frontend'
                        def baseDir = (serviceDir == 'frontend') ? "frontend" : "backend/${serviceDir}"
                        dir(baseDir) {
                            sh "docker build -t ${DOCKER_HUB_USERNAME}/${imageNameSuffix}:latest ."
                        }
                    }
                }
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    def imagesToScan = [
                        "${DOCKER_HUB_USERNAME}/exam-eureka-service:latest",
                        "${DOCKER_HUB_USERNAME}/exam-api-gateway:latest",
                        "${DOCKER_HUB_USERNAME}/exam-answer-service:latest",
                        "${DOCKER_HUB_USERNAME}/exam-exam-service:latest",
                        "${DOCKER_HUB_USERNAME}/exam-course-service:latest",
                        "${DOCKER_HUB_USERNAME}/exam-user-service:latest",
                        "${DOCKER_HUB_USERNAME}/exam-frontend:latest"
                    ]

                    for (image in imagesToScan) {
                        echo "Lancement du scan Trivy pour l'image: ${image}"
                        sh "trivy image --format json --output trivy-${image.replaceAll('/', '-').replaceAll(':', '_')}.json ${image}"
                    }

                    sh '''
                        for report in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$report" | grep -q .; then
                                echo "ERREUR: Vulnérabilités critiques détectées dans $report. Échec du pipeline."
                                exit 1
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
                        sh "echo \"$DOCKER_PASSWORD\" | docker login -u \"$DOCKER_USERNAME\" --password-stdin"

                        def imagesToPush = [
                            "${DOCKER_HUB_USERNAME}/exam-eureka-service:latest",
                            "${DOCKER_HUB_USERNAME}/exam-api-gateway:latest",
                            "${DOCKER_HUB_USERNAME}/exam-answer-service:latest",
                            "${DOCKER_HUB_USERNAME}/exam-exam-service:latest",
                            "${DOCKER_HUB_USERNAME}/exam-course-service:latest",
                            "${DOCKER_HUB_USERNAME}/exam-user-service:latest",
                            "${DOCKER_HUB_USERNAME}/exam-frontend:latest"
                        ]

                        for (image in imagesToPush) {
                            echo "Publication de l'image : ${image}"
                            sh "docker push ${image} || { echo 'Échec du push pour ${image}'; exit 1; }"
                        }
                        sh 'docker logout'
                    }
                }
            }
        }

        // --- DÉBUT DE LA SECTION SONARQUBE COMMENTÉE ---
        /*
        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        def servicesToScan = [
                            'api-gateway-service',
                            'answer-service',
                            'course-service',
                            'eureka-service',
                            'exam-service',
                            'user-service'
                        ]
                        for (serviceDir in servicesToScan) {
                            echo "Lancement de l'analyse SonarQube pour ${serviceDir}..."
                            dir("backend/${serviceDir}") {
                                sh "mvn sonar:sonar -Dsonar.projectKey=exam-${serviceDir} -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=${env.SONAR_TOKEN_CRED_ID}"
                            }
                        }
                        // Si vous avez un sonar-project.properties dans frontend
                        // dir("frontend") {
                        //     sh "${tools.get(env.SONAR_SCANNER_NAME).getHome()}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=${env.SONAR_TOKEN_CRED_ID}"
                        // }
                    }
                }
            }
        }
        */
        // --- FIN DE LA SECTION SONARQUBE COMMENTÉE ---

        stage('Déploiement sur Kubernetes (Minikube)') {
            steps {
                script {
                    echo "Déploiement sur Kubernetes (Minikube)..."

                    sh 'minikube status || minikube start'
                    sh 'minikube addons enable ingress || true'

                    echo "Application des manifests des bases de données et des PVCs..."
                    sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml'
                    sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-deployment.yaml'
                    sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-service.yaml'

                    sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-pvc.yaml'
                    sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-deployment.yaml'
                    sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-service.yaml'

                    sh 'kubectl apply -f k8s/user-service/postgres-user-db-pvc.yaml'
                    sh 'kubectl apply -f k8s/user-service/postgres-user-db-deployment.yaml'
                    sh 'kubectl apply -f k8s/user-service/postgres-user-db-service.yaml'

                    sh 'kubectl apply -f k8s/sonarqube/sonar-db-pvc.yaml'
                    sh 'kubectl apply -f k8s/sonarqube/sonar-db-deployment.yaml'
                    sh 'kubectl apply -f k8s/sonarqube/sonar-db-service.yaml'
                    sh 'kubectl apply -f k8s/sonarqube/sonarqube-data-pvc.yaml'
                    sh 'kubectl apply -f k8s/sonarqube/sonarqube-extensions-pvc.yaml'


                    echo "Attente des déploiements des bases de données..."
                    sh 'kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/mysql-exam-db --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/postgres-user-db --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/sonar-db --timeout=300s || true'


                    echo "Application des manifests des services d'infrastructure et principaux..."
                    sh 'kubectl apply -f k8s/eureka/'
                    sh 'kubectl apply -f k8s/api-gateway/'
                    sh 'kubectl apply -f k8s/frontend/'
                    sh 'kubectl apply -f k8s/sonarqube/deployment.yaml'
                    sh 'kubectl apply -f k8s/sonarqube/service.yaml'

                    echo "Attente du déploiement d'Eureka et SonarQube..."
                    sh 'kubectl wait --for=condition=Available deployment/eureka-service --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/sonarqube --timeout=600s || true'


                    echo "Application des manifests des services métiers..."
                    sh 'kubectl apply -f k8s/answer-service/deployment.yaml'
                    sh 'kubectl apply -f k8s/answer-service/service.yaml'
                    sh 'kubectl apply -f k8s/exam-service/deployment.yaml'
                    sh 'kubectl apply -f k8s/exam-service/service.yaml'
                    sh 'kubectl apply -f k8s/course-service/deployment.yaml'
                    sh 'kubectl apply -f k8s/course-service/service.yaml'
                    sh 'kubectl apply -f k8s/user-service/deployment.yaml'
                    sh 'kubectl apply -f k8s/user-service/service.yaml'

                    echo "Attente des déploiements de tous les services métiers..."
                    sh 'kubectl wait --for=condition=Available deployment/answer-service --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/exam-service --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/course-service --timeout=300s || true'
                    sh 'kubectl wait --for=condition=Available deployment/user-service --timeout=300s || true'

                    echo "Application du manifest Ingress..."
                    sh 'kubectl apply -f k8s/ingress.yaml'
                }
            }
        }

        stage('Tests de charge JMeter (sur Kubernetes)') {
            steps {
                script {
                    echo "Exécution des tests de charge JMeter sur les services déployés sur Kubernetes..."
                    def minikubeIp = sh(returnStdout: true, script: 'minikube ip').trim()
                    def apiGatewayUrl = "http://${minikubeIp}/api"

                    echo "URL cible pour JMeter: ${apiGatewayUrl}"
                    sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -Jtarget.url=${apiGatewayUrl} -l results.jtl -e -o report"
                    archiveArtifacts artifacts: 'report/**,results.jtl', allowEmptyArchive: true
                }
            }
        }

        stage('Scan de sécurité OWASP ZAP (sur Kubernetes)') {
            steps {
                script {
                    echo "Lancement du scan OWASP ZAP sur les services déployés sur Kubernetes..."
                    def minikubeIp = sh(returnStdout: true, script: 'minikube ip').trim()
                    def apiGatewayUrl = "http://${minikubeIp}/api"

                    echo "URL cible pour ZAP: ${apiGatewayUrl}"
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${apiGatewayUrl} ${ZAP_REPORT_FILE}
                        if jq '.alerts[] | select(.risk == "High" or .risk == "Critical")' "${ZAP_REPORT_FILE}" | grep -q .; then
                            echo "ERREUR: Vulnérabilités critiques ou élevées détectées dans ${ZAP_REPORT_FILE}. Échec du pipeline."
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
            echo "Pipeline terminé."
            echo "Vérification finale des ressources Kubernetes:"
            sh 'kubectl get pods -o wide'
            sh 'kubectl get services'
            sh 'kubectl get deployments'
            sh 'kubectl get ingress'
            sh 'minikube service list'
            sh 'minikube ip'
        }
        success {
            echo 'Pipeline réussi! Les services sont déployés sur Kubernetes.'
        }
        failure {
            echo 'Pipeline échoué! Veuillez vérifier les logs pour les erreurs.'
        }
    }
}