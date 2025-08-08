FROM eclipse-temurin:11.0.23_9-jre-focal
VOLUME /tmp
ARG JAR_FILE=exam-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app.jar"]
