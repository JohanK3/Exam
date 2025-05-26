# ----------- STAGE 1: Run --------------
FROM eclipse-temurin:11-jre

WORKDIR /app

# Copier le JAR généré par Jenkins
COPY backend/user-service/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]