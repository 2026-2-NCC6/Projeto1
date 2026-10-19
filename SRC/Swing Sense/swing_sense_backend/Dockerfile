# ---- build: compila para binario nativo (AOT) ------------------------------
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# ---- runtime: imagem minima, sem shell, sem root (R-10) ---------------------
# /runtime traz apenas as bibliotecas e certificados CA necessarios ao binario.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Usuario nao privilegiado (UID numerico, pois a imagem nao tem /etc/passwd).
USER 10001:10001

EXPOSE 8080

# A imagem nao tem curl: o proprio binario faz o GET /health.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/app/bin/server", "--healthcheck"]

ENTRYPOINT ["/app/bin/server"]
