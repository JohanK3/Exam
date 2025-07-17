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
        
        // Nouvelles variables d'optimisation
        MAVEN_OPTS = '-T 1C -Dmaven.build.cache.enabled=true'
        TRIVY_ARGS = '--security-checks vuln --severity CRITICAL --exit-code 0 --timeout 5m'
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
                    // Parallélisation du linting
                    def lintJobs = [:]
                    def dockerfiles = [
                        'backend/eureka-service/Dockerfile',
                        'backend/api-gateway-service/Dockerfile',
                        'backend/answer-service/Dockerfile',
                        'backend/exam-service/Dockerfile',
                        'backend/course-service/Dockerfile',
                        'backend/user-service/Dockerfile',
                        'frontend/Dockerfile'
                    ]
                    
                    dockerfiles.each { df ->
                        lintJobs[df] = {
                            echo "Linting ${df}"
                            sh "docker run --rm -i hadolint/hadolint < ${df} || true"
                        }
                    }
                    parallel lintJobs
                }
            }
        }

        stage('Build Maven') {
            steps {
                script {
                    // Build séquentiel des commons
                    dir('backend/common-exam') { sh "mvn clean install $MAVEN_OPTS -DskipTests" }
                    dir('backend/common-service') { sh "mvn clean install $MAVEN_OPTS -DskipTests" }
                    dir('backend/common-student') { sh "mvn clean install $MAVEN_OPTS -DskipTests" }

                    // Build parallèle des services
                    def services = [
                        'eureka-service',
                        'api-gateway-service',
                        'answer-service',
                        'exam-service',
                        'course-service',
                        'user-service'
                    ]
                    def buildJobs = [:]
                    services.each { svc ->
                        buildJobs[svc] = {
                            dir("backend/$svc") {
                                sh "mvn clean package $MAVEN_OPTS -DskipTests"  // package > install pour les services
                            }
                        }
                    }
                    parallel buildJobs
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh """
                    docker-compose -f $DOCKER_COMPOSE_FILE build \
                    --parallel \
                    --memory 2GB
                """
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
                    
                    // Scan parallèle optimisé
                    def scanJobs = [:]
                    images.each { img ->
                        scanJobs[img] = {
                            sh """
                                trivy image $TRIVY_ARGS \
                                --format json \
                                --output trivy-$img.json \
                                $img
                            """
                        }
                    }
                    parallel scanJobs
                    
                    // Analyse rapide des résultats
                    sh '''
                        grep -rl '"Severity": "CRITICAL"' trivy-*.json || echo "Aucune vulnérabilité critique"
                    '''
                    archiveArtifacts artifacts: 'trivy-*.json'
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    def services = ['eureka-service', 'api-gateway-service', 'answer-service', 'exam-service', 'course-service', 'user-service', 'frontend']
                    
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_HUB_CRED_ID, usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh """
                            echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                            docker system prune -f
                        """
                        
                        // Push en parallèle avec xargs
                        sh """
                            printf '%s\\n' ${services.join(' ')} | xargs -P 4 -I {} sh -c '
                                docker tag exam-{} ${DOCKER_HUB_USERNAME}/exam-{}:latest && 
                                docker push ${DOCKER_HUB_USERNAME}/exam-{}:latest
                            '
                        """
                        sh "docker logout"
                    }
                }
            }
        }

        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(env.SONAR_SCANNER_NAME) {
                        // Backend en parallèle
                        def backendServices = ['api-gateway-service', 'answer-service', 'course-service', 'eureka-service', 'exam-service', 'user-service']
                        def sonarJobs = [:]
                        
                        backendServices.each { svc ->
                            sonarJobs[svc] = {
                                dir("backend/$svc") {
                                    withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                        sh "mvn sonar:sonar $MAVEN_OPTS -Dsonar.projectKey=exam-$svc -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN"
                                    }
                                }
                            }
                        }
                        
                        // Frontend séparé
                        sonarJobs['frontend'] = {
                            dir("frontend") {
                                withCredentials([string(credentialsId: env.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                                    sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner -Dsonar.projectKey=exam-frontend -Dsonar.sources=. -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN"
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
                script {
                    // Déploiement en parallèle
                    parallel(
                        'Services Principaux': {
                            sh '''
                                kubectl apply -f k8s/eureka/ &
                                kubectl apply -f k8s/api-gateway/ &
                                kubectl apply -f k8s/frontend/ &
                                kubectl apply -f k8s/answer-service/ &
                                wait
                            '''
                        },
                        'MongoDB': {
                            sh '''
                                kubectl apply -f k8s/answer-service/mongo-answer-db-pvc.yaml
                                kubectl apply -f k8s/answer-service/mongo-answer-db-deployment.yaml
                                kubectl apply -f k8s/answer-service/mongo-answer-db-service.yaml
                                kubectl apply -f k8s/answer-service/mongo-answer-pv.yaml
                                kubectl wait --for=condition=Available deployment/mongo-answer-db --timeout=120s
                            '''
                        }
                    )
                    
                    // ZAP en arrière-plan
                    sh '''
                        kubectl apply -f k8s/zap/zap-automation-plan-config.yaml
                        export ZAP_JOB_NAME=owasp-zap-automation-${BUILD_NUMBER}
                        envsubst < k8s/zap/zap-automation-job.yaml | kubectl apply -f -
                    '''
                }
            }
        }

        stage('Déploiement Monitoring') {
            steps {
                sh '''
                    helm repo add $HELM_REPO_NAME $HELM_REPO_URL --force-update
                    helm upgrade --install $PROMETHEUS_RELEASE_NAME $HELM_REPO_NAME/$PROMETHEUS_CHART_NAME \
                    --namespace $MONITORING_NAMESPACE \
                    --create-namespace \
                    --wait \
                    --timeout 3m
                '''
            }
        }

        stage('Tests Finaux') {
            parallel {
                stage('Tests JMeter') {
                    steps {
                        sh """
                            $JMETER_HOME/bin/jmeter -n -t frontend.jmx -Jhost=exam.local -l frontend-results.jtl -e -o frontend-report &
                            $JMETER_HOME/bin/jmeter -n -t exam.jmx -Jhost=exam.local -l exam-results.jtl -e -o exam-report &
                            wait
                        """
                        archiveArtifacts artifacts: '*-results.jtl, *-report/**'
                    }
                }
                
                stage('Vérification ZAP') {
                    steps {
                        sh '''
                            kubectl wait --for=condition=complete job/owasp-zap-automation-${BUILD_NUMBER} --timeout=300s || true
                            POD=$(kubectl get pods -l job-name=owasp-zap-automation-${BUILD_NUMBER} -o jsonpath='{.items[0].metadata.name}')
                            kubectl cp $POD:/zap/wrk/zap_report.json ./zap_report.json || echo "Aucun rapport ZAP"
                            
                            if [ -f zap_report.json ]; then
                                if jq -e '.site[].alerts[] | select(.riskcode == "3" or .riskcode == "4")' zap_report.json; then
                                    echo "Vulnérabilités critiques détectées" && exit 1
                                fi
                            fi
                        '''
                        archiveArtifacts artifacts: 'zap_report.json'
                    }
                }
            }
        }
    }

    post {
        always {
            sh '''
                kubectl get all -A --no-headers | grep -v "kube-system" || true
                docker system prune -f
            '''
        }
    }
}
