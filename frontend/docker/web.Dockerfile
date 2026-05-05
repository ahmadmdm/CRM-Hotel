FROM ghcr.io/cirruslabs/flutter:3.41.3 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter config --enable-web && flutter pub get

COPY . .

ARG API_BASE_URL=http://127.0.0.1:8000/api/v1
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.29-alpine

COPY docker/nginx.default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html