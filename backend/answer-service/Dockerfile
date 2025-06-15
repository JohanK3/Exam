FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=answer-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8083
ENTRYPOINT ["java","-jar","/app.jar"]