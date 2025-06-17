pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://api-gateway-service:8090' // Utilise le nom du service Docker
        ZAP_REPORT_FILE = 'zap_report.json'
        // Variables pour SonarQube (commentées mais conservées)
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins'
        // Variable pour DeepSource (commentée mais prête)
        // DEEPSOURCE_TOKEN_CRED_ID = 'deepsource-token'
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
                    def parallelJobs = [:]
                    for (module in modules) {
                        def moduleName = module
                        parallelJobs[moduleName] = {
                            dir(moduleName) {
                                echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${moduleName}"
                                sh 'mvn clean install -DskipTests'
                            }
                        }
                    }
                    parallel parallelJobs
                }
            }
        }

        // Stage DeepSource (commenté, prêt à être décommenté plus tard)
        /*
        stage('Analyse de code (DeepSource)') {
            steps {
                withCredentials([string(credentialsId: env.DEEPSOURCE_TOKEN_CRED_ID, variable: 'DEEPSOURCE_TOKEN')]) {
                    sh '''
                        deepsource report --analyzer java --analyzer javascript \\
                        --commit-hash ${GIT_COMMIT} \\
                        --token ${DEEPSOURCE_TOKEN}
                    '''
                }
            }
        }
        */

        // Stage SonarQube (déjà commenté, conservé tel quel)
        /*
        stage('Analyse de Code (SonarQube)') {
            steps {
                script {
                    def modulesToScan = [
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
                    for (modulePath in modulesToScan) {
                        dir(modulePath) {
                            echo "Lancement de l'analyse SonarQube pour le module : ${modulePath}"
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=${modulePath.replace('/', '-')}" +
                                    "-Dsonar.sources=src/main/java" +
                                    "-Dsonar.java.binaries=target/classes" +
                                    "-Dsonar.host.url=${env.SONAR_HOST_URL}" +
                                    "-Dsonar.login=${env.SONAR_AUTH_TOKEN}"
                            }
                        }
                    }
                }
            }
            post {
                always {
                    echo "Vérification du Quality Gate SonarQube..."
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Vérifiez les rapports sur SonarQube."
                }
            }
        }
        */

        stage('Construction des Images Docker') {
            steps {
                sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} build'
                echo "Images Docker de l'application construites."
            }
        }

        stage('Démarrage des Services Applicatifs Docker Compose') {
            steps {
                sh '''
                    echo "Démarrage des services applicatifs via Docker Compose..."
                    COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

                    echo "Attente de la disponibilité de l'API Gateway (${ZAP_TARGET_URL})..."
                    for i in {1..12}; do
                        if curl --output /dev/null --silent --head --fail ${ZAP_TARGET_URL}/actuator/health; then
                            echo "API Gateway est prête."
                            break
                        fi
                        echo "En attente de ${ZAP_TARGET_URL}..."
                        sleep 10
                    done
                    if [ $i -eq 12 ]; then
                        echo "Erreur : Timeout, API Gateway non disponible."
                        exit 1
                    fi
                '''
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
                    echo "Lancement du scan ZAP sur ${env.ZAP_TARGET_URL}..."
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                        if jq '.alerts[] | select(.risk == "High" or .risk == "Critical")' "${ZAP_REPORT_FILE}" | grep -q .; then
                            echo "Erreur : Vulnérabilités critiques détectées dans ${ZAP_REPORT_FILE}"
                            exit 1
                        fi
                    '''
                    archiveArtifacts artifacts: "${ZAP_REPORT_FILE}", allowEmptyArchive: false
                }
            }
        }

        stage('Scan de sécurité Trivy') {
            steps {
                script {
                    def dockerImages = [
                        'exam-eureka-service',
                        'exam-api-gateway-service',
                        'exam-answer-service',
                        'exam-exam-service',
                        'exam-course-service',
                        'exam-user-service',
                        'exam-frontend'
                    ]
                    for (image in dockerImages) {
                        echo "Lancement du scan Trivy pour l'image : ${image}:latest"
                        sh "trivy image --severity HIGH,CRITICAL --format json --cache-dir .trivycache ${image}:latest > trivy-${image.replace('exam-', '')}.json"
                    }
                    sh '''
                        for report in trivy-*.json; do
                            if jq '.Results[] | select(.Vulnerabilities != null) | .Vulnerabilities[] | select(.Severity == "CRITICAL")' "$report" | grep -q .; then
                                echo "Erreur : Vulnérabilités critiques détectées dans $report"
                                exit 1
                            fi
                        done
                    '''
                    archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: false
                }
            }
        }
    }

    post {
        always {
            echo "Arrêt des services Docker Compose et nettoyage..."
            sh '''
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down --rmi local
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
                rm -rf .trivycache
            '''
            archiveArtifacts artifacts: 'docker-compose.log', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
            echo "Nettoyage du workspace en cours."
        }
        success {
            echo "Pipeline terminé avec SUCCÈS !"
        }
        failure {
            echo "Pipeline a échoué. Vérifiez les logs des étapes concernées et les rapports archivés."
        }
        aborted {
            echo "Pipeline a été annulé."
        }
    }
}
