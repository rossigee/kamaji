# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /workspace

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X github.com/clastix/kamaji/internal.GitCommit=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown') \
    -X github.com/clastix/kamaji/internal.GitTag=pregenerated-certs-v1 \
    -X github.com/clastix/kamaji/internal.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%S)" \
    -a -installsuffix cgo -o kamaji main.go

# Final stage
FROM cgr.dev/chainguard/static:latest

WORKDIR /

# Copy the binary from builder stage
COPY --from=builder /workspace/kamaji .

USER 65532:65532

ENTRYPOINT ["/kamaji"]