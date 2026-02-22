.PHONY: build release dmg clean run help xcodegen check

APP_NAME = ZeroTeir
PROJECT_FILE = $(APP_NAME).xcodeproj
SCHEME = $(APP_NAME)
TEAM_ID = 7552UR9ZVD
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/Export
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg

help:
	@echo "ZeroTeir Build System (XcodeGen + NetworkExtension)"
	@echo ""
	@echo "Available targets:"
	@echo "  make xcodegen - Generate Xcode project from project.yml"
	@echo "  make build    - Build Debug configuration"
	@echo "  make release  - Build Release archive"
	@echo "  make dmg      - Create distributable DMG"
	@echo "  make run      - Build and run the app"
	@echo "  make check    - Check dependency versions"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show this help message"

xcodegen:
	@echo "Generating Xcode project..."
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate
	@# Fix XcodeGen bug: local SPM package reference not linked in product dependency
	@PKGREF=$$(grep -B1 'XCLocalSwiftPackageReference' $(PROJECT_FILE)/project.pbxproj | head -1 | awk '{print $$1}'); \
	if [ -n "$$PKGREF" ]; then \
		sed -i '' "s/isa = XCSwiftPackageProductDependency;/isa = XCSwiftPackageProductDependency; package = $$PKGREF;/" $(PROJECT_FILE)/project.pbxproj; \
	fi
	@echo "Xcode project generated at $(PROJECT_FILE)"

build: xcodegen
	@echo "Building $(APP_NAME) (Debug)..."
	xcodebuild -project $(PROJECT_FILE) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-derivedDataPath $(BUILD_DIR) \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		build

release: xcodegen
	@echo "Building $(APP_NAME) (Release archive)..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild archive \
		-project $(PROJECT_FILE) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-archivePath $(ARCHIVE_PATH) \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM=$(TEAM_ID)
	@echo "Archive created at $(ARCHIVE_PATH)"

dmg: release
	@echo "Creating DMG..."
	@mkdir -p $(EXPORT_PATH)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist
	./Scripts/build-dmg.sh "$(EXPORT_PATH)/$(APP_NAME).app" "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"

run: build
	@echo "Running $(APP_NAME)..."
	@APP_PATH=$$(find $(BUILD_DIR) -name "$(APP_NAME).app" -type d | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "Error: Could not find $(APP_NAME).app in $(BUILD_DIR)"; \
		exit 1; \
	fi; \
	open "$$APP_PATH"

check:
	@./Scripts/check-versions.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(PROJECT_FILE)
	@rm -rf *.xcworkspace
	@rm -rf .swiftpm
	@echo "Clean complete"
