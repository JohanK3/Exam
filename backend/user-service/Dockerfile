FROM eclipse-temurin:11.0.23_9-jre-focal

VOLUME /tmp
WORKDIR /app
COPY user-service/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
