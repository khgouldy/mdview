.PHONY: help tools gen lint format test build-ios test-ios open clean

SCHEME = mdview
PROJECT = mdview.xcodeproj
DERIVED_DATA = .derivedData
RESOLVED = $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
IOS_DESTINATION = generic/platform=iOS
MDVIEW_IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 16

help:
	@echo "mdview targets:"
	@echo "  tools      Install xcodegen, swiftformat, and swiftlint if they are missing"
	@echo "  gen        Copy Config/Local.xcconfig if needed and generate the Xcode project"
	@echo "  lint       swiftformat --lint and swiftlint (strict)"
	@echo "  format     Apply swiftformat and swiftlint --fix"
	@echo "  test       swift test Packages/MDCore, then an unsigned generic iOS build"
	@echo "  build-ios  xcodebuild for generic/platform=iOS with signing disabled"
	@echo "  test-ios   Simulator XCUITest. Refuses unless CI=true or MDVIEW_ALLOW_SIMULATOR=1"
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
	swiftformat --lint .
	swiftlint lint --strict

format: tools
	swiftformat .
	swiftlint lint --fix

test: tools gen
	swift test --package-path Packages/MDCore
	$(MAKE) build-ios

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
		CODE_SIGNING_ALLOWED=NO

open: gen
	open $(PROJECT)

clean:
	rm -rf $(PROJECT) $(DERIVED_DATA) Packages/MDCore/.build Packages/MDCore/.swiftpm
