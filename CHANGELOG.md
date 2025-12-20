# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-20

### Added
- **ADB Layer**: `AdbClient` for device communication (tap, swipe, text input, screenshots)
- **Device Management**: `DeviceManager` for device discovery and selection
- **Barrier System**: Condition-waiting primitives
  - `DeviceReadyBarrier`: Wait for device boot
  - `AppReadyBarrier`: Wait for Flutter app start
  - `HotReloadBarrier`: Wait for hot reload completion
  - `VmServiceReadyBarrier`: Wait for VM service connection
  - `VisualStabilityBarrier`: Wait for screen stability
- **Flutter Daemon**: JSON-RPC protocol handler for `flutter run --machine`
- **Session Management**: `FlutterSession` for app lifecycle
- **Observation System**: Two-camera model for overlay detection
  - `DeviceCamera`: ADB framebuffer screenshots
  - `FlutterCamera`: Flutter engine screenshots via VM service
  - `OverlayDetector`: Compare screenshots to detect system overlays
  - `ObservationBundle`: Structured output (screenshots, widget tree, semantics, logs)
- **Scene Execution**: YAML-based test scenario definitions
  - `SceneParser`: Parse scene YAML files
  - `SceneExecutor`: Orchestrate scene execution
- **Interactions**: Device input primitives
  - Tap, swipe, text input, key events (back, home, enter, etc.)
- **CLI Tool**: `ooda` command with subcommands
  - `devices`: List connected Android devices
  - `screenshot`: Capture device screenshot
  - `run`: Run Flutter app with observation
  - `observe`: Capture observation bundle
  - `scene`: Execute scene YAML file
- **Example Apps**: Showcase app and minimal single-purpose test apps
