pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'  // URL de votre application à scanner
        ZAP_REPORT_FILE = 'zap_report.html'       // Nom du rapport ZAP
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                git branch: 'sprint-1', url: 'https://github.com/JohanK3/Exam.git'
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

        stage('Tests de charge JMeter') {
            steps {
                sh "${JMETER_HOME}/bin/jmeter -n -t test.jmx -l results.jtl -e -o report"
                archiveArtifacts artifacts: 'report/**,results.jtl', allowEmptyArchive: true
            }
        }

        stage('Scan de sécurité OWASP ZAP') {
            steps {
                script {
                    // Assurez-vous que l'application est démarrée avant le scan
                    sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} up -d'
                    sleep(time: 60, unit: 'SECONDS')  // Attendre que l'application soit disponible

                    // Exécution du scan ZAP
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                    '''
                    archiveArtifacts artifacts: '${ZAP_REPORT_FILE}', allowEmptyArchive: true
                }
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
    }
}