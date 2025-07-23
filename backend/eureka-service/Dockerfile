FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=eureka-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8761
ENTRYPOINT ["java","-jar","/app.jar"]
