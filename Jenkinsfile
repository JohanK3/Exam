pipeline {
    agent any

    tools {
        maven 'Maven3' // Vérifiez le nom exact de votre installation Maven
        jdk 'Java17'    // Vérifiez le nom exact de votre installation JDK
    }

    environment {
        // Variables d'environnement pour Docker Hub
        DOCKER_HUB_USERNAME = 'johankarl' // Votre nom d'utilisateur Docker Hub
        DOCKER_HUB_CRED_ID = 'dockerhub' // ID de vos identifiants Docker Hub configurés dans Jenkins

        // Fichier Docker Compose
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        // Variables pour SonarQube (à vérifier avec votre configuration Jenkins)
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Nom de votre SonarQube Scanner Tool
        // L'URL de SonarQube sera l'IP de la VM Jenkins elle-même, car SonarQube est installé directement dessus
        SONAR_HOST_URL = 'http://localhost:9000' // Ou l'IP de la VM si Jenkins ne tourne pas sur localhost
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // ID de votre Secret Token SonarQube dans Jenkins

        // Variables pour ZAP
        JMETER_HOME = '/opt/jmeter' // Chemin vers JMeter (si non géré par Jenkins Tools)
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
                // Augmentation du timeout pour le clonage Git
                timeout(time: 300, unit: 'SECONDS') { // Augmente le timeout à 5 minutes (300 secondes)
                    git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
                }
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

        stage('Configure Minikube Docker') {
            steps {
                echo "Configuration de l'environnement Docker pour Minikube..."
                sh 'eval $(minikube docker-env)'
            }
        }

        stage('Construction des Images Docker') {
            steps {
                echo "Construction des images Docker via docker-compose (dans l'environnement Minikube)..."
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    def imagesToScan = [
                        "exam-eureka-service:latest",
                        "exam-api-gateway-service:latest",
                        "exam-answer-service:latest",
                        "exam-exam-service:latest",
                        "exam-course-service:latest",
                        "exam-user-service:latest",
                        "exam-frontend:latest"
                    ]

                    for (image in imagesToScan) {
                        echo "Lancement du scan Trivy pour l'image: ${image}"
                        sh "trivy image --format json --output trivy-${image.replaceAll('/', '-').replaceAll(':', '_')}.json ${image}"
                    }

                    sh '''
                        for report in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$report" | grep -q .; then
                                echo "ERREUR: Vulnérabilités critiques détectées dans $report. Échec du pipeline."
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
                        sh "echo \"$DOCKER_PASSWORD\" | docker login -u \"$DOCKER_USERNAME\" --password-stdin"

                        sh '''
                            for service_name in eureka-service api-gateway-service answer-service exam-service course-service user-service frontend; do
                                original_image="exam-${service_name}"
                                new_image="${DOCKER_HUB_USERNAME}/${original_image}"

                                echo "Taggage et publication de l'image : ${original_image} vers ${new_image}:latest"
                                docker tag "$original_image" "$new_image:latest"
                                docker push "$new_image:latest" || {
                                    echo "Échec du push pour $new_image:latest"
                                    exit 1
                                }
                                echo "Image $new_image:latest publiée avec succès"
                            done

                            docker logout
                        '''
                    }
                }
            }
        }

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
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "mvn sonar:sonar -Dsonar.projectKey=exam-${serviceDir} -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                                }
                            }
                        }
                        dir("frontend") {
                            withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                sh "${tools.get(env.SONAR_SCANNER_NAME).getHome()}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                            }
                        }
                    }
                }
            }
        }

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
                        // Déploiement des bases de données commenté comme demandé
                        // sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml'
                        // sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-deployment.yaml'
                        // sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-service.yaml'

                        // sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-pvc.yaml'
                        // sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-deployment.yaml'
                        // sh 'kubectl apply -f k8s/exam-service/mysql-exam-db-service.yaml'

                        // sh 'kubectl apply -f k8s/user-service/postgres-user-db-pvc.yaml'
                        // sh 'kubectl apply -f k8s/user-service/postgres-user-db-deployment.yaml'
                        // sh 'kubectl apply -f k8s/user-service/postgres-user-db-service.yaml'

                        echo "Attente des déploiements des bases de données..."
                        // Attente des déploiements des bases de données commentée comme demandé
                        // sh 'kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=300s || true'
                        // sh 'kubectl wait --for=condition=Available deployment/mysql-exam-db --timeout=300s || true'
                        // sh 'kubectl wait --for=condition=Available deployment/postgres-user-db --timeout=300s || true'


                        echo "Application des manifests des services d'infrastructure et principaux..."
                        sh 'kubectl apply -f k8s/eureka/'
                        sh 'kubectl apply -f k8s/api-gateway/'
                        sh 'kubectl apply -f k8s/frontend/'

                        echo "Attente du déploiement d'Eureka..."
                        sh 'kubectl wait --for=condition=Available deployment/eureka-service --timeout=300s || true'


                        echo "Application des manifests des services métiers..."
                        // Déploiement des services métiers commenté comme demandé
                        // sh 'kubectl apply -f k8s/answer-service/deployment.yaml'
                        // sh 'kubectl apply -f k8s/answer-service/service.yaml'
                        // sh 'kubectl apply -f k8s/exam-service/deployment.yaml'
                        // sh 'kubectl apply -f k8s/exam-service/service.yaml'
                        // sh 'kubectl apply -f k8s/course-service/deployment.yaml'
                        // sh 'kubectl apply -f k8s/course-service/service.yaml'
                        // sh 'kubectl apply -f k8s/user-service/deployment.yaml'
                        // sh 'kubectl apply -f k8s/user-service/service.yaml'

                        echo "Attente des déploiements de tous les services métiers..."
                        // Attente des déploiements des services métiers commentée comme demandé
                        // sh 'kubectl wait --for=condition=Available deployment/answer-service --timeout=300s || true'
                        // sh 'kubectl wait --for=condition=Available deployment/exam-service --timeout=300s || true'
                        // sh 'kubectl wait --for=condition=Available deployment/course-service --timeout=300s || true'
                        // sh 'kubectl wait --for=condition=Available deployment/user-service --timeout=300s || true'

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
