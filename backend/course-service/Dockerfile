FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=course-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app.jar"]
