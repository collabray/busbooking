FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o auth-service main.go

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /app/auth-service /auth-service
USER nonroot:nonroot
EXPOSE 8080 9090
ENTRYPOINT ["/auth-service"]
