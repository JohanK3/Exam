pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
        // Suppression de la déclaration de l'outil SonarQube Scanner d'ici.
        // La fonction `tool env.SONAR_SCANNER_NAME` dans les étapes du pipeline
        // trouvera l'outil via sa configuration dans 'Global Tool Configuration'.
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'
        ZAP_REPORT_FILE = 'zap_report.html'
        DOCKER_BUILD_ID = "${env.BUILD_ID}"

        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Doit correspondre au nom configuré dans Global Tool Configuration
        SONAR_HOST_URL = 'http://192.168.110.147:9000' // L'URL de votre serveur SonarQube
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // L'ID des identifiants Secret text dans Jenkins
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                echo "Nettoyage de l'espace de travail Jenkins..."
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                echo "Récupération du code source depuis GitHub (branche sprint-3)..."
                git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Téléchargement des scripts utilitaires') {
            steps {
                echo "Téléchargement et configuration des scripts utilitaires..."
                sh '''
                    echo "Téléchargement de wait-for-it.sh..."
                    curl -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
                    chmod +x wait-for-it.sh

                    echo "Vérification/Téléchargement de zap_scan.sh..."
                    if [ ! -f zap_scan.sh ]; then
                        echo "zap_scan.sh non trouvé localement. Téléchargement depuis le dépôt (exemple)."
                    else
                        chmod +x zap_scan.sh
                    fi

                    echo "Vérification/Téléchargement de scan_trivy.sh..."
                    if [ ! -f scan_trivy.sh ]; then
                        echo "scan_trivy.sh non trouvé localement. Téléchargement depuis le dépôt (exemple)."
                    else
                        chmod +x scan_trivy.sh
                    fi
                '''
            }
        }

        stage('Linting des Dockerfiles') {
            steps {
                script {
                    echo "Lancement du linting pour les Dockerfiles avec Hadolint..."
                    def dockerfiles = [
                        'backend/eureka-service/Dockerfile', 'backend/api-gateway-service/Dockerfile',
                        'backend/answer-service/Dockerfile', 'backend/exam-service/Dockerfile',
                        'backend/course-service/Dockerfile', 'backend/user-service/Dockerfile',
                        'frontend/Dockerfile'
                    ]
                    for (dockerfile in dockerfiles) {
                        echo "  -> Linting : ${dockerfile}"
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || echo 'Problèmes détectés dans ${dockerfile}, vérifiez le rapport.'"
                    }
                }
            }
        }

        stage('Validation docker-compose') {
            steps {
                echo "Validation de la syntaxe de ${DOCKER_COMPOSE_FILE}..."
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} config --quiet || echo "Erreur dans la validation de ${DOCKER_COMPOSE_FILE}" || true'
            }
        }

        stage('Compilation Maven') {
            steps {
                script {
                    echo "Compilation des microservices Maven..."
                    def modules = [
                        'backend/common-exam', 'backend/common-service', 'backend/common-student',
                        'backend/eureka-service', 'backend/api-gateway-service', 'backend/answer-service',
                        'backend/exam-service', 'backend/course-service', 'backend/user-service'
                    ]
                    for (module in modules) {
                        dir(module) {
                            echo "  -> Compilation de : ${module}"
                            sh 'mvn clean install -DskipTests'
                        }
                    }
                }
            }
        }

        stage('Construction et démarrage Docker Compose') {
            steps {
                echo "Construction des images Docker via Docker Compose..."
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build

                    echo "Démarrage des services applicatifs via Docker Compose (y compris SonarQube)..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

                    echo "Attente de la disponibilité de l'API Gateway (${ZAP_TARGET_URL})..."
                    ./wait-for-it.sh ${ZAP_TARGET_URL#http://} --timeout=300 -- echo "Services prêts" || { echo "Timeout: services non disponibles! Le build échoue."; exit 1; }
                    
                    echo "Attente de la disponibilité de SonarQube (${SONAR_HOST_URL})..."
                    ./wait-for-it.sh ${SONAR_HOST_URL#http://} --timeout=300 -- echo "SonarQube est prêt!" || { echo "Timeout: SonarQube non disponible!"; exit 1; }
                '''
            }
        }

        stage('Analyse de Code (SonarQube)') {
            steps {
                script {
                    echo "Lancement de l'analyse SonarQube pour les modules backend..."
                    def modulesToScan = [
                        'backend/common-exam', 'backend/common-service', 'backend/common-student',
                        'backend/eureka-service', 'backend/api-gateway-service', 'backend/answer-service',
                        'backend/exam-service', 'backend/course-service', 'backend/user-service'
                    ]

                    for (modulePath in modulesToScan) {
                        dir(modulePath) {
                            echo "  -> Analyse SonarQube pour le module : ${modulePath}"
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=Exam-${modulePath.replace('/', '-')} " +
                                    "-Dsonar.sources=src/main/java " +
                                    "-Dsonar.java.binaries=target/classes " +
                                    "-Dsonar.host.url=${env.SONAR_HOST_URL} " +
                                    "-Dsonar.login=${env.SONAR_AUTH_TOKEN}"
                            }
                        }
                    }
                }
            }
            post {
                always {
                    echo "Vérification du Quality Gate SonarQube..."
                    timeout(time: 20, unit: 'MINUTES') {
                        // Quality Gate réactivé. Le pipeline attendra que SonarQube termine le traitement.
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Veuillez vérifier les rapports sur ${env.SONAR_HOST_URL}."
                }
            }
        }

        stage('Tests d’intégration JMeter') {
            steps {
                echo "Exécution des tests d'intégration JMeter..."
                sh "${JMETER_HOME}/bin/jmeter -n -t Test\\ Integration.jmx -l integration_results.jtl -e -o jmeter-integration-report"
                archiveArtifacts artifacts: 'integration_results.jtl,jmeter-integration-report/**', allowEmptyArchive: true
            }
        }

        stage('Tests de charge JMeter') {
            steps {
                echo "Exécution des tests de charge JMeter..."
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l load_results.jtl -e -o jmeter-load-report"
                archiveArtifacts artifacts: 'load_results.jtl,jmeter-load-report/**', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                echo "Lancement du scan de sécurité OWASP ZAP..."
                sh '''
                    chmod +x zap_scan.sh
                    ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE} || echo "Scan ZAP a échoué, vérifiez l'accessibilité de ${ZAP_TARGET_URL}"
                '''
                sh 'if [ -f ${ZAP_REPORT_FILE} ]; then echo "Rapport ZAP trouvé : ${ZAP_REPORT_FILE}"; else echo "Aucun rapport ZAP généré"; fi'
                archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    echo "Lancement des scans de vulnérabilités Docker avec Trivy..."
                    def dockerImages = [
                        'exam-eureka-service', 'exam-api-gateway-service', 'exam-answer-service',
                        'exam-exam-service', 'exam-course-service', 'exam-user-service',
                        'exam-frontend'
                    ]
                    for (image in dockerImages) {
                        echo "  -> Scan Trivy pour l'image : ${image}:latest"
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
            echo "Pipeline a échoué. Veuillez vérifier les logs et les rapports archivés pour plus de détails."
        }
        aborted {
            echo "Pipeline a été annulé."
        }
    }
}
