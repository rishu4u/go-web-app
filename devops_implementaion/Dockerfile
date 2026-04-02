# ============================================================
# Dockerfile — go-web-app (my DevOps implementation)
# Multi-stage build: Build with golang:1.22, run with distroless
# ============================================================

# ---- Stage 1: Build ----------------------------------------
FROM golang:1.22 AS builder

WORKDIR /app

# Download dependencies first (cached layer)
COPY go.mod ./
RUN go mod download

# Copy source & build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# ---- Stage 2: Run (distroless = minimal attack surface) -----
FROM gcr.io/distroless/base

WORKDIR /

# Copy only what the app needs
COPY --from=builder /app/main   .
COPY --from=builder /app/static ./static

EXPOSE 8080

CMD ["./main"]
