pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'Java17'
        // Assure-toi que 'SonarQubeScannerCLI' est le nom que tu as donné dans
        // Jenkins > Manage Jenkins > Global Tool Configuration > SonarQube Scanners
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        JMETER_HOME = '/opt/jmeter'
        ZAP_TARGET_URL = 'http://localhost:8090'   // URL de votre application à scanner (via l'hôte Docker)
        ZAP_REPORT_FILE = 'zap_report.json'        // Nom du rapport ZAP (maintenant JSON)

        // --- Variables d'environnement pour SonarQube ---
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Le nom configuré dans Jenkins Global Tool Configuration
        SONAR_HOST_URL = 'http://localhost:9000'   // L'URL de ton serveur SonarQube (qui tourne via Docker Compose sur l'hôte)
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // L'ID de tes identifiants Jenkins (Secret text)
    }

    stages {
        stage('Nettoyage de l’espace de travail') {
            steps {
                cleanWs()
            }
        }

        stage('Récupération du code source') {
            steps {
                // Modifié : Clonage de la branche 'sprint-3' avec les identifiants
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
                    for (module in modules) {
                        dir(module) {
                            echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${module}"
                            sh 'mvn clean install -DskipTests'
                        }
                    }
                }
            }
        }

        // Le stage 'Analyse de Code (SonarQube)' est commenté comme demandé
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
                    # Utiliser wait-for-it.sh ici si tu l'as téléchargé, sinon un simple sleep
                    # ./wait-for-it.sh api-gateway-service:8090 --timeout=120 -- echo "API Gateway est prête" || error "Timeout: API Gateway non disponible"
                '''
                // La commande 'sleep' est une étape Jenkins Pipeline et doit être en dehors du bloc 'sh'
                sleep(time: 90, unit: 'SECONDS') // Augmenté le délai pour plus de sûreté
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
                    echo "Lancement du scan ZAP sur ${ZAP_TARGET_URL}..."
                    sh '''
                        chmod +x zap_scan.sh
                        ./zap_scan.sh ${ZAP_TARGET_URL} ${ZAP_REPORT_FILE}
                    '''
                    archiveArtifacts artifacts: '${ZAP_REPORT_FILE}', allowEmptyArchive: true
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
                        // Ajout de --cache-dir pour forcer Trivy à utiliser un cache dans le workspace
                        sh "trivy image --severity HIGH,CRITICAL --format json --cache-dir .trivycache ${image}:latest > trivy-${image.replace('exam-', '')}.json || true"
                    }
                }
                archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            echo "Arrêt des services Docker Compose et nettoyage..."
            sh '''
                # Arrêter les services Docker Compose
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} down
                # Archiver les logs de Docker Compose pour le débogage
                COMPOSE_PROJECT_NAME=exam docker-compose -f ${DOCKER_COMPOSE_FILE} logs > docker-compose.log
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
