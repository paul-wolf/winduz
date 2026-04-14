.PHONY: build install uninstall restart dev

build:
	swift build -c release

install:
	bash scripts/install.sh

uninstall:
	bash scripts/uninstall.sh

# Kill and restart the installed binary without rebuilding (fast dev cycle)
restart:
	pkill -f "$(HOME)/.local/bin/Winduz" 2>/dev/null || true
	sleep 0.5
	nohup "$(HOME)/.local/bin/Winduz" > /dev/null 2>&1 & disown

# Run the debug build in the foreground (for development)
dev:
	swift run Winduz
