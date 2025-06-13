pipeline {
    agent any

    tools {
        // Assurez-vous que 'Maven3' et 'Java17' sont les noms exacts
        // que vous avez configurés dans Jenkins > Manage Jenkins > Global Tool Configuration
        maven 'Maven3'
        jdk 'Java17'
        // Assurez-vous que 'SonarQubeScannerCLI' est le nom exact donné
        // dans Jenkins > Manage Jenkins > Global Tool Configuration > SonarQube Scanners
        sonarScanner 'SonarQubeScannerCLI'
    }

    environment {
        // Chemin vers votre fichier docker-compose
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        // Chemin vers l'installation de JMeter sur votre agent Jenkins
        JMETER_HOME = '/opt/jmeter'
        // URL de l'API Gateway de votre application, utilisée par ZAP et wait-for-it.sh
        ZAP_TARGET_URL = 'http://localhost:8090'
        // Nom du fichier de rapport généré par OWASP ZAP
        ZAP_REPORT_FILE = 'zap_report.html'
        // ID du build Jenkins, utile pour le tagging Docker par exemple
        DOCKER_BUILD_ID = "${env.BUILD_ID}"

        // --- Variables d'environnement pour SonarQube ---
        // Le nom configuré pour SonarQube Scanner CLI dans Jenkins Global Tool Configuration
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        // L'URL de votre serveur SonarQube (généralement son adresse IP ou localhost:9000)
        SONAR_HOST_URL = 'http://192.168.147.110:9000'
        // L'ID de vos identifiants Jenkins (Secret text) contenant le token SonarQube
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'
        // --- Fin des variables SonarQube ---
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
                // Assurez-vous que 'github-credentials' est l'ID de vos identifiants GitHub dans Jenkins
                git branch: 'sprint-3', credentialsId: 'github-credentials', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Téléchargement des scripts utilitaires') {
            steps {
                echo "Téléchargement et configuration des scripts utilitaires..."
                // Télécharge wait-for-it.sh pour attendre que les services Docker soient prêts
                sh '''
                    echo "Téléchargement de wait-for-it.sh..."
                    curl -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
                    chmod +x wait-for-it.sh

                    # Si vos scripts zap_scan.sh et scan_trivy.sh sont dans votre dépôt Git,
                    # assurez-vous qu'ils sont exécutables. Sinon, décommentez et ajustez
                    # les lignes curl pour les télécharger si nécessaire.
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
                        'frontend/Dockerfile' // N'oubliez pas le Dockerfile du frontend si vous l'avez
                    ]
                    for (dockerfile in dockerfiles) {
                        echo "  -> Linting : ${dockerfile}"
                        // Le '|| echo ...' permet d'afficher un message et de continuer le pipeline
                        // même si Hadolint trouve des problèmes (warnings ou erreurs).
                        // Pour faire échouer le pipeline en cas d'erreur de linting, supprimez '|| echo ...'.
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || echo 'Problèmes détectés dans ${dockerfile}, vérifiez le rapport.'"
                    }
                }
            }
        }

        stage('Validation docker-compose') {
            steps {
                echo "Validation de la syntaxe de ${DOCKER_COMPOSE_FILE}..."
                // 'config --quiet' valide la syntaxe sans afficher les services.
                // '|| true' permet au pipeline de continuer même si la validation échoue.
                // Supprimez '|| true' pour un comportement plus strict en cas d'erreur de validation.
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
                    for (module in modules) {
                        dir(module) {
                            echo "  -> Compilation de : ${module}"
                            // -DskipTests: Garde cette option si vous exécutez les tests Junit dans une étape séparée ou plus tard.
                            sh 'mvn clean install -DskipTests'
                        }
                    }
                }
            }
        }

        stage('Analyse de Code (SonarQube)') {
            steps {
                script {
                    echo "Lancement de l'analyse SonarQube pour les modules backend..."
                    // Liste de tous les modules backend à scanner
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

                    // Itérer sur chaque module et lancer l'analyse SonarQube
                    for (modulePath in modulesToScan) {
                        dir(modulePath) { // Se positionner dans le répertoire du module
                            echo "  -> Analyse SonarQube pour le module : ${modulePath}"
                            // Utilisation de withSonarQubeEnv pour injecter l'URL et le token
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                // Exécution du SonarScanner CLI.
                                // -Dsonar.projectKey: Identifiant unique du projet dans SonarQube.
                                //                   Utilise le chemin du module pour le rendre unique (ex: Exam-backend-course-service)
                                // -Dsonar.sources: Chemin vers le code source à analyser (par défaut le répertoire courant '.')
                                // -Dsonar.java.binaries: Chemin vers les fichiers .class compilés par Maven
                                // -Dsonar.host.url: L'URL de votre serveur SonarQube
                                // -Dsonar.login: Le token d'authentification (injecté par withSonarQubeEnv)
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=Exam-${modulePath.replace('/', '-')}" + // Ex: 'Exam-backend-course-service'
                                    "-Dsonar.sources=src/main/java" +
                                    "-Dsonar.java.binaries=target/classes" + // Important pour l'analyse Java
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
                    // Attendre la fin de l'analyse et vérifier le Quality Gate
                    // Si le Quality Gate échoue, le pipeline sera marqué en FAILURE
                    timeout(time: 10, unit: 'MINUTES') { // Donne suffisamment de temps pour que l'analyse se termine sur SonarQube
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Veuillez vérifier les rapports sur ${env.SONAR_HOST_URL}."
                    // La ligne 'currentBuild.result = 'FAILURE'' est supprimée ici
                    // car 'waitForQualityGate abortPipeline: true' gère déjà l'échec du pipeline.
                }
            }
        }

        stage('Construction et démarrage Docker Compose') {
            steps {
                echo "Construction des images Docker via Docker Compose..."
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build

                    echo "Démarrage des services applicatifs via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

                    echo "Attente de la disponibilité de l'API Gateway (${ZAP_TARGET_URL})..."
                    # Utilisation de wait-for-it.sh pour attendre la disponibilité du service
                    # ${ZAP_TARGET_URL#http://} retire le préfixe 'http://' pour wait-for-it.sh
                    ./wait-for-it.sh ${ZAP_TARGET_URL#http://} --timeout=180 -- echo "Services prêts" || { echo "Timeout: services non disponibles! Le build échoue."; exit 1; }
                '''
            }
        }

        stage('Tests d’intégration JMeter') {
            steps {
                echo "Exécution des tests d'intégration JMeter..."
                // Assurez-vous que 'Test Integration.jmx' existe et que son chemin est correct
                sh "${JMETER_HOME}/bin/jmeter -n -t Test\\ Integration.jmx -l integration_results.jtl -e -o jmeter-integration-report"
                archiveArtifacts artifacts: 'integration_results.jtl,jmeter-integration-report/**', allowEmptyArchive: true
            }
        }

        stage('Tests de charge JMeter') {
            steps {
                echo "Exécution des tests de charge JMeter..."
                // Assurez-vous que 'test.jmx' existe et que son chemin est correct
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l load_results.jtl -e -o jmeter-load-report"
                archiveArtifacts artifacts: 'load_results.jtl,jmeter-load-report/**', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                echo "Lancement du scan de sécurité OWASP ZAP..."
                // Assurez-vous que zap_scan.sh est présent et exécutable dans le workspace Jenkins
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
                        // `|| true` permet de ne pas faire échouer le build si Trivy trouve des vulnérabilités.
                        // Pour que le build échoue sur les vulnérabilités critiques/élevées, supprimez '|| true'.
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
                # Arrêter les services Docker Compose et supprimer les conteneurs
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down
                # Archiver les logs de Docker Compose pour le débogage
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
                # Supprimer les images Docker créées par le build (celles avec le préfixe 'exam-')
                docker images | grep '^exam-' | awk '{print $1":"$2}' | xargs -r docker rmi || true
                # Nettoyer les images Docker non utilisées par d'autres conteneurs actifs pour libérer de l'espace
                # Attention : 'docker image prune -f' supprime toutes les images non utilisées,
                # y compris celles qui ne sont pas liées à ce projet si elles ne sont utilisées par aucun conteneur.
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
