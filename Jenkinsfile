pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://192.168.110.147:8090'
        ZAP_REPORT_FILE = 'zap_report.html'
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
                        dir('backend/course-service') {
                            sh 'mvn sonar:sonar'
                        }
                    }
                }
            }
        }

        stage('Tests d’intégration JMeter') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} up -d'
                sleep(time: 30, unit: 'SECONDS')
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
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} up -d'
                sleep(time: 60, unit: 'SECONDS')
                sh '''
                    chmod +x zap_scan.sh
                    ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                '''
                archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: true
            }
        }

        stage('Construction et déploiement Docker Compose') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} down'
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} up -d'
            }
        }
    }

    post {
        always {
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log'
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
        }
        failure {
            echo 'Le pipeline a échoué. Vérifiez les logs et les rapports archivés.'
        }
    }
}
