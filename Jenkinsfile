pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
        // Assurez-vous que 'SonarQubeScannerCLI' est le nom que vous avez donné dans Jenkins Global Tool Configuration
        // sonarScanner 'SonarQubeScannerCLI' // Décommentez si vous utilisez SonarQubeScannerCLI dans ce pipeline
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'    // URL de votre application à scanner (via l'hôte Docker)
        ZAP_REPORT_FILE = 'zap_report.json'         // Nom du rapport ZAP (maintenant JSON)

        // --- Variables d'environnement pour SonarQube (si vous le réactivez) ---
        // SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        // SONAR_HOST_URL = 'http://localhost:9000'
        // SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'

        // --- Variables pour Docker Hub ---
        DOCKER_HUB_REPO = 'johankassa' // REMPLACEZ PAR VOTRE NOM D'UTILISATEUR DOCKER HUB !
        DOCKER_HUB_CREDS_ID = 'docker-hub-credentials' // ID des identifiants Docker Hub dans Jenkins

        // --- NOUVELLE VARIABLE POUR DEEPSOURCE ---
        DEEPSOURCE_TOKEN_CRED_ID = 'deepsource-access-token' // ID des identifiants DeepSource dans Jenkins
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
                                echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${moduleName}"
                                sh 'mvn clean install -DskipTests'
                            }
                        }
                    }
                    parallel parallelJobs
                }
            }
        }

        // --- NOUVELLE ÉTAPE POUR DEEPSOURCE ---
        stage('Analyse Statique de Code (DeepSource)') {
            steps {
                script {
                    echo "Installation du CLI DeepSource..."
                    // Téléchargement et installation du CLI DeepSource pour Linux
                    // Assurez-vous que l'agent Jenkins a les permissions pour exécuter curl et mv
                    sh 'curl https://deepsource.io/cli | sh'
                    sh 'mv deepsource /usr/local/bin/' // Déplace le CLI dans un répertoire du PATH

                    echo "Authentification du CLI DeepSource..."
                    // Utilise les identifiants Secret Text de Jenkins pour récupérer le token
                    withCredentials([string(credentialsId: env.DEEPSOURCE_TOKEN_CRED_ID, variable: 'DEEPSOURCE_ACCESS_TOKEN')]) {
                        sh "deepsource auth login --token ${DEEPSOURCE_ACCESS_TOKEN}"
                    }

                    echo "Lancement de l'analyse DeepSource..."
                    // Exécute l'analyse DeepSource depuis la racine du dépôt Git
                    // DeepSource lira le fichier .deepsource.toml à la racine de votre dépôt
                    sh 'deepsource run'

                    echo "Attente de la complétion de l'analyse DeepSource et vérification du Quality Gate..."
                    // 'deepsource status --wait' attend que l'analyse soit terminée.
                    // '--timeout 600' donne 10 minutes (600 secondes) maximum pour l'analyse.
                    // Le pipeline échouera si le Quality Gate de DeepSource n'est pas satisfait.
                    sh 'deepsource status --wait --timeout 600'
                }
            }
            post {
                failure {
                    echo "Le Quality Gate DeepSource a échoué. Veuillez vérifier les détails sur votre tableau de bord DeepSource."
                }
            }
        }
        // --- FIN DE L'ÉTAPE DEEPSOURCE ---

        stage('Construction et Push des Images Docker sur Docker Hub') {
            steps {
                script {
                    sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
                    echo "Images Docker de l'application construites."

                    def dockerImages = [
                        'exam-eureka-service',
                        'exam-api-gateway-service',
                        'exam-answer-service',
                        'exam-exam-service',
                        'exam-course-service',
                        'exam-user-service',
                        'exam-frontend'
                    ]

                    // S'authentifier à Docker Hub
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CREDS_ID, usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh "echo \"${DOCKER_PASSWORD}\" | docker login -u ${DOCKER_USERNAME} --password-stdin"
                    }

                    for (image in dockerImages) {
                        def fullImageName = "${env.DOCKER_HUB_REPO}/${image}:latest"
                        echo "Tagging image ${image}:latest as ${fullImageName}"
                        sh "docker tag ${image}:latest ${fullImageName}"
                        echo "Pushing image ${fullImageName} to Docker Hub"
                        sh "docker push ${fullImageName}"
                    }
                }
                echo "Images Docker poussées vers Docker Hub."
            }
        }

        stage('Démarrage des Services Applicatifs Docker Compose') {
            steps {
                sh '''
                    echo "Démarrage des services applicatifs via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

                    echo "Attente de la disponibilité de l'API Gateway (${ZAP_TARGET_URL})..."
                    for i in {1..12}; do
                        if curl --output /dev/null --silent --head --fail ${ZAP_TARGET_URL}/actuator/health; then
                            echo "API Gateway est prête."
                            break
                        fi
                        echo "En attente de ${ZAP_TARGET_URL}..."
                        sleep 10
                    done
                    if [ $i -eq 12 ]; then
                        echo "Erreur : Timeout, API Gateway non disponible."
                        exit 1
                    fi
                '''
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
                    echo "Lancement du scan ZAP sur ${env.ZAP_TARGET_URL}..."
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                        if jq '.alerts[] | select(.risk == "High" or .risk == "Critical")' "${ZAP_REPORT_FILE}" | grep -q .; then
                            echo "Erreur : Vulnérabilités critiques détectées dans ${ZAP_REPORT_FILE}"
                            exit 1
                        fi
                    '''
                    archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: false
                }
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
                                echo "Erreur : Vulnérabilités critiques détectées dans $report"
                                exit 1
                            fi
                        done
                    '''
                    archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: false
                }
            }
        }

        // --- NOUVELLES ÉTAPES POUR LE DÉPLOIEMENT KUBERNETES (Sprint 2 - US9) ---
        // Vous devrez créer le dossier kubernetes/manifests dans votre dépôt Git
        // et y placer les fichiers YAML pour vos deployments, services, etc.
        // Les images dans ces manifests devront pointer vers votre Docker Hub (ex: johankassa/exam-eureka-service:latest)

        stage('Préparation du Namespace Kubernetes') {
            steps {
                withKubeConfig(credentialsId: 'kubeconfig-sfm-connect') { // Assurez-vous d'avoir cet ID de creds dans Jenkins
                    echo "Création ou vérification du namespace Kubernetes : sfm-connect"
                    sh "kubectl create namespace sfm-connect --dry-run=client -o yaml | kubectl apply -f -"
                }
            }
        }

        stage('Déploiement des Microservices sur Kubernetes') {
            steps {
                withKubeConfig(credentialsId: 'kubeconfig-sfm-connect') {
                    echo "Déploiement des manifests Kubernetes depuis : kubernetes/manifests"
                    sh "kubectl apply -f kubernetes/manifests --namespace sfm-connect"

                    echo "Attente de la disponibilité des déploiements Kubernetes..."
                    sh "kubectl rollout status deployment/api-gateway-service --namespace sfm-connect --timeout=5m"
                    echo "Déploiements Kubernetes terminés."
                }
            }
        }

        // --- Fin des NOUVELLES ÉTAPES ---
    }

    post {
        always {
            echo "Arrêt des services Docker Compose et nettoyage..."
            sh '''
                # Arrêter et supprimer tous les conteneurs du projet
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down --rmi local -v
                # Supprimer tous les conteneurs ZAP orphelins
                docker ps -q -f name=zap | xargs -r docker rm -f
                # Nettoyer les réseaux Docker
                docker network prune -f
                # Supprimer les fichiers générés
                rm -f zap_report.json zap_out.json
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
                rm -rf .trivycache
            '''
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
            echo "Nettoyage du workspace en cours."
        }
        success {
            echo "Pipeline terminé avec SUCCÈS !"
        }
        failure {
            echo "Pipeline a échoué. Vérifiez les logs des étapes concernées et les rapports archivés."
        }
        aborted {
            echo "Pipeline a été annulé."
        }
    }
}
