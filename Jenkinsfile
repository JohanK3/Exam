pipeline {
    agent any // Le pipeline peut s'exécuter sur n'importe quel agent disponible

    environment {
        // Liste des Dockerfiles à linter
        DOCKERFILES_TO_LINT = [
            'backend/eureka-service/Dockerfile',
            'backend/api-gateway-service/Dockerfile',
            'backend/answer-service/Dockerfile',
            'backend/exam-service/Dockerfile',
            'backend/course-service/Dockerfile',
            'backend/user-service/Dockerfile',
            'frontend/Dockerfile'
        ]
    }

    stages {
        // --- Phase 1: Préparation et Récupération du Code ---
        stage('Nettoyage de l’espace de travail') {
            steps {
                echo "Nettoyage de l'espace de travail Jenkins..."
                cleanWs() // Nettoie le répertoire de travail du pipeline
            }
        }

        stage('Récupération du code source') {
            steps {
                echo "Récupération du code source depuis GitHub..."
                // Augmentation du timeout pour le clonage Git, car le dépôt est volumineux
                timeout(time: 300, unit: 'SECONDS') { // Définit un timeout de 5 minutes (300 secondes)
                    git branch: 'sprint-3', credentialsId: 'github', url: 'https://github.com/JohanK3/Exam.git'
                }
            }
        }

        // --- Phase 2: Analyse Statique et Compilation ---
        stage('Linting des Dockerfiles') {
            steps {
                script {
                    echo "Lancement du linting pour tous les Dockerfiles..."
                    for (dockerfile in DOCKERFILES_TO_LINT) {
                        echo "  -> Linting de ${dockerfile}"
                        sh "docker run --rm -i hadolint/hadolint < ${dockerfile} || true"
                    }
                }
            }
        }
    }

    // Le bloc post est conservé pour les messages de fin de pipeline
    post {
        always {
            echo "Pipeline terminé."
        }
        success {
            echo 'Pipeline réussi!'
        }
        failure {
            echo 'Pipeline échoué! Veuillez vérifier les logs pour les erreurs.'
        }
    }
}
