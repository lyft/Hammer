.DEFAULT_GOAL := generate

# Code Signing Settings

NO_CODE_SIGN_SETTINGS = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Install Tasks

install-lint:
	brew list swiftlint &>/dev/null || brew install swiftlint

install-xcodegen:
	brew list xcodegen &>/dev/null || brew install xcodegen

install-xcbeautify:
	brew list xcbeautify &>/dev/null || brew install xcbeautify

# Run Tasks

generate: install-xcodegen
	xcodegen generate

test: lint test-iPad

lint: install-lint
	swiftlint lint --strict 2>/dev/null

test-iPad:
	set -o pipefail && \
		xcodebuild \
		-project Hammer.xcodeproj \
		-scheme Hammer \
		-destination "name=iPad Pro (12.9-inch) (6th generation)" \
		test \
		$(NO_CODE_SIGN_SETTINGS) | xcbeautify

test-iPhone:
	set -o pipefail && \
		xcodebuild \
		-project Hammer.xcodeproj \
		-scheme Hammer \
		-destination "name=iPhone 15" \
		test \
		$(NO_CODE_SIGN_SETTINGS) | xcbeautify

test-iPhone-iOS16:
	set -o pipefail && \
		xcodebuild \
		-project Hammer.xcodeproj \
		-scheme Hammer \
		-destination "name=iPhone 14" \
		-sdk iphonesimulator16.1 \
		test \
		$(NO_CODE_SIGN_SETTINGS) | xcbeautify

# List all targets (from https://stackoverflow.com/questions/4219255/how-do-you-get-the-list-of-targets-in-a-makefile)

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
