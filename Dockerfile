# ESTÁGIO 1: Build do Frontend (Interface)
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY frontend/package.json frontend/yarn.lock ./frontend/
RUN cd frontend && yarn install
COPY frontend/ ./frontend/
RUN cd frontend && yarn build

# ESTÁGIO 2: Build do Backend (Go)
FROM golang:1.24-alpine AS builder
RUN apk add --no-cache make git
WORKDIR /app
COPY . .
# Copia os arquivos gerados no Estágio 1 para a pasta static antes de compilar o Go
COPY --from=frontend-builder /app/static ./static
# Compila o binário embutindo os arquivos da pasta static e i18n
RUN go build -o listmonk main.go

# ESTÁGIO 3: Imagem Final
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata shadow su-exec
WORKDIR /listmonk

# Copia apenas o necessário do builder
COPY --from=builder /app/listmonk .
COPY --from=builder /app/config.toml.sample .
COPY --from=builder /app/i18n ./i18n
COPY --from=builder /app/static ./static
COPY --from=builder /app/docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["./listmonk"]
