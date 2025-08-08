FROM eclipse-temurin:11.0.23_9-jre-focal

WORKDIR /app

COPY answer-service/target/*.jar app.jar

EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
