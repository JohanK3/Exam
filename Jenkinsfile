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
        SONAR_HOST_URL = 'http://sonarqube-service:9000' // URL du service SonarQube dans le cluster Kubernetes (interne)
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
                echo "Construction des images Docker via docker-compose..."
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    // Les noms d'images produits par docker-compose sont comme 'exam-eureka-service'
                    // Vous devrez peut-être les tagger si vous voulez un tag ':latest' explicite
                    def imagesToScan = [
                        "exam-eureka-service:latest",
                        "exam-api-gateway-service:latest", // Corrigé pour correspondre à docker-compose.yml
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

                        // Reprise de la logique de publication de votre ancien Jenkinsfile
                        sh '''
                            # Liste des services custom à pousser (noms d'images tels que définis dans docker-compose.yml)
                            # Remarque : j'ai ajusté 'api-gateway-service' pour correspondre à votre docker-compose.yml
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

        // --- SECTION SONARQUBE COMMENTÉE (comme dans vos versions précédentes) ---
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
                                // Assurez-vous que SONAR_TOKEN_CRED_ID est bien l'ID d'un "Secret text" contenant le token
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "mvn sonar:sonar -Dsonar.projectKey=exam-${serviceDir} -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                                }
                            }
                        }
                        // Si vous avez un sonar-project.properties dans frontend
                        // dir("frontend") {
                        //      withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                        //          sh "${tools.get(env.SONAR_SCANNER_NAME).getHome()}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                        //      }
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

                    // Définir KUBECONFIG pour toutes les commandes kubectl dans ce bloc
                    withEnv(["KUBECONFIG=/home/karl/.kube/config"]) {
                        sh 'minikube status || minikube start'
                        sh 'minikube addons enable ingress || true'

                        echo "Application des manifests des bases de données et des PVCs..."
                        sh 'kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml'
                        sh 'kubectl apply -f kk8s/answer-service/mongo-answer-db-deployment.yaml'
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
                    } // Fin du bloc withEnv pour le stage de déploiement
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

                    // ZAP_TARGET_URL n'est plus utilisé en variable d'environnement Jenkins car il est calculé dynamiquement ici
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ''' + apiGatewayUrl + ''' ${ZAP_REPORT_FILE}
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
            // Définir KUBECONFIG pour les commandes kubectl dans le bloc post-build
            withEnv(["KUBECONFIG=/home/karl/.kube/config"]) {
                sh 'kubectl get pods -o wide || true' // Ajout de || true pour ne pas faire échouer le pipeline si la commande échoue
                sh 'kubectl get services || true'
                sh 'kubectl get deployments || true'
                sh 'kubectl get ingress || true'
            }
            sh 'minikube service list || true'
            sh 'minikube ip || true'
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
