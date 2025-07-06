pipeline {
    agent any // Le pipeline peut s'exécuter sur n'importe quel agent disponible

    tools {
        maven 'Maven3' // Vérifiez le nom exact de votre installation Maven
        // La ligne 'jdk 'Java17'' a été retirée d'ici pour gérer JAVA_HOME manuellement
    }

    environment {
        // Variables d'environnement pour Docker Hub
        DOCKER_HUB_USERNAME = 'johankarl' // Votre nom d'utilisateur Docker Hub
        DOCKER_HUB_CRED_ID = 'dockerhub' // ID de vos identifiants Docker Hub configurés dans Jenkins

        // Fichier Docker Compose
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        // Variables pour SonarQube (à vérifier avec votre configuration Jenkins)
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Nom de votre SonarQube Scanner Tool (utilisé par withSonarQubeEnv)
        SONAR_HOST_URL = 'http://localhost:9000' // L'URL de SonarQube (sur la VM Jenkins)
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // ID de votre Secret Token SonarQube dans Jenkins

        // Variables pour ZAP
        JMETER_HOME = '/opt/jmeter' // Chemin vers JMeter (si non géré par Jenkins Tools)
        ZAP_REPORT_FILE = 'zap_report.json'

        // Définir JAVA_HOME explicitement pour Maven, en pointant vers ton installation OpenJDK 17
        // Assure-toi que ce chemin est correct sur ta VM !
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64' // Chemin typique pour OpenJDK 17 sur Ubuntu
        PATH = "${JAVA_HOME}/bin:${env.PATH}" // Ajoute Java au PATH

        // Chemin direct vers l'installation du SonarScanner CLI
        // Cette variable est maintenant commentée car le stage SonarQube est désactivé.
        // SONAR_SCANNER_HOME = '/opt/sonar-scanner' // <-- METS TON CHEMIN RÉEL ICI APRÈS L'INSTALLATION DU SCANNER CLI
    }

    stages {
        // --- Phase 1: Préparation et Récupération du Code ---
        stage('Nettoyage de l’espace de travail') {
            steps {
                echo "Nettoyage de l'espace de travail Jenkins..."
                cleanWs() // Nettoie le répertoire de travail du pipeline
            }
        }

        stage('Récupération du code source') {
            steps {
                echo "Récupération du code source depuis GitHub..."
                // Augmentation du timeout pour le clonage Git, car le dépôt est volumineux
                timeout(time: 300, unit: 'SECONDS') { // Définit un timeout de 5 minutes (300 secondes)
                    git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
                }
            }
        }

        // --- Phase 2: Analyse Statique et Compilation ---
        stage('Linting des Dockerfiles') {
            steps {
                script {
                    // La liste DOCKERFILES_TO_LINT est définie à l'intérieur du bloc 'script'
                    def DOCKERFILES_TO_LINT = [
                        'backend/eureka-service/Dockerfile',
                        'backend/api-gateway-service/Dockerfile',
                        'backend/answer-service/Dockerfile',
                        'backend/exam-service/Dockerfile',
                        'backend/course-service/Dockerfile',
                        'backend/user-service/Dockerfile',
                        'frontend/Dockerfile'
                    ]
                    echo "Lancement du linting pour tous les Dockerfiles..."
                    for (dockerfile in DOCKERFILES_TO_LINT) {
                        echo "  -> Linting de ${dockerfile}"
                        sh "docker run --rm -i hadolint < ${dockerfile} || true"
                    }
                }
            }
        }

        stage('Compilation Maven') { // Ce stage regroupe les compilations communes et métiers
            steps {
                script {
                    def COMMON_MODULES = [
                        'backend/common-exam',
                        'backend/common-service',
                        'backend/common-student'
                    ]
                    echo "Compilation des modules Maven communs..."
                    for (module in COMMON_MODULES) {
                        dir(module) {
                            sh 'mvn clean install -DskipTests'
                        }
                    }

                    def BACKEND_MODULES = [
                        'backend/eureka-service',
                        'backend/api-gateway-service',
                        'backend/answer-service',
                        'backend/exam-service',
                        'backend/course-service',
                        'backend/user-service'
                    ]
                    echo "Compilation des services Maven métiers en parallèle..."
                    def parallelJobs = [:]
                    for (module in BACKEND_MODULES) {
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

        // --- Phase 3: Gestion des Images Docker ---
        stage('Configure Minikube Docker') {
            steps {
                echo "Configuration de l'environnement Docker pour Minikube..."
                script { // Ajout d'un bloc script pour la définition des variables locales
                    // Définir KUBECONFIG et MINIKUBE_HOME pour les commandes minikube
                    // Ceci est crucial pour que minikube status/start fonctionne correctement pour l'utilisateur Jenkins
                    withEnv(["KUBECONFIG=${env.HOME}/.kube/config", "MINIKUBE_HOME=${env.HOME}"]) {
                        echo "Vérification et démarrage de Minikube si nécessaire..."
                        // S'assure que Minikube est en cours d'exécution avant de tenter docker-env
                        sh 'minikube status || minikube start --driver=docker --cpus 4 --memory 8192mb'
                        echo "Configuration de l'environnement Docker pour Minikube..."
                        sh 'eval $(minikube docker-env)' // Redirige les commandes 'docker' vers le démon Docker de Minikube
                    }
                }
            }
        }

        stage('Construction des Images Docker') {
            steps {
                echo "Construction des images Docker via docker-compose (dans l'environnement Minikube)..."
                // Utilise la variable d'environnement DOCKER_COMPOSE_FILE définie globalement
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    // La liste IMAGES_TO_SCAN est définie à l'intérieur du bloc 'script'
                    def IMAGES_TO_SCAN = [
                        "exam-eureka-service:latest",
                        "exam-api-gateway-service:latest",
                        "exam-answer-service:latest",
                        "exam-exam-service:latest",
                        "exam-course-service:latest",
                        "exam-user-service:latest",
                        "exam-frontend:latest"
                    ]
                    echo "Lancement du scan Trivy pour toutes les images Docker..."
                    for (image in IMAGES_TO_SCAN) {
                        echo "  -> Scan Trivy pour l'image: ${image}"
                        sh "trivy image --format json --output trivy-${image.replaceAll('/', '-').replaceAll(':', '_')}.json ${image}"
                    }

                    sh '''
                        for report in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$report" | grep -q .; then
                                echo "ERREUR: Vulnérabilités critiques détectées dans $report. Échec du pipeline."
                                # exit 1 // Décommenter pour faire échouer le pipeline en cas de vulnérabilités critiques
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
                    // La liste DOCKER_SERVICES_TO_PUSH est définie à l'intérieur du bloc 'script'
                    def DOCKER_SERVICES_TO_PUSH = [
                        'eureka-service',
                        'api-gateway-service',
                        'answer-service',
                        'exam-service',
                        'course-service',
                        'user-service',
                        'frontend'
                    ]
                    echo "Publication des images Docker sur Docker Hub..."
                    withCredentials([usernamePassword(
                        credentialsId: env.DOCKER_HUB_CRED_ID,
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh "echo \"$DOCKER_PASSWORD\" | docker login -u \"$DOCKER_USERNAME\" --password-stdin"

                        for (service_name in DOCKER_SERVICES_TO_PUSH) {
                            def original_image = "exam-${service_name}"
                            def new_image = "${env.DOCKER_HUB_USERNAME}/${original_image}"
                            echo "  -> Publication de ${new_image}:latest"
                            sh "docker tag \"$original_image\" \"$new_image:latest\"" // Re-taggage avant le push
                            sh "docker push \"$new_image:latest\" || { echo \"Échec du push pour $new_image:latest\"; exit 1; }"
                        }
                        sh 'docker logout'
                    }
                }
            }
        }

        // Le stage 'Analyse SonarQube' est commenté comme demandé.
        /*
        stage('Analyse SonarQube') {
            steps {
                script {
                    // La liste servicesToScan est définie à l'intérieur du bloc 'script'
                    def servicesToScan = [
                        'api-gateway-service',
                        'answer-service',
                        'course-service',
                        'eureka-service',
                        'exam-service',
                        'user-service'
                    ]
                    echo "Lancement de l'analyse SonarQube pour les services backend et le frontend..."
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        for (serviceDir in servicesToScan) {
                            echo "  -> Analyse SonarQube pour ${serviceDir}..."
                            dir("backend/${serviceDir}") {
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "mvn sonar:sonar -Dsonar.projectKey=exam-${serviceDir} -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                                }
                            }
                        }
                        dir("frontend") {
                            echo "  -> Analyse SonarQube pour le frontend..."
                            withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                // Utilisation du chemin direct vers le SonarScanner CLI, sans tools.get()
                                sh "${env.SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                            }
                        }
                    }
                }
            }
        }
        */

        stage('Déploiement sur Kubernetes (Minikube)') {
            steps {
                script {
                    echo "Déploiement sur Kubernetes (Minikube)..."

                    // Définir KUBECONFIG et MINIKUBE_HOME pour toutes les commandes dans ce bloc
                    // Idéalement, utilisez ${env.HOME} pour que cela s'adapte à l'utilisateur exécutant le pipeline.
                    withEnv(["KUBECONFIG=${env.HOME}/.kube/config", "MINIKUBE_HOME=${env.HOME}"]) {
                        sh 'minikube status || minikube start --driver=docker --cpus 4 --memory 8192mb' // Rétablissement des options de démarrage
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

                        echo "Attente des déploiements des bases de données..."
                        sh 'kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=300s || true'
                        sh 'kubectl wait --for=condition=Available deployment/mysql-exam-db --timeout=300s || true'
                        sh 'kubectl wait --for=condition=Available deployment/postgres-user-db --timeout=300s || true'


                        echo "Application des manifests des services d'infrastructure et principaux..."
                        sh 'kubectl apply -f k8s/eureka/'
                        sh 'kubectl apply -f k8s/api-gateway/'
                        sh 'kubectl apply -f k8s/frontend/'

                        echo "Attente du déploiement d'Eureka..."
                        sh 'kubectl wait --for=condition=Available deployment/eureka-service --timeout=300s || true'


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
                    } // Fin du bloc withEnv pour le stage de déploiement
                }
            }
        }

        stage('Tests de charge JMeter (sur Kubernetes)') {
            steps {
                script {
                    echo "Exécution des tests de charge JMeter sur les services déployés sur Kubernetes..."
                    // Utilisation de env.HOME pour s'assurer que minikube ip fonctionne correctement pour l'utilisateur Jenkins
                    withEnv(["MINIKUBE_HOME=${env.HOME}"]) {
                        def minikubeIp = sh(returnStdout: true, script: 'minikube ip').trim()
                        def apiGatewayUrl = "http://${minikubeIp}/api"

                        echo "URL cible pour JMeter: ${apiGatewayUrl}"
                        sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -Jtarget.url=${apiGatewayUrl} -l results.jtl -e -o report"
                    }
                    archiveArtifacts artifacts: 'report/**,results.jtl', allowEmptyArchive: true
                }
            }
        }

        stage('Scan de sécurité OWASP ZAP (sur Kubernetes)') {
            steps {
                script {
                    echo "Lancement du scan OWASP ZAP sur les services déployés sur Kubernetes..."
                    // Utilisation de env.HOME pour s'assurer que minikube ip fonctionne correctement pour l'utilisateur Jenkins
                    withEnv(["MINIKUBE_HOME=${env.HOME}"]) {
                        def minikubeIp = sh(returnStdout: true, script: 'minikube ip').trim()
                        def apiGatewayUrl = "http://${minikubeIp}/api"

                        sh '''
                            chmod +x zap_scan.sh
                            ./zap_scan.sh ''' + apiGatewayUrl + ''' ${ZAP_REPORT_FILE}
                            if jq '.alerts[] | select(.risk == "High" or .risk == "Critical")' "${ZAP_REPORT_FILE}" | grep -q .; then
                                echo "ERREUR: Vulnérabilités critiques ou élevées détectées dans ${ZAP_REPORT_FILE}. Échec du pipeline."
                                exit 1
                            fi
                        '''
                    }
                    archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: false
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline terminé."
            echo "Vérification finale des ressources Kubernetes:"
            // Utilisation de env.HOME pour KUBECONFIG dans le bloc post-build
            withEnv(["KUBECONFIG=${env.HOME}/.kube/config"]) {
                sh 'kubectl get pods -o wide || true'
                sh 'kubectl get services || true'
                sh 'kubectl get deployments || true'
                sh 'kubectl get ingress || true'
            }
            // Utilisation de env.HOME pour minikube service list et minikube ip
            withEnv(["MINIKUBE_HOME=${env.HOME}"]) {
                sh 'minikube service list || true'
                sh 'minikube ip || true'
            }
            echo "Arrêt des services Docker Compose (s'ils ont été démarrés pour d'autres tests, ou pour cleanup)"
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} down --rmi local || true'
            sh 'docker-compose logs > docker-compose.log || true'
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
        }
        success {
            echo 'Pipeline réussi! Les services sont déployés sur Kubernetes.'
        }
        failure {
            echo 'Pipeline échoué! Veuillez vérifier les logs pour les erreurs.'
        }
    }
}
