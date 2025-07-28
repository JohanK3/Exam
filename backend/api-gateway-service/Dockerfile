FROM openjdk:11-jre-slim-buster

WORKDIR /app
COPY api-gateway-service/target/*.jar app.jar

EXPOSE 8090
ENTRYPOINT ["java","-jar","app.jar"]
