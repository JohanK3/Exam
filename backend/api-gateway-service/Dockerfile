# ----------- STAGE 1: Build ------------
    FROM maven:3.8.8-eclipse-temurin-11 AS build

    WORKDIR /build
    


    COPY api-gateway-service/ ./api-gateway-service/
    

    
    # Compiler le microservice
    RUN mvn -f api-gateway-service/pom.xml clean package -DskipTests
    
    # ----------- STAGE 2: Run --------------
    FROM eclipse-temurin:11-jre
    
    WORKDIR /app
    
    # Copier le JAR du service compilé
    COPY --from=build /build/api-gateway-service/target/*.jar app.jar
    
    EXPOSE 8080
    ENTRYPOINT ["java", "-jar", "/app/app.jar"]
    