FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=exam-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app.jar"]
