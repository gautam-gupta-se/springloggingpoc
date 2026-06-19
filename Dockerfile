FROM eclipse-temurin:21-jre-alpine
# Explicitly grab the bootable jar, avoiding the -plain.jar file completely
COPY build/libs/*-SNAPSHOT.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]