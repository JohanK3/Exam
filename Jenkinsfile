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
                sleep(time: 120, unit: 'SECONDS')
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
                // Attendre que l'API Gateway soit prêt (augmenté à 90 secondes)
                sleep(time: 120, unit: 'SECONDS')
                sh '''
                    chmod +x zap_scan.sh
                    ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE} || echo "Scan ZAP a échoué, vérifiez l'accessibilité de ${ZAP_TARGET_URL}"
                '''
                // Vérifier si le rapport est généré avant archivage
                sh 'if [ -f ${ZAP_REPORT_FILE} ]; then echo "Rapport ZAP trouvé"; else echo "Aucun rapport ZAP généré"; fi'
                archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: true
            }
        }

        stage('Nettoyage des anciennes images') {
            steps {
                sh '''
                    # Supprimer les images avec le préfixe exam- pour éviter les conflits
                    docker images | grep '^exam-' | awk '{print $1":"$2}' | xargs -I {} docker rmi {} || true
                '''
            }
        }

        stage('Construction Docker Compose') {
            steps {
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build --no-cache
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} images -q | sort -u | xargs -I {} sh -c 'docker tag {} {}_${DOCKER_BUILD_ID} || true'
                '''
            }
        }

        stage('Déploiement Docker Compose') {
            steps {
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
                    docker image prune -f
                '''
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                sh '''
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} build || true
                    chmod +x scan_trivy.sh
                    ./scan_trivy.sh
                '''
                archiveArtifacts artifacts: 'trivy-*.txt', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log'
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true

            // Nettoyage des images taggées temporaires
            sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} images -q | sort -u | xargs -I {} docker rmi {}_${DOCKER_BUILD_ID} || true'
        }
        failure {
            echo 'Le pipeline a échoué. Vérifiez les logs et les rapports archivés.'
        }
    }
}
