# Builds the Spring Boot backend into a container image.
# On Render: Root Directory = backend, Runtime = Docker.

# Stage 1: compile and package the jar. Needs internet access to Maven Central during the build.
FROM eclipse-temurin:25-jdk AS build
WORKDIR /build
COPY . .
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw && ./mvnw -B -DskipTests package

# Stage 2: a small runtime image that only holds the jar and the config template.
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /build/target/*.jar /app/app.jar
# Spring Boot reads ./config/application.properties. Its ${...} values come from environment variables.
COPY --from=build /build/src/main/resources/application.properties.example /app/config/application.properties
ENV JAVA_OPTS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC"
# Render sets PORT itself. Locally the app uses 8080.
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -Dserver.port=$PORT -jar /app/app.jar"]
