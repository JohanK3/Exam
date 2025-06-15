# Stage d'exécution : ne contient que le JRE nécessaire pour exécuter l'application
# Utilise une image JRE plus légère pour l'exécution (pas besoin du JDK pour la runtime).
# C'est cette image 'openjdk:11-jre-slim-buster' qui est recommandée pour l'optimisation.
FROM openjdk:11-jre-slim-buster

# Définit un volume pour l'application. Utile pour la persistance des données et le débogage si nécessaire.
VOLUME /tmp

# Copie le JAR compilé de l'application depuis le système de fichiers hôte (où Jenkins a compilé).
# Le 'context: ./backend' dans docker-compose.yml fait que le dossier 'backend' est la racine pour COPY.
# Donc, pour 'course-service', le JAR sera dans 'course-service/target/*.jar' par rapport au contexte Docker.
ARG JAR_FILE=course-service/target/*.jar
COPY ${JAR_FILE} app.jar

# Expose le port interne sur lequel l'application s'exécute.
EXPOSE 8081
# Le port correct pour le service Course

# Définit la commande de démarrage de l'application Spring Boot.
ENTRYPOINT ["java","-jar","/app.jar"]
