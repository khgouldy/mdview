.PHONY: help tools gen lint check-config icon format test build-tests build-ios test-ios archive upload open clean

SCHEME = mdview
PROJECT = mdview.xcodeproj
DERIVED_DATA = .derivedData
RESOLVED = $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
IOS_DESTINATION = generic/platform=iOS
# CI installs exactly this SwiftFormat (.github/workflows/ci.yml checks that the two agree). Formatting rules change
# between releases, so a different local version can pass lint here and fail on CI, or the other way round.
SWIFTFORMAT_VERSION = 0.64.1
MDVIEW_IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 16
# Extra xcodebuild test arguments, e.g. -only-testing:mdviewUITests/FindTests (CI's only_testing dispatch input).
TEST_IOS_ARGS ?=
BUILD_DIR ?= $(HOME)/GrokBot/builds/mdview
ARCHIVE_PATH ?= $(BUILD_DIR)/mdview.xcarchive
# Env file defining APPSTORE_CONNECT_KEY_ID, APPSTORE_CONNECT_ISSUER_ID, APPSTORE_CONNECT_KEY_PATH.
ASC_ENV ?= $(HOME)/.appstoreconnect/mdview.env
ASC_AUTH = -allowProvisioningUpdates -authenticationKeyPath "$$(eval echo $$APPSTORE_CONNECT_KEY_PATH)" -authenticationKeyID "$$APPSTORE_CONNECT_KEY_ID" -authenticationKeyIssuerID "$$APPSTORE_CONNECT_ISSUER_ID"

help:
	@echo "mdview targets:"
	@echo "  tools      Install xcodegen, swiftformat, and swiftlint if they are missing"
	@echo "  gen        Copy Config/Local.xcconfig if needed and generate the Xcode project"
	@echo "  lint       swiftformat --lint, swiftlint (strict), then check-config"
	@echo "  check-config  scripts/check_app_config.py (team ID, bundle IDs, privacy manifests, TRUEPREDICATE)"
	@echo "  icon       Install icon direction ICON=a|b|c (default a) into AppIcon.appiconset: any, dark and tinted"
	@echo "  format     Apply swiftformat and swiftlint --fix"
	@echo "  test       swift test Packages/MDCore, then build-tests"
	@echo "  build-tests  xcodebuild build-for-testing (app and UI tests) for generic iOS, no simulator"
	@echo "  build-ios  xcodebuild for generic/platform=iOS with signing disabled"
	@echo "  test-ios   Simulator XCUITest. Refuses unless CI=true or MDVIEW_ALLOW_SIMULATOR=1"
	@echo "  archive    Signed Release archive into BUILD_DIR (App Store Connect API key from ASC_ENV)"
	@echo "  upload     Export the archive and upload it to App Store Connect"
	@echo "  open       Generate the project and open it in Xcode"
	@echo "  clean      Remove the generated project and local build products"

tools:
	@command -v xcodegen >/dev/null 2>&1 || HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
	@command -v swiftformat >/dev/null 2>&1 || HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftformat
	@command -v swiftlint >/dev/null 2>&1 || HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftlint

gen: tools
	@test -f Config/Local.xcconfig || cp -f Config/Local.xcconfig.example Config/Local.xcconfig
	@resolved="$(RESOLVED)"; \
	backup=""; \
	if [ -f "$$resolved" ]; then backup=$$(mktemp); cp -f "$$resolved" "$$backup"; fi; \
	xcodegen generate; \
	status=$$?; \
	if [ -n "$$backup" ]; then mkdir -p "$$(dirname "$$resolved")"; cp -f "$$backup" "$$resolved"; rm -f "$$backup"; fi; \
	exit $$status

lint: tools
	@v="$$(swiftformat --version)"; [ "$$v" = "$(SWIFTFORMAT_VERSION)" ] || \
		echo "warning: swiftformat $$v here, CI pins $(SWIFTFORMAT_VERSION); lint results may differ" >&2
	swiftformat --lint .
	swiftlint lint --strict
	@$(MAKE) --no-print-directory check-config

check-config:
	python3 scripts/check_app_config.py

ICON ?= a
ICON_SET = App/mdview/Assets.xcassets/AppIcon.appiconset

icon:
	@case "$(ICON)" in a|b|c) ;; *) echo "error: ICON must be a, b or c (got '$(ICON)')" >&2; exit 1;; esac
	python3 scripts/generate_app_icon.py --direction $(ICON) --appearance any --size 1024 --out $(ICON_SET)/AppIcon.png
	python3 scripts/generate_app_icon.py --direction $(ICON) --appearance dark --size 1024 --out $(ICON_SET)/AppIcon-dark.png
	python3 scripts/generate_app_icon.py --direction $(ICON) --appearance tinted --size 1024 --out $(ICON_SET)/AppIcon-tinted.png

format: tools
	swiftformat .
	swiftlint lint --fix

test: tools gen
	swift test --package-path Packages/MDCore
	$(MAKE) build-tests

build-tests: tools gen
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(IOS_DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

build-ios: tools gen
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(IOS_DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

test-ios: tools gen
	@if [ "$${CI}" != "true" ] && [ "$${MDVIEW_ALLOW_SIMULATOR}" != "1" ]; then \
		echo "error: make test-ios boots the iOS Simulator and runs the XCUITest launch test." >&2; \
		echo "This Mac does not run that target. GitHub Actions sets CI=true. A human can set MDVIEW_ALLOW_SIMULATOR=1." >&2; \
		exit 1; \
	fi
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(MDVIEW_IOS_DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-parallel-testing-enabled NO \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		$(TEST_IOS_ARGS) \
		CODE_SIGNING_ALLOWED=NO

archive: tools gen
	@mkdir -p "$(BUILD_DIR)"
	@set -a; . "$(ASC_ENV)"; set +a; \
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(IOS_DESTINATION)' \
		-archivePath "$(ARCHIVE_PATH)" \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		$(ASC_AUTH)

upload:
	@test -d "$(ARCHIVE_PATH)" || { echo "error: run make archive first" >&2; exit 1; }
	@team=$$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Config/Local.xcconfig); \
	test -n "$$team" || { echo "error: set DEVELOPMENT_TEAM in Config/Local.xcconfig" >&2; exit 1; }; \
	cp -f Config/ExportOptions.plist "$(BUILD_DIR)/ExportOptions.plist"; \
	/usr/libexec/PlistBuddy -c "Add :teamID string $$team" "$(BUILD_DIR)/ExportOptions.plist"; \
	set -a; . "$(ASC_ENV)"; set +a; \
	xcodebuild -exportArchive \
		-archivePath "$(ARCHIVE_PATH)" \
		-exportOptionsPlist "$(BUILD_DIR)/ExportOptions.plist" \
		-exportPath "$(BUILD_DIR)/export" \
		$(ASC_AUTH)

open: gen
	open $(PROJECT)

clean:
	rm -rf $(PROJECT) $(DERIVED_DATA) Packages/MDCore/.build Packages/MDCore/.swiftpm
