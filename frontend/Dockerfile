FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .

RUN go build -o frontend .

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/frontend .

COPY --from=builder /app/templates ./templates
COPY --from=builder /app/static ./static

EXPOSE 8080

CMD ["./frontend"]