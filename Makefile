.PHONY: build run test dist

build:
	./scripts/bundle.sh

run: build
	open "build/Farol Voice.app"

test:
	swift test

# A signed, notarized DMG and zip. See RELEASING.md.
dist:
	./scripts/dist.sh
