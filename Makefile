BINARY_NAME=app

# CGO_ENABLED=0 to match CI. With cgo on, the binary links against glibc and
# dies on alpine ("not found" on exec, because musl != glibc) - so a locally
# built image would fail in a way CI never reproduces.
build:
	CGO_ENABLED=0 go build -o bin/$(BINARY_NAME) .

run: build
	./bin/$(BINARY_NAME)

test:
	go test -race ./...

clean:
	rm -f bin/$(BINARY_NAME)

docker-build: build
	docker build -t $(BINARY_NAME) .

.PHONY: build run test clean docker-build
