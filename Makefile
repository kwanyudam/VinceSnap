APP_NAME = VinceSnap
BUILD_DIR = build
APP_BUNDLE = $(APP_NAME).app
SOURCES = $(wildcard Sources/VinceSnap/*.swift)

# Note: this Makefile invokes swiftc directly instead of `swift build`
# because the current Command Line Tools install has a mismatched
# PackageDescription dylib that breaks SPM manifest loading.
# Package.swift is kept so `swift build` works once the toolchain is fixed
# (e.g. after reinstalling CLT or pointing xcode-select at full Xcode).

.PHONY: build bundle run clean

build: $(BUILD_DIR)/$(APP_NAME)

$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	swiftc -O $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)

# Wrap the binary in a proper .app bundle so macOS treats it as a real app
# (its own Accessibility permission entry, no Dock icon via LSUIElement).
# Ad-hoc codesigning keeps the Accessibility grant stable across rebuilds.
bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	codesign --force --sign - $(APP_BUNDLE)

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE) .build
