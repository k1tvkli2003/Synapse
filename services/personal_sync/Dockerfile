FROM golang:1.26.5-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags='-s -w' -o /out/synapse-personal-sync ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/synapse-personal-sync /synapse-personal-sync
USER nonroot:nonroot
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/synapse-personal-sync"]
