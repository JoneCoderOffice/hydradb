# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy the go.mod first, then copy the rest of the application files
COPY go.mod ./
COPY . .

# Run go mod tidy to generate the go.sum file and fetch dependencies
RUN go mod tidy

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Production stage
FROM alpine:3.19

WORKDIR /app

# Install certificates for secure connections if needed
RUN apk --no-cache add ca-certificates

# Copy compiled binary and static assets
COPY --from=builder /app/main .
COPY --from=builder /app/views ./views
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/docs ./docs

EXPOSE 8080

CMD ["./main"]
