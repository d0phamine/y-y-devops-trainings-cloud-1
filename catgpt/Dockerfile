FROM golang:1.21 as build
WORKDIR /go/bin
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build


FROM scratch
COPY --from=build /go/bin/catgpt-1.0 /go/bin/catgpt-1.0
ENTRYPOINT ["/go/bin/catgpt-1.0"]
EXPOSE 8080