pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        // Docker Hub
        DOCKER_HUB_USERNAME = 'johankarl'
        DOCKER_HUB_CRED_ID = 'dockerhub'
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        // SonarQube
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'

        // JMeter
        JMETER_HOME = '/opt/jmeter'

        // Helm Prometheus/Grafana
        HELM_REPO_NAME = 'prometheus-community'
        HELM_REPO_URL = 'https://prometheus-community.github.io/helm-charts'
        PROMETHEUS_CHART_NAME = 'kube-prometheus-stack'
        PROMETHEUS_RELEASE_NAME = 'prometheus'
        MONITORING_NAMESPACE = 'monitoring'

        // Chemin du fichier de configuration Kubernetes
        KUBECONFIG = '/home/karl/.kube/config'
    }

    stages {
        stage('Nettoyage') {
            steps { cleanWs() }
        }

        stage('Checkout') {
            steps {
                git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Lint & Compilation') {
            steps {
                sh 'echo "LINT BACKEND (Java)" && mvn -f backend/pom.xml checkstyle:check'
                sh 'echo "LINT FRONTEND (Angular)" && npm run lint --prefix frontend'
                sh 'echo "COMPILATION BACKEND (Java)" && mvn -f backend/pom.xml clean compile'
                sh 'echo "COMPILATION FRONTEND (Angular)" && npm install --prefix frontend && npm run build --prefix frontend'
            }
        }

        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        def services = ['api-gateway-service', 'answer-service', 'course-service', 'eureka-service', 'exam-service', 'user-service']
                        services.each {
                            dir("backend/${it}") {
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "mvn clean verify sonar:sonar -Dsonar.projectKey=exam-${it} -Dsonar.projectName=exam-${it} -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}"
                                }
                            }
                        }
                        dir("frontend") {
                            withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                sh """
                                    npm install
                                    ${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner \
                                        -Dsonar.projectKey=exam-frontend \
                                        -Dsonar.projectName=exam-frontend \
                                        -Dsonar.sources=src \
                                        -Dsonar.projectBaseDir=. \
                                        -Dsonar.language=js \
                                        -Dsonar.host.url=${SONAR_HOST_URL} \
                                        -Dsonar.login=${SONAR_TOKEN}
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CRED_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                        docker-compose -f $DOCKER_COMPOSE_FILE build
                        docker-compose -f $DOCKER_COMPOSE_FILE push
                    '''
                }
            }
        }

        stage('Scan Sécurité Trivy') {
            steps {
                sh '''
                    docker images --format '{{.Repository}}:{{.Tag}}' | grep johankarl | while read image; do
                        echo "Scan de $image"
                        trivy image --format json --timeout 15m --output trivy-${image//[:\/]/_}.json $image
                    done
                '''
                archiveArtifacts artifacts: 'trivy-*.json'
            }
        }

        stage('Déploiement Kubernetes') {
            steps {
                sh 'kubectl apply -f k8s/'
            }
        }

        stage('Déploiement Monitoring') {
            steps {
                sh '''
                    helm repo add ${HELM_REPO_NAME} ${HELM_REPO_URL} || true
                    helm repo update
                    helm upgrade --install ${PROMETHEUS_RELEASE_NAME} ${HELM_REPO_NAME}/${PROMETHEUS_CHART_NAME} --namespace ${MONITORING_NAMESPACE} --create-namespace
                    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n ${MONITORING_NAMESPACE} --timeout=300s || true
                    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus -n ${MONITORING_NAMESPACE} --timeout=300s || true
                '''
            }
        }

        stage('Tests de Charge JMeter') {
            steps {
                script {
                    def targetHost = "exam.local"
                    sh """
                        echo "[1] Test de charge FRONTEND"
                        ${JMETER_HOME}/bin/jmeter -n -t frontend.jmx -Jhost=${targetHost} -l frontend-results.jtl -e -o frontend-report

                        echo "[2] Test de charge EXAM"
                        ${JMETER_HOME}/bin/jmeter -n -t exam.jmx -Jhost=${targetHost} -l exam-results.jtl -e -o exam-report
                    """
                    archiveArtifacts artifacts: 'frontend-report/**, frontend-results.jtl, exam-report/**, exam-results.jtl'
                }
            }
        }

        stage('Scan Sécurité ZAP') {
            steps {
                sh '''
                    docker run -t owasp/zap2docker-stable zap-baseline.py -t http://exam.local -J zap-report.json || true
                '''
                archiveArtifacts artifacts: 'zap-report.json'
            }
        }
    }

    post {
        always {
            echo "Fin du pipeline"
            sh 'kubectl get all -A || true'
        }
    }
}
