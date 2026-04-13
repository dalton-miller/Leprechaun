RCLONE_VERSION = 1.73.4

.PHONY: all build release clean download-rclone setup

# Default: debug build
all: build

# Build debug
build: download-rclone
	swift build

# Build release + DMG
release: download-rclone
	swift build --configuration release
	./package.sh

# Build release + sign + notarize
release-signed: download-rclone
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo "Usage: make release-signed SIGN_IDENTITY='Developer ID Application: Name (TEAM)' TEAM_ID=XXXXX"; \
		exit 1; \
	fi
	swift build --configuration release
	./package.sh --sign "$(SIGN_IDENTITY)" --team-id "$(TEAM_ID)"

# Notarize as well
release-notarized: download-rclone
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo "Usage: make release-notarized SIGN_IDENTITY='...' TEAM_ID=XXXXX"; \
		exit 1; \
	fi
	swift build --configuration release
	./package.sh --sign "$(SIGN_IDENTITY)" --notarize --team-id "$(TEAM_ID)"

# Download rclone binaries for current host
download-rclone:
	@mkdir -p Sources/Leprechaun/Resources
	@if [ ! -f Sources/Leprechaun/Resources/rclone-darwin-arm64 ]; then \
		echo "Downloading rclone $(RCLONE_VERSION) for darwin-arm64…"; \
		curl -sL "https://downloads.rclone.org/v$(RCLONE_VERSION)/rclone-v$(RCLONE_VERSION)-osx-arm64.zip" -o /tmp/rclone-arm64.zip; \
		unzip -o /tmp/rclone-arm64.zip -d /tmp/rclone-arm64; \
		cp /tmp/rclone-arm64/rclone-v$(RCLONE_VERSION)-osx-arm64/rclone Sources/Leprechaun/Resources/rclone-darwin-arm64; \
		chmod +x Sources/Leprechaun/Resources/rclone-darwin-arm64; \
		rm -rf /tmp/rclone-arm64.zip /tmp/rclone-arm64; \
	else \
		echo "rclone-darwin-arm64 already present."; \
	fi
	@if [ ! -f Sources/Leprechaun/Resources/rclone-darwin-x86_64 ]; then \
		echo "Downloading rclone $(RCLONE_VERSION) for darwin-x86_64…"; \
		curl -sL "https://downloads.rclone.org/v$(RCLONE_VERSION)/rclone-v$(RCLONE_VERSION)-osx-amd64.zip" -o /tmp/rclone-x86_64.zip; \
		unzip -o /tmp/rclone-x86_64.zip -d /tmp/rclone-x86_64; \
		cp /tmp/rclone-x86_64/rclone-v$(RCLONE_VERSION)-osx-amd64/rclone Sources/Leprechaun/Resources/rclone-darwin-x86_64; \
		chmod +x Sources/Leprechaun/Resources/rclone-darwin-x86_64; \
		rm -rf /tmp/rclone-x86_64.zip /tmp/rclone-x86_64; \
	else \
		echo "rclone-darwin-x86_64 already present."; \
	fi

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -rf Sources/Leprechaun/Resources/rclone-darwin-arm64 Sources/Leprechaun/Resources/rclone-darwin-x86_64

# Run debug
run: download-rclone
	swift run Leprechaun
