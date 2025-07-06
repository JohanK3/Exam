pipeline {
    agent any // Le pipeline peut s'exécuter sur n'importe quel agent disponible

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
