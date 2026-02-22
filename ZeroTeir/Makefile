.PHONY: build clean run bundle install help

APP_NAME = ZeroTeir
BUNDLE_NAME = $(APP_NAME).app
BUILD_DIR = .build/release
BUNDLE_DIR = $(BUNDLE_NAME)/Contents

help:
	@echo "ZeroTeir Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build    - Build the executable"
	@echo "  make bundle   - Create macOS app bundle"
	@echo "  make run      - Build and run the app"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make install  - Install WireGuard tools (requires Homebrew)"
	@echo "  make help     - Show this help message"

build:
	@echo "Building $(APP_NAME)..."
	swift build -c release

run: build
	@echo "Running $(APP_NAME)..."
	$(BUILD_DIR)/$(APP_NAME)

bundle: build
	@echo "Creating app bundle..."
	@mkdir -p $(BUNDLE_DIR)/MacOS
	@mkdir -p $(BUNDLE_DIR)/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE_DIR)/MacOS/
	@cp Resources/Info.plist $(BUNDLE_DIR)/
	@cp Resources/ZeroTeir.entitlements $(BUNDLE_DIR)/
	@chmod +x $(BUNDLE_DIR)/MacOS/$(APP_NAME)
	@echo "App bundle created at $(BUNDLE_NAME)"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf .build
	@rm -rf $(BUNDLE_NAME)
	@rm -rf *.xcodeproj
	@echo "Clean complete"

install:
	@echo "Installing WireGuard tools..."
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Install from https://brew.sh"; exit 1; }
	brew install wireguard-tools
	@echo "WireGuard tools installed"
