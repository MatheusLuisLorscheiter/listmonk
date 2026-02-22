FROM golang:1.24-alpine AS builder
RUN apk add --no-cache make nodejs npm yarn git
WORKDIR /app
COPY . .

RUN make build-dist

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata shadow su-exec
WORKDIR /listmonk

COPY --from=builder /app/listmonk .
COPY --from=builder /app/config.toml.sample config.toml
COPY --from=builder /app/static ./static
COPY --from=builder /app/i18n ./i18n
COPY --from=builder /app/docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["./listmonk"]
