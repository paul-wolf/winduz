.PHONY: build install uninstall dev

build:
	swift build -c release

install:
	bash scripts/install.sh

uninstall:
	bash scripts/uninstall.sh

# Run the debug build in the foreground (for development)
dev:
	swift run Winduz
