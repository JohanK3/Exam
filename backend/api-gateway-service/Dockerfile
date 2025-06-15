FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=api-gateway-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8090
ENTRYPOINT ["java","-jar","/app.jar"]