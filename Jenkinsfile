pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
        // Assure-toi que 'SonarQubeScannerCLI' est le nom que tu as donné dans
        // Jenkins > Manage Jenkins > Global Tool Configuration > SonarQube Scanners
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'
        ZAP_REPORT_FILE = 'zap_report.html'
        DOCKER_BUILD_ID = "${env.BUILD_ID}" // Id du build Jenkins, utile pour le tagging Docker

        // --- Variables d'environnement pour SonarQube ---
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Le nom configuré dans Jenkins Global Tool Configuration
        SONAR_HOST_URL = 'http://localhost:9000'   // L'URL de ton serveur SonarQube
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // L'ID de tes identifiants Jenkins (Secret text)
        // --- Fin des variables SonarQube ---
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                git branch: 'sprint-2', credentialsId: 'github-credentials', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Téléchargement des scripts utilitaires') {
            steps {
                sh '''
                    echo "Téléchargement de wait-for-it.sh..."
                    curl -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
                    chmod +x wait-for-it.sh

                    echo "Téléchargement de zap_scan.sh (exemple)..."
                    # Assure-toi que ce script existe dans ton repo ou télécharge-le d'ici si nécessaire
                    # curl -o zap_scan.sh https://raw.githubusercontent.com/ton_repo/ton_projet/zap_scan.sh
                    # chmod +x zap_scan.sh

                    echo "Téléchargement de scan_trivy.sh (exemple)..."
                    # Assure-toi que ce script existe dans ton repo ou télécharge-le d'ici si nécessaire
                    # curl -o scan_trivy.sh https://raw.githubusercontent.com/ton_repo/ton_projet/scan_trivy.sh
                    # chmod +x scan_trivy.sh
                '''
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
                        'frontend/Dockerfile' // N'oublie pas le Dockerfile du frontend si tu l'as
                    ]
                    for (dockerfile in dockerfiles) {
                        echo "Lancement du linting pour ${dockerfile}"
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || echo 'Problèmes détectés dans ${dockerfile}, vérifiez le rapport.'"
                    }
                }
            }
        }

        stage('Validation docker-compose') {
            steps {
                echo "Validation de la syntaxe de ${DOCKER_COMPOSE_FILE}"
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} config --quiet || echo "Erreur dans la validation de ${DOCKER_COMPOSE_FILE}" || true'
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
                    for (module in modules) {
                        dir(module) {
                            echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${module}"
                            sh 'mvn clean install -DskipTests'
                        }
                    }
                }
            }
        }

        stage('Analyse de Code (SonarQube)') {
            steps {
                script {
                    def modulesToScan = [
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

                    for (modulePath in modulesToScan) {
                        dir(modulePath) {
                            echo "Lancement de l'analyse SonarQube pour le module : ${modulePath}"
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=Exam-${modulePath.replace('/', '-')}" +
                                    "-Dsonar.sources=src/main/java" +
                                    "-Dsonar.java.binaries=target/classes" +
                                    "-Dsonar.host.url=${env.SONAR_HOST_URL}" +
                                    "-Dsonar.login=${env.SONAR_AUTH_TOKEN}"
                            }
                        }
                    }
                }
            }
            post {
                always {
                    echo "Vérification du Quality Gate SonarQube..."
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Vérifiez les rapports sur ${env.SONAR_HOST_URL}."
                }
            }
        }

        stage('Construction et démarrage Docker Compose') {
            steps {
                sh '''
                    echo "Construction des images Docker via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build

                    echo "Démarrage des services applicatifs via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

                    echo "Attente de la disponibilité de l'API Gateway (${ZAP_TARGET_URL})..."
                    ./wait-for-it.sh ${ZAP_TARGET_URL#http://} --timeout=180 -- echo "Services prêts" || { echo "Timeout: services non disponibles!"; exit 1; }
                '''
            }
        }

        stage('Tests d’intégration JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t Test\\ Integration.jmx -l integration_results.jtl -e -o jmeter-integration-report"
                archiveArtifacts artifacts: 'integration_results.jtl,jmeter-integration-report/**', allowEmptyArchive: true
            }
        }

        stage('Tests de charge JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l load_results.jtl -e -o jmeter-load-report"
                archiveArtifacts artifacts: 'load_results.jtl,jmeter-load-report/**', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                sh '''
                    chmod +x zap_scan.sh
                    ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE} || echo "Scan ZAP a échoué, vérifiez l'accessibilité de ${ZAP_TARGET_URL}"
                '''
                sh 'if [ -f ${ZAP_REPORT_FILE} ]; then echo "Rapport ZAP trouvé"; else echo "Aucun rapport ZAP généré"; fi'
                archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    def dockerImages = [
                        'exam-eureka-service',
                        'exam-api-gateway-service',
                        'exam-answer-service',
                        'exam-exam-service',
                        'exam-course-service',
                        'exam-user-service',
                        'exam-frontend'
                    ]
                    for (image in dockerImages) {
                        echo "Lancement du scan Trivy pour l'image : ${image}:latest"
                        sh "trivy image --severity HIGH,CRITICAL --format table ${image}:latest > trivy-${image.replace('exam-', '')}-report.txt || true"
                    }
                }
                archiveArtifacts artifacts: 'trivy-*-report.txt', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            echo "Nettoyage post-pipeline : arrêt des services Docker Compose et suppression des images temporaires..."
            sh '''
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
                docker images | grep '^exam-' | awk '{print $1":"$2}' | xargs -r docker rmi || true
                docker image prune -f || true
            '''
            archiveArtifacts artifacts: 'docker-compose.log,**/target/*.jar', allowEmptyArchive: true
        }
        success {
            echo "Pipeline terminé avec SUCCÈS !"
        }
        failure {
            echo "Pipeline a échoué. Vérifiez les logs et les rapports archivés."
        }
        aborted {
            echo "Pipeline a été annulé."
        }
    }
}
