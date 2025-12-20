# OODA-Flutter Makefile
# Human-friendly wrapper for common development tasks

# Use dart pub global run for portability (doesn't require ~/.pub-cache/bin in PATH)
MELOS := dart pub global run melos

.PHONY: help setup bootstrap test analyze format clean devices screenshot

# Default target
help:
	@echo "OODA-Flutter Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup      - Install dependencies (dart pub get)"
	@echo "  make bootstrap  - Bootstrap with melos (IDE integration)"
	@echo ""
	@echo "Development:"
	@echo "  make test       - Run all tests"
	@echo "  make analyze    - Run static analysis"
	@echo "  make format     - Format all code"
	@echo "  make clean      - Clean build artifacts"
	@echo ""
	@echo "CLI (requires connected device):"
	@echo "  make devices    - List connected Android devices"
	@echo "  make screenshot - Take a screenshot (auto-selects device)"
	@echo ""
	@echo "Examples:"
	@echo "  make showcase   - Run the showcase app"
	@echo ""

# Setup targets
setup:
	dart pub global activate melos
	dart pub get

bootstrap: setup
	$(MELOS) bootstrap

# Development targets
test:
	$(MELOS) exec --scope="ooda_shared,ooda_runner" -- dart test

analyze:
	$(MELOS) exec -- dart analyze .

format:
	$(MELOS) exec -- dart format .

clean:
	$(MELOS) exec -- rm -rf .dart_tool build

# CLI targets
devices:
	cd packages/ooda_runner && dart run bin/ooda.dart devices

screenshot:
	cd packages/ooda_runner && dart run bin/ooda.dart screenshot

# Example app targets
showcase:
	cd examples/ooda_showcase && flutter run
