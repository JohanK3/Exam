# Dockerfile simplifié
FROM openjdk:11-jre-slim-buster

WORKDIR /app

COPY answer-service/target/*.jar app.jar

EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
