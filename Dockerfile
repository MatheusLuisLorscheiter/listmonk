# ETAPA 1: Builder (Usando Debian para evitar erros de ferramentas como grep/make)
FROM golang:1.24 AS builder

# Instalar Node.js e Yarn (necessários para o frontend do listmonk)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

WORKDIR /app
COPY . .

# Rodar o build (compila o frontend e o binário Go)
# O listmonk usa 'make build' para gerar o executável com assets embutidos
RUN make build

# ETAPA 2: Imagem Final (Leve, baseada em Alpine)
FROM alpine:latest

# Instalar apenas dependências de runtime
RUN apk --no-cache add ca-certificates tzdata shadow su-exec

WORKDIR /listmonk

# Copiar os arquivos gerados na etapa anterior
COPY --from=builder /app/listmonk .
COPY --from=builder /app/config.toml.sample config.toml
COPY --from=builder /app/static ./static
COPY --from=builder /app/i18n ./i18n
COPY --from=builder /app/queries ./queries
COPY --from=builder /app/schema.sql ./schema.sql
COPY --from=builder /app/permissions.json ./permissions.json

# include the compiled frontend assets (used by initFS/frontendDir)
COPY --from=builder /app/frontend/dist ./frontend/dist

COPY --from=builder /app/docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["./listmonk"]