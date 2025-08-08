pipeline {
    agent any
    tools {
        maven 'Maven3'
        jdk 'Java17'
    }
    environment {
        DOCKER_HUB_USERNAME = 'johankarl'
        DOCKER_HUB_CRED_ID = 'dockerhub'
        JMETER_HOME = '/opt/jmeter'
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://192.168.91.129:9000'
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'
        KUBE_NAMESPACE = 'exam-namespace'
        ZAP_JOB_PREFIX = 'owasp-zap-automation'
        // KUBECONFIG_CRED_ID = 'kubeconfig-file' // Removed as per your request
    }

    stages {
        stage('Nettoyage') {
            steps { cleanWs() }
        }

        stage('Checkout') {
            steps {
                git branch: 'sprint-1', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Linting Dockerfiles') {
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
                    for (df in dockerfiles) {
                        sh "docker run --rm -i hadolint/hadolint < ${df} || true"
                    }
                }
            }
        }
        
        stage('Build Maven') {
            steps {
                script {
                    def commons = ['backend/common-exam', 'backend/common-service', 'backend/common-student']
                    commons.each { dir(it) { sh 'mvn clean install -DskipTests' } }

                    def services = [
                        'backend/eureka-service',
                        'backend/api-gateway-service',
                        'backend/answer-service',
                        'backend/exam-service',
                        'backend/course-service',
                        'backend/user-service'
                    ]
                    def jobs = [:]
                    services.each { svc -> jobs[svc] = { dir(svc) { sh 'mvn clean install -DskipTests' } } }
                    parallel jobs
                }
            }
        }

        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        def javaServices = ['api-gateway-service', 'answer-service', 'course-service',
                                            'eureka-service', 'exam-service', 'user-service']
                        parallel javaServices.collectEntries { svc ->
                            [svc, {
                                dir("backend/${svc}") {
                                    withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                        sh "mvn sonar:sonar -Dsonar.projectKey=exam-${svc} -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}"
                                    }
                                }
                            }]
                        }

                        dir("frontend") {
                            withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                            }
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                // Keeping your original docker compose build as requested.
                // Ensure your docker-compose.yml correctly references the Dockerfiles.
                sh "docker compose -f ${DOCKER_COMPOSE_FILE} build"
            }
        }

        stage('Tests de charge JMeter') {
             steps {
                     sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l load_results.jtl -e -o jmeter-load-report"
                     archiveArtifacts artifacts: 'load_results.jtl,jmeter-load-report/**', allowEmptyArchive: true
             }
        }

        stage('Trivy Scan') {
            steps {
                script {
                    def images = [
                        "exam-eureka-service",
                        "exam-api-gateway-service",
                        "exam-answer-service",
                        "exam-exam-service",
                        "exam-course-service",
                        "exam-user-service",
                        "exam-frontend"
                    ]
                    def trivyJobs = [:]
                    images.each { img ->
                        trivyJobs[img] = {
                            sh "trivy image --format json --timeout 15m --output trivy-${img}.json ${img}"
                        }
                    }
                    parallel trivyJobs

                    sh '''
                        for f in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$f" | grep -q .; then
                                echo "Vulnérabilités critiques trouvées dans $f. Le pipeline continue mais soyez vigilant."
                            else
                                echo "Aucune vulnérabilité critique détectée dans $f."
                            fi
                        done
                    '''
                    archiveArtifacts artifacts: 'trivy-*.json'
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    def services = [
                        'eureka-service', 'api-gateway-service', 'answer-service',
                        'exam-service', 'course-service', 'user-service', 'frontend'
                    ]
                    def pushJobs = [:]
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CRED_ID,
                                                    usernameVariable: 'DOCKER_USERNAME',
                                                    passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh "echo \"$DOCKER_PASSWORD\" | docker login -u \"$DOCKER_USERNAME\" --password-stdin"
                        services.each { svc ->
                            def local = "exam-${svc}"
                            def remote = "${DOCKER_HUB_USERNAME}/${local}"
                            pushJobs[svc] = {
                                sh "docker tag ${local} ${remote}:latest && docker push ${remote}:latest"
                            }
                        }
                        parallel pushJobs
                        sh "docker logout"
                    }
                }
            }
        }

        stage('Archive Manifests') {
            steps {
                archiveArtifacts artifacts: 'k8s/**', allowEmptyArchive: false
            }
        }

        // --- STAGE DE PRÉPARATION DU NAMESPACE SANS KUBECONFIG_FILE ---
        stage('Préparation Namespace Kubernetes') {
            steps {
                script {
                    echo "Vérification et création du namespace ${KUBE_NAMESPACE}..."
                    // Crée le namespace s'il n'existe pas, ou ne fait rien s'il existe déjà
                    sh "kubectl create namespace ${KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                }
            }
        }
        // --- FIN DU STAGE ---

        stage('Déploiement Kubernetes') {
            steps {
                script {
                    try {
                        echo "Déploiement de la configuration MetalLB (IP pool + L2Advertisement)..."
                        sh """
                            kubectl apply -f k8s/metallb-config.yaml -n metallb-system
                        """
                        echo "Déploiement des ressources de persistance pour MongoDB..."
                        // Déploiement des ressources de persistance pour MongoDB en premier
                        // Le PV doit être appliqué avant le PVC
                        sh """
                            kubectl apply -f k8s/answer-service/mongo-answer-pv.yaml -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml -n ${KUBE_NAMESPACE}
                        """

                        // --- Ajout des autres bases de données si elles existent dans vos k8s/ dossiers ---
                        echo "Déploiement des ressources de persistance pour MySQL (exam-service)..."
                        sh """
                            kubectl apply -f k8s/exam-service/mysql-exam-db-pv.yaml -n ${KUBE_NAMESPACE} || true
                            kubectl apply -f k8s/exam-service/mysql-exam-db-pvc.yaml -n ${KUBE_NAMESPACE}
                        """

                        echo "Déploiement des ressources de persistance pour PostgreSQL (user-service)..."
                        sh """
                            kubectl apply -f k8s/user-service/postgres-user-db-pv.yaml -n ${KUBE_NAMESPACE} || true
                            kubectl apply -f k8s/user-service/postgres-user-db-pvc.yaml -n ${KUBE_NAMESPACE}
                        """
                        // --- Fin de l'ajout des autres bases de données ---

                        echo "Déploiement de MongoDB pour answer-service..."
                        sh """
                            kubectl apply -f k8s/answer-service/mongo-answer-db-deployment.yaml -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/answer-service/mongo-answer-db-service.yaml -n ${KUBE_NAMESPACE}
                            # Attendre que le déploiement de MongoDB soit prêt
                            kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=300s -n ${KUBE_NAMESPACE} || true
                        """

                        // --- Déploiement des autres bases de données et attente ---
                        echo "Déploiement de MySQL pour exam-service..."
                        sh """
                            kubectl apply -f k8s/exam-service/mysql-exam-db-deployment.yaml -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/exam-service/mysql-exam-db-service.yaml -n ${KUBE_NAMESPACE}
                            kubectl wait --for=condition=Available deployment/mysql-exam-db --timeout=300s -n ${KUBE_NAMESPACE} || true
                        """

                        echo "Déploiement de PostgreSQL pour user-service..."
                        sh """
                            kubectl apply -f k8s/user-service/postgres-user-db-deployment.yaml -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/user-service/postgres-user-db-service.yaml -n ${KUBE_NAMESPACE}
                            kubectl wait --for=condition=Available deployment/postgres-user-db --timeout=300s -n ${KUBE_NAMESPACE} || true
                        """
                        // --- Fin de l'ajout des autres bases de données ---

                        echo "Déploiement des services applicatifs principaux (Eureka, API Gateway, Frontend, Answer-Service)..."
                        // Déploiement des services applicatifs principaux
                        sh """
                            kubectl apply -f k8s/eureka/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/api-gateway/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/frontend/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/answer-service/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/exam-service/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/course-service/ -n ${KUBE_NAMESPACE}
                            kubectl apply -f k8s/user-service/ -n ${KUBE_NAMESPACE}
                        """

                        echo "Déploiement de l'ingress..."
                        // Déploiement de l'ingress
                        sh "kubectl apply -f k8s/ingress.yaml -n ${KUBE_NAMESPACE}"

                        echo "Vérification du statut des déploiements..."
                        // Vérification du statut des déploiements principaux
                        def deployments = [
                            'mongo-answer-db', 'mysql-exam-db', 'postgres-user-db', // Added other DBs
                            'eureka-service', 'api-gateway-service', 'frontend',
                            'answer-service', 'exam-service', 'course-service', 'user-service' // Added other services
                        ]
                        deployments.each { dep ->
                            sh "kubectl rollout status deployment/${dep} -n ${KUBE_NAMESPACE} --timeout=300s || true"
                        }

                    } catch (Exception e) {
                        echo "Erreur lors du déploiement: ${e.toString()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    post {
    always {
            echo "Fin du pipeline CI/CD"
            script {
                try {
                    // Suppression éventuelle du job ZAP (désactivé)
                    // def ZAP_JOB_NAME = "${ZAP_JOB_PREFIX}-${BUILD_NUMBER}"
                    // sh "kubectl delete job ${ZAP_JOB_NAME} -n ${KUBE_NAMESPACE} --ignore-not-found=true"
                } catch (Exception e) {
                    echo "Erreur lors du nettoyage: ${e.toString()}"
                }
            }
        }
        success {
            echo "Pipeline CI/CD réussi"
            emailext(
                subject: "✅ Build Réussi - #${env.BUILD_NUMBER}",
                body: """
                    <p>Le job <b>${env.JOB_NAME}</b> s'est terminé avec succès.</p>
                    <p>Voir les logs : <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                """,
                mimeType: 'text/html',
                to: 'johankarlkassa@gmail.com'
            )
        }
        failure {
            echo "Pipeline CI/CD échoué"
            emailext(
                subject: "❌ Échec du Build - #${env.BUILD_NUMBER}",
                body: """
                    <p>Le job <b>${env.JOB_NAME}</b> a échoué.</p>
                    <p>Voir les logs : <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                """,
                mimeType: 'text/html',
                attachmentsPattern: 'zap_report.json,trivy.json,jmeter-report.html',
                to: 'johankarlkassa@gmail.com'
            )
        }
        unstable {
            echo "Pipeline CI/CD instable"
            emailext(
                subject: "⚠️ Build Instable - #${env.BUILD_NUMBER}",
                body: """
                    <p>Le job <b>${env.JOB_NAME}</b> est instable.</p>
                    <p>Consultez les détails : <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                """,
                mimeType: 'text/html',
                to: 'johankarlkassa@gmail.com'
            )
        }
    }
}
