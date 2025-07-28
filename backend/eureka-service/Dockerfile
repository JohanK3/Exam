FROM openjdk:11-jre-slim-buster

VOLUME /tmp
WORKDIR /app

COPY eureka-service/target/*.jar app.jar

EXPOSE 8761
ENTRYPOINT ["java", "-jar", "app.jar"]
