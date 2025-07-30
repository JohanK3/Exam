FROM eclipse-temurin:11.0.23_9-jre-focal

WORKDIR /app
COPY api-gateway-service/target/*.jar app.jar

EXPOSE 8090
ENTRYPOINT ["java","-jar","app.jar"]
