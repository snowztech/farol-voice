.PHONY: build run test

build:
	./scripts/bundle.sh

run: build
	open "build/Farol Voice.app"

test:
	swift test
