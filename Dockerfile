# ETAPA 1: Builder (Usando Debian para evitar erros de ferramentas como grep/make)
FROM golang:1.24 AS builder

# Instalar Node.js e Yarn (necessários para o frontend do listmonk)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

WORKDIR /app
COPY . .

# Build the project and embed all static assets (frontend, sql, etc.)
# `make dist` runs the frontend build and packages everything into a single binary.
RUN make dist

# ETAPA 2: Imagem Final (Leve, baseada em Alpine)
FROM alpine:latest

# Instalar apenas dependências de runtime
RUN apk --no-cache add ca-certificates tzdata shadow su-exec

WORKDIR /listmonk

# Copy the self-contained binary from builder and sample config
COPY --from=builder /app/listmonk .
COPY --from=builder /app/config.toml.sample config.toml

# optional: copy entrypoint script
COPY --from=builder /app/docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["./listmonk"]