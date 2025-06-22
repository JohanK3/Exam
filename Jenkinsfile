pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
        sonarScanner 'SonarQubeScannerCLI' // Déclaration explicite de l'outil SonarScanner
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'
        ZAP_REPORT_FILE = 'zap_report.json' // J'ai remis JSON car c'est souvent plus utile pour le parsing
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://192.168.110.147:9000' // Assurez-vous que c'est l'IP de votre VM Jenkins/SonarQube
        SONAR_TOKEN_CRED_ID = 'sonarqube-token' // ID de vos identifiants Jenkins (Secret text)
        DEEPSOURCE_TOKEN_CRED_ID = 'deepsource-access-token' // ID de vos identifiants DeepSource
        DOCKER_HUB_USER = 'johankarl' // REMPLACEZ PAR VOTRE NOM D'UTILISATEUR DOCKER HUB !
        DOCKER_HUB_CRED_ID = 'dockerhub' // ID de vos identifiants Docker Hub dans Jenkins
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
                        # curl -o zap_scan.sh https://raw.githubusercontent.com/JohanK3/Exam/sprint-3/scripts/zap_scan.sh # Adaptez le chemin si nécessaire
                        # chmod +x zap_scan.sh
                    else
                        chmod +x zap_scan.sh
                    fi

                    echo "Vérification/Téléchargement de scan_trivy.sh..."
                    if [ ! -f scan_trivy.sh ]; then
                        echo "scan_trivy.sh non trouvé localement. Téléchargement depuis le dépôt (exemple)."
                        # curl -o scan_trivy.sh https://raw.githubusercontent.com/JohanK3/Exam/sprint-3/scripts/scan_trivy.sh # Adaptez le chemin si nécessaire
                        # chmod +x scan_trivy.sh
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
                        'backend/eureka-service/Dockerfile',
                        'backend/api-gateway-service/Dockerfile',
                        'backend/answer-service/Dockerfile',
                        'backend/exam-service/Dockerfile',
                        'backend/course-service/Dockerfile',
                        'backend/user-service/Dockerfile',
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
                                echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${moduleName}"
                                sh 'mvn clean install -DskipTests'
                            }
                        }
                    }
                    parallel parallelJobs
                }
            }
        }

        stage('Analyse Statique de Code (DeepSource)') {
            steps {
                script {
                    echo "Installation du CLI DeepSource..."
                    sh 'curl https://deepsource.io/cli | sh'
                    sh 'sudo mv deepsource /usr/local/bin/'

                    echo "Authentification du CLI DeepSource..."
                    withCredentials([string(credentialsId: env.DEEPSOURCE_TOKEN_CRED_ID, variable: 'DEEPSOURCE_ACCESS_TOKEN')]) {
                        sh "deepsource auth login --token ${DEEPSOURCE_ACCESS_TOKEN}"
                    }

                    echo "Lancement de l'analyse DeepSource..."
                    sh 'deepsource run'

                    echo "Attente de la complétion de l'analyse DeepSource et vérification du Quality Gate..."
                    sh 'deepsource status --wait --timeout 600'
                }
            }
            post {
                failure {
                    echo "Le Quality Gate DeepSource a échoué. Veuillez vérifier les détails sur votre tableau de bord DeepSource."
                }
            }
        }

        stage('Préparation Environnement Docker et Démarrage Services') {
            steps {
                sh '''
                    echo "Construction des images Docker via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build

                    echo "Démarrage des services applicatifs via Docker Compose (y compris SonarQube si configuré)..."
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
                            echo "  -> Analyse SonarQube pour le module : ${modulePath}"
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=Exam-${modulePath.replace('/', '-')} " +
                                    "-Dsonar.sources=src/main/java " +
                                    "-Dsonar.java.binaries=target/classes " +
                                    "-Dsonar.host.url=${env.SONAR_HOST_URL}" // SonarQubeLogin est géré par withSonarQubeEnv
                            }
                        }
                    }
                }
            }
            post {
                always {
                    echo "Vérification du Quality Gate SonarQube..."
                    timeout(time: 20, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Veuillez vérifier les rapports sur ${env.SONAR_HOST_URL}."
                }
            }
        }

        stage('Scan de sécurité Trivy') { // DÉPLACÉ AVANT LE PUSH
            steps {
                script {
                    echo "Lancement des scans de vulnérabilités Docker avec Trivy..."
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
                        echo "  -> Scan Trivy pour l'image : ${image}:latest"
                        // Fait échouer le build si des vulnérabilités HIGH ou CRITICAL sont trouvées
                        sh "trivy image --severity HIGH,CRITICAL --exit-code 1 --format table ${image}:latest > trivy-${image.replace('exam-', '')}-report.txt"
                    }
                }
                archiveArtifacts artifacts: 'trivy-*-report.txt', allowEmptyArchive: true
            }
            post {
                failure {
                    echo "Le scan Trivy a détecté des vulnérabilités critiques. La publication sera bloquée."
                }
            }
        }

        stage('Publication sur Docker Hub') { // DÉPLACÉ APRÈS LE SCAN TRIVY
            steps {
                script {
                    echo "Authentification et publication des images sur Docker Hub..."
                    def dockerImages = [
                        'exam-eureka-service',
                        'exam-api-gateway-service',
                        'exam-answer-service',
                        'exam-exam-service',
                        'exam-course-service',
                        'exam-user-service',
                        'exam-frontend'
                    ]
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CRED_ID, usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh "echo \"${DOCKER_PASSWORD}\" | docker login -u ${DOCKER_USERNAME} --password-stdin"
                        for (image in dockerImages) {
                            def fullImageName = "${env.DOCKER_HUB_USER}/${image}:${BUILD_NUMBER}"
                            echo "  -> Tagging image ${image}:latest as ${fullImageName}"
                            sh "docker tag ${image}:latest ${fullImageName}"
                            echo "  -> Pushing image ${fullImageName} to Docker Hub"
                            sh "docker push ${fullImageName}"
                        }
                    }
                    echo "Images Docker poussées vers Docker Hub."
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
