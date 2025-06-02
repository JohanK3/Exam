pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'
        ZAP_REPORT_FILE = 'zap_report.html'
        DOCKER_BUILD_ID = "${env.BUILD_ID}"
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                git branch: 'sprint-2', credentialsId: 'github-credentials', url: 'https://github.com/JohanK3/Exam.git'
            }
        }

        stage('Téléchargement de wait-for-it.sh') {
            steps {
                sh '''
                    curl -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
                    chmod +x wait-for-it.sh
                '''
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
                        'backend/user-service/Dockerfile'
                    ]
                    for (dockerfile in dockerfiles) {
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || echo 'Problèmes détectés dans ${dockerfile}, vérifiez le rapport.'"
                    }
                }
            }
        }

        stage('Validation docker-compose') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} config --quiet || echo "Erreur dans la validation de ${DOCKER_COMPOSE_FILE}"'
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
                    for (module in modules) {
                        dir(module) {
                            sh 'mvn clean install -DskipTests'
                        }
                    }
                }
            }
        }

        stage('Analyse SonarQube') {
            steps {
                script {
                    withSonarQubeEnv(credentialsId: 'jenkins-token-sonar') {
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
                                sh "mvn sonar:sonar -Dsonar.projectKey=Exam-${module.replace('/', '-')}"
                            }
                        }
                    }
                }
            }
        }

        stage('Construction et démarrage Docker Compose') {
            steps {
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
                    ./wait-for-it.sh ${ZAP_TARGET_URL} --timeout=120 -- echo "Services prêts" || echo "Timeout: services non disponibles"
                '''
            }
        }

        stage('Tests d’intégration JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t Test\\ Integration.jmx -l integration_results.jtl -e -o jmeter-integration-report"
                archiveArtifacts artifacts: 'integration_results.jtl,jmeter-integration-report/**', allowEmptyArchive: true
            }
        }

        stage('Tests de charge JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l load_results.jtl -e -o jmeter-load-report"
                archiveArtifacts artifacts: 'load_results.jtl,jmeter-load-report/**', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                sh '''
                    chmod +x zap_scan.sh
                    ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE} || echo "Scan ZAP a échoué, vérifiez l'accessibilité de ${ZAP_TARGET_URL}"
                '''
                sh 'if [ -f ${ZAP_REPORT_FILE} ]; then echo "Rapport ZAP trouvé"; else echo "Aucun rapport ZAP généré"; fi'
                archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                sh '''
                    chmod +x scan_trivy.sh
                    ./scan_trivy.sh
                '''
                archiveArtifacts artifacts: 'trivy-*.txt', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            sh '''
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down
                docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
                docker image prune -f
                docker images | grep '^exam-' | awk '{print $1":"$2}' | xargs -I {} docker rmi {} || true
                docker-compose -f ${DOCKER_COMPOSE_FILE} images -q | sort -u | xargs -I {} docker rmi {}_${DOCKER_BUILD_ID} || true
            '''
            archiveArtifacts artifacts: 'docker-compose.log,**/target/*.jar', allowEmptyArchive: true
        }
        failure {
            echo 'Le pipeline a échoué. Vérifiez les logs et les rapports archivés.'
        }
    }
}