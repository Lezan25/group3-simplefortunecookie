FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o frontend .

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/frontend .

COPY templates ./templates
COPY static ./static

EXPOSE 8080

CMD ["./frontend"]