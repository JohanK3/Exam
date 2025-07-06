pipeline {
    agent any // Le pipeline peut s'exécuter sur n'importe quel agent disponible

    tools {
        maven 'Maven3' // Vérifiez le nom exact de votre installation Maven
        // Désactivation de l'installation automatique du JDK par Jenkins
        // Nous allons utiliser le JDK déjà installé manuellement sur la VM
        // jdk 'Java17' // Cette ligne est maintenant commentée
    }

    environment {
        // Variables d'environnement pour Docker Hub
        DOCKER_HUB_USERNAME = 'johankarl' // Votre nom d'utilisateur Docker Hub
        DOCKER_HUB_CRED_ID = 'dockerhub' // ID de vos identifiants Docker Hub configurés dans Jenkins

        // Fichier Docker Compose
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        // Variables pour SonarQube (à vérifier avec votre configuration Jenkins)
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Nom de votre SonarQube Scanner Tool
        SONAR_HOST_URL = 'http://localhost:9000' // L'URL de SonarQube (sur la VM Jenkins)
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // ID de votre Secret Token SonarQube dans Jenkins

        // Variables pour ZAP
        JMETER_HOME = '/opt/jmeter' // Chemin vers JMeter (si non géré par Jenkins Tools)
        ZAP_REPORT_FILE = 'zap_report.json'

        // Définir JAVA_HOME explicitement pour Maven, en pointant vers ton installation OpenJDK 17
        // Assure-toi que ce chemin est correct sur ta VM !
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64' // Chemin typique pour OpenJDK 17 sur Ubuntu
        PATH = "${JAVA_HOME}/bin:${env.PATH}" // Ajoute Java au PATH
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
    }

    // Le bloc post est conservé pour les messages de fin de pipeline
    post {
        always {
            echo "Pipeline terminé."
        }
        success {
            echo 'Pipeline réussi!'
        }
        failure {
            echo 'Pipeline échoué! Veuillez vérifier les logs pour les erreurs.'
        }
    }
}
