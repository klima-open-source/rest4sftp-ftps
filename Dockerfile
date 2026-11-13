FROM eclipse-temurin:11-jdk AS builder
COPY . /appsrc
WORKDIR /appsrc
RUN ./gradlew --no-daemon clean installDist -x test

FROM eclipse-temurin:11-jre
EXPOSE 8080
COPY --from=builder /appsrc/build/install/rest4sftp /app/rest4sftp
WORKDIR /app
ENTRYPOINT ["/app/rest4sftp/bin/rest4sftp","--port","8080"]
CMD ["--sftp"]
