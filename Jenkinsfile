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
        // Ajout d'un identifiant unique pour les builds Docker
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
                        // Scan de tous les modules au lieu d'un seul
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

        stage('Construction Docker Compose') {
            steps {
                // Build forcé avec cache et tag explicite
                sh '''
                    docker-compose -f ${DOCKER_COMPOSE_FILE} build --no-cache
                    docker-compose -f ${DOCKER_COMPOSE_FILE} images -q | xargs -I {} docker tag {} {}_${DOCKER_BUILD_ID}
                '''
            }
        }

        stage('Déploiement Docker Compose') {
            steps {
                sh '''
                    docker-compose -f ${DOCKER_COMPOSE_FILE} down
                    docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
                '''
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    // Liste des services à scanner (sans les bases de données externes)
                    def services = [
                        'eureka-service',
                        'api-gateway-service',
                        'answer-service',
                        'exam-service',
                        'course-service',
                        'user-service',
                        'frontend'
                    ]

                    // Scan avec vérification de l'existence des images
                    for (service in services) {
                        sh """
                            if docker image inspect ${service}:latest >/dev/null 2>&1; then
                                trivy image --scanners vuln --exit-code 0 ${service}:latest > trivy-${service}.txt
                            else
                                echo "[WARNING] Image ${service}:latest non trouvée - scan ignoré" > trivy-${service}.txt
                            fi
                        """
                    }
                    archiveArtifacts artifacts: 'trivy-*.txt', allowEmptyArchive: true
                }
            }
        }
    }

    post {
        always {
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log'
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true

            // Nettoyage des images tagguées temporaires
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} images -q | xargs -I {} docker rmi {}_${DOCKER_BUILD_ID} || true'
        }
        failure {
            echo 'Le pipeline a échoué. Vérifiez les logs et les rapports archivés.'
        }
    }
}