ifeq ($(shell command -v podman 2> /dev/null),)
	CMD=docker
else
	CMD=podman
endif

.PHONY: all
all:
	gleam build

.PHONY: test
test: build-test-suite
	gleam test

.PHONY: build-test-suite
build-test-suite: build-rust-test-suite build-wat2wasm-test-suite

.PHONY: build-rust-test-suite
build-rust-test-suite:
	$(CMD) run \
	--rm \
	--userns=keep-id \
	-v ./test_suite/rust:/usr/src/test_suite \
	-w /usr/src/test_suite \
	docker.io/library/rust:1.85.1-alpine3.20 \
	sh -c "rustup target add wasm32-unknown-unknown && cargo build --release"

.PHONY: build-wat2wasm-test-suite
build-wat2wasm-test-suite:
	$(CMD) run \
	--rm \
	--user root \
	-v ./test_suite/wat:/usr/src/test_suite \
	-w /usr/src/test_suite \
	docker.io/library/ubuntu:latest \
	sh -c "apt update && apt -y install wabt && find . -name '*.wat' -type f -exec echo {} \; -exec wat2wasm {} \;"