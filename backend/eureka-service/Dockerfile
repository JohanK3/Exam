FROM eclipse-temurin:11-jre-alpine

WORKDIR /app
COPY eureka-service/target/*.jar app.jar

EXPOSE 8761
ENTRYPOINT ["java", "-jar", "app.jar"]
