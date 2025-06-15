FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=user-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app.jar"]