FROM google/dart:stable
WORKDIR /app
COPY . /app
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server
EXPOSE 8080
CMD ["./bin/server"]
