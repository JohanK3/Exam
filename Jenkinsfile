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
        ZAP_TARGET_URL = 'http://localhost:8090' // URL de votre application à scanner
        ZAP_REPORT_FILE = 'zap_report.html'     // Nom du rapport ZAP

        // --- Nouvelles variables d'environnement pour SonarQube ---
        SONAR_SCANNER_NAME = 'SonarQubeScannerCLI' // Le nom configuré dans Jenkins Global Tool Configuration
        SONAR_HOST_URL = 'http://localhost:9000'   // L'URL de ton serveur SonarQube
        SONAR_TOKEN_CRED_ID = 'sonar-token-for-jenkins' // L'ID de tes identifiants Jenkins (Secret text)
        // --- Fin des variables SonarQube ---
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
                            echo "Exécution de 'mvn clean install -DskipTests' pour le module : ${module}"
                            sh 'mvn clean install -DskipTests' // Garde -DskipTests comme demandé par ton encadrant
                        }
                    }
                }
            }
        }

        stage('Analyse de Code (SonarQube)') {
            steps {
                script {
                    // Liste de tous les modules backend à scanner
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

                    // Itérer sur chaque module et lancer l'analyse SonarQube
                    for (modulePath in modulesToScan) {
                        dir(modulePath) { // Se positionner dans le répertoire du module
                            echo "Lancement de l'analyse SonarQube pour le module : ${modulePath}"
                            // Utilisation de withSonarQubeEnv pour injecter l'URL et le token
                            withSonarQubeEnv(credentialsId: env.SONAR_TOKEN_CRED_ID) {
                                // Exécution du SonarScanner CLI.
                                // -Dsonar.projectKey: Identifiant unique du projet dans SonarQube.
                                //                   Utilise le chemin du module pour le rendre unique (ex: backend-course-service)
                                // -Dsonar.sources: Chemin vers le code source à analyser (par défaut le répertoire courant '.')
                                // -Dsonar.java.binaries: Chemin vers les fichiers .class compilés par Maven
                                // -Dsonar.host.url: L'URL de ton serveur SonarQube
                                // -Dsonar.login: Le token d'authentification (injecté par withSonarQubeEnv)
                                sh "${tool env.SONAR_SCANNER_NAME}/bin/sonar-scanner " +
                                    "-Dsonar.projectKey=${modulePath.replace('/', '-')}" + // Ex: 'backend-course-service'
                                    "-Dsonar.sources=src/main/java" +
                                    "-Dsonar.java.binaries=target/classes" + // Important pour l'analyse Java
                                    "-Dsonar.host.url=${env.SONAR_HOST_URL}" +
                                    "-Dsonar.login=${env.SONAR_AUTH_TOKEN}" // Variable auto-injectée par withSonarQubeEnv
                            }
                        }
                    }
                }
            }
            post {
                always {
                    echo "Vérification du Quality Gate SonarQube..."
                    // Attendre la fin de l'analyse et vérifier le Quality Gate
                    // Si le Quality Gate échoue, le pipeline sera marqué en FAILURE
                    timeout(time: 3, unit: 'MINUTES') { // Donne suffisamment de temps pour que l'analyse se termine sur SonarQube
                        waitForQualityGate abortPipeline: true
                    }
                }
                failure {
                    echo "Le Quality Gate SonarQube a échoué. Vérifiez les rapports sur SonarQube."
                    currentBuild.result = 'FAILURE' // Force le statut du build à FAILURE si le Quality Gate échoue
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
                    // Note: Le `docker-compose up -d` est dans l'étape suivante.
                    // Si ZAP a besoin de l'appli avant le build/deploy Docker,
                    // cette étape de démarrage Docker Compose devrait être déplacée AVANT ZAP.
                    // Pour le moment, je maintiens la structure mais c'est un point à valider.
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
            // Ajoutez un nettoyage des conteneurs/images si nécessaire après le pipeline
            // sh 'docker-compose -f ${DOCKER_COMPOSE_FILE} down --rmi all'
            echo "Nettoyage du workspace en cours."
        }
        success {
            echo "Pipeline terminé avec SUCCÈS !"
        }
        failure {
            echo "Pipeline a échoué. Vérifiez les logs des étapes concernées."
        }
    }
}
