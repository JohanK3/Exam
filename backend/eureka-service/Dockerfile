FROM openjdk:11-jre-slim-buster
VOLUME /tmp
ARG JAR_FILE=eureka-service/target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8761
# AJOUTÉ : Désactive l'auto-configuration des métriques système pour éviter la NullPointerException
ENV SPRING_AUTOCONFIGURE_EXCLUDE=org.springframework.boot.actuate.autoconfigure.metrics.SystemMetricsAutoConfiguration
ENTRYPOINT ["java","-jar","/app.jar"]
