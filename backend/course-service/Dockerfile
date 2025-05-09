# ----------- STAGE 1: Build ------------
    FROM maven:3.8.8-eclipse-temurin-11 AS build

    WORKDIR /build
    
    # Copier les projets
    COPY common-exam/ ./common-exam/
    COPY common-service/ ./common-service
    COPY common-student/ ./common-student

    COPY course-service/ ./course-service/
    
    # Installer le module partagé
    RUN mvn -f common-exam/pom.xml clean install
    RUN mvn -f common-service/pom.xml clean install
    RUN mvn -f common-student/pom.xml clean install
    
    # Compiler le microservice
    RUN mvn -f course-service/pom.xml clean package -DskipTests
    
    # ----------- STAGE 2: Run --------------
    FROM eclipse-temurin:11-jre
    
    WORKDIR /app
    
    # Copier le JAR du service compilé
    COPY --from=build /build/course-service/target/*.jar app.jar
    
    EXPOSE 8080
    ENTRYPOINT ["java", "-jar", "/app/app.jar"]
    