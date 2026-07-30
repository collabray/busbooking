FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o wallet-service main.go

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/wallet-service /wallet-service
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/wallet-service"]
