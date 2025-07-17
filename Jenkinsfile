pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        DOCKER_HUB_USERNAME = 'johankarl'
        DOCKER_HUB_CRED_ID = 'dockerhub'
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://192.168.110.149:9000'
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'

        JMETER_HOME = '/opt/jmeter'

        HELM_REPO_NAME = 'prometheus-community'
        HELM_REPO_URL = 'https://prometheus-community.github.io/helm-charts'
        PROMETHEUS_CHART_NAME = 'kube-prometheus-stack'
        PROMETHEUS_RELEASE_NAME = 'prometheus'
        MONITORING_NAMESPACE = 'monitoring'

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
                        echo "Linting ${df}"
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

        stage('Build Docker Images') {
            steps { sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build' }
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
                    def services = ['eureka-service', 'api-gateway-service', 'answer-service', 'exam-service', 'course-service', 'user-service', 'frontend']
                    def pushJobs = [:]
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CRED_ID, usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
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

        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        def services = ['api-gateway-service', 'answer-service', 'course-service', 'eureka-service', 'exam-service', 'user-service']
                        def sonarJobs = [:]
                        services.each { svc ->
                            sonarJobs[svc] = {
                                dir("backend/${svc}") {
                                    withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                        sh "mvn sonar:sonar -Dsonar.projectKey=exam-${svc} -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}"
                                    }
                                }
                            }
                        }
                        sonarJobs["frontend"] = {
                            dir("frontend") {
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=$SONAR_TOKEN"
                                }
                            }
                        }
                        parallel sonarJobs
                    }
                }
            }
        }

        stage('Déploiement Kubernetes') {
            steps {
                sh '''
                    kubectl apply -f k8s/eureka/
                    kubectl apply -f k8s/api-gateway/
                    kubectl apply -f k8s/frontend/
                    kubectl apply -f k8s/answer-service/
                    # kubectl apply -f k8s/exam-service/
                    # kubectl apply -f k8s/course-service/
                    # kubectl apply -f k8s/user-service/

                    kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml
                    kubectl apply -f k8s/answer-service/mongo-answer-db-deployment.yaml
                    kubectl apply -f k8s/answer-service/mongo-answer-db-service.yaml
                    kubectl apply -f k8s/answer-service/mongo-answer-pv.yaml
                    kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=300s || true

                    kubectl apply -f k8s/zap/zap-automation-plan-config.yaml
                    export ZAP_JOB_NAME=owasp-zap-automation-${BUILD_NUMBER}
                    envsubst < k8s/zap/zap-automation-job.yaml | sed "s/owasp-zap-automation-job/${ZAP_JOB_NAME}/g" | kubectl apply -f -
                    kubectl wait --for=condition=complete job/${ZAP_JOB_NAME} --timeout=900s || true
                    POD=$(kubectl get pods --selector=job-name=${ZAP_JOB_NAME} -o jsonpath='{.items[0].metadata.name}')
                    kubectl cp $POD:/zap/wrk/zap_report.json ./zap_report.json || true
                    kubectl apply -f k8s/ingress.yaml
                '''
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
                    def jmeterJobs = [:]
                    jmeterJobs["frontend"] = {
                        sh "${JMETER_HOME}/bin/jmeter -n -t frontend.jmx -Jhost=${targetHost} -l frontend-results.jtl -e -o frontend-report"
                    }
                    jmeterJobs["exam"] = {
                        sh "${JMETER_HOME}/bin/jmeter -n -t exam.jmx -Jhost=${targetHost} -l exam-results.jtl -e -o exam-report"
                    }
                    parallel jmeterJobs

                    archiveArtifacts artifacts: 'frontend-report/**, frontend-results.jtl, exam-report/**, exam-results.jtl'
                }
            }
        }

        stage('Analyse ZAP') {
            steps {
                sh '''
                    if [ ! -f zap_report.json ]; then echo "Pas de rapport ZAP"; exit 0; fi
                    if jq '.site[].alerts[] | select(.riskcode == "3" or .riskcode == "4")' zap_report.json | grep -q .; then
                        echo "ERREUR: Vulnérabilités critiques ou élevées détectées par ZAP. Échec du pipeline."
                        exit 1
                    else
                        echo "Aucune vulnérabilité critique ou élevée détectée par ZAP."
                    fi
                '''
                archiveArtifacts artifacts: 'zap_report.json'
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
