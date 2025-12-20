# OODA-Flutter

An AI-driven OODA (Observe-Orient-Decide-Act) loop framework for automated Flutter UI testing on Android.

## What is this?

OODA-Flutter provides a **control plane for AI agents** to autonomously build, run, observe, interact with, and critique Flutter applications. It bridges the gap between AI systems and Flutter's UI layer, enabling:

- **Automated UI testing** driven by AI agents rather than hand-coded test scripts
- **Visual observation** with screenshot capture from both the device (ADB) and Flutter engine
- **Overlay detection** to identify system UI elements (keyboard, dialogs) overlaying the app
- **Structured scene execution** defined in simple YAML files
- **Rich introspection** including widget trees, semantics trees, and app logs

## Why OODA?

The [OODA loop](https://en.wikipedia.org/wiki/OODA_loop) (Observe-Orient-Decide-Act) is a decision-making framework. This project implements the "Observe" and "Act" phases for Flutter apps:

- **Observe**: Capture screenshots, widget trees, semantics, logs, and detect overlays
- **Act**: Execute interactions (tap, swipe, text input, key events) on the device

The "Orient" and "Decide" phases are left to the AI agent consuming this framework.

## Features

### Device Interaction
- Tap at coordinates
- Swipe gestures with configurable duration
- Text input
- Key events (back, home, enter, etc.)

### Observation Capabilities
- **Two-camera model**: Captures both ADB framebuffer screenshots and Flutter engine screenshots
- **Overlay detection**: Compares the two captures to detect system overlays (keyboard, dialogs, notifications)
- **Widget tree extraction**: Full widget hierarchy from the running app
- **Semantics tree extraction**: Accessibility tree for understanding UI structure
- **Log capture**: App logs during observation

### Barrier System
Barriers are conditions the framework waits for before proceeding:
- **DeviceReadyBarrier**: Wait for device boot completion
- **AppReadyBarrier**: Wait for Flutter app to start
- **HotReloadBarrier**: Wait for hot reload/restart to complete
- **VmServiceReadyBarrier**: Wait for VM service connection
- **VisualStabilityBarrier**: Wait for screen to stop changing (animations complete)

### Scene Execution
Define test scenarios in YAML:

```yaml
name: login_flow
setup:
  hot_restart: true
steps:
  - checkpoint: initial_screen
    description: Login form before interaction
  - tap: { x: 540, y: 400 }
  - wait: visual_stability
  - input_text: "user@example.com"
  - tap: { x: 540, y: 500 }
  - input_text: "password123"
  - tap: { x: 540, y: 700 }
  - wait: visual_stability
  - checkpoint: after_login
    description: State after login attempt
barriers:
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 3
```

## Requirements

- **Dart SDK**: 3.10.0 or newer
- **Flutter SDK**: 3.0.0 or newer
- **Android**: Connected device or emulator with ADB access
- **ADB**: Android Debug Bridge installed and in PATH

## Installation

```bash
# Clone the repository
git clone https://github.com/neptunestation-com/ooda-flutter.git
cd ooda-flutter

# Install dependencies (uses Dart pub workspaces)
dart pub get

# Optional: Bootstrap with melos for IDE integration
melos bootstrap
```

## Usage

### CLI Commands

The `ooda` CLI tool is the main entry point:

```bash
cd packages/ooda_runner

# List connected devices
dart run bin/ooda.dart devices

# Take a screenshot
dart run bin/ooda.dart screenshot -d <device_id>

# Run a scene
dart run bin/ooda.dart scene -f path/to/scene.yaml

# Run and observe a Flutter app
dart run bin/ooda.dart run -p /path/to/flutter/project -d <device_id>
```

### Running Example Apps

The repository includes example Flutter apps for testing:

```bash
# Run the showcase app
cd examples/ooda_showcase
flutter run

# Run a scene against the showcase app
dart run packages/ooda_runner/bin/ooda.dart scene \
  -f examples/ooda_showcase/scenes/login_flow.yaml \
  -p examples/ooda_showcase
```

### Programmatic Usage

```dart
import 'package:ooda_runner/ooda_runner.dart';

// Connect to a device
final adb = AdbClient();
final devices = await DeviceManager(adb).listDevices();
final device = devices.first;

// Execute interactions
final controller = InteractionController(adb, device.id);
await controller.tap(540, 400);
await controller.inputText('Hello, World!');
await controller.swipe(startX: 540, startY: 1000, endX: 540, endY: 500);

// Capture observations
final camera = DeviceCamera(adb, device.id);
final screenshot = await camera.capture();
```

## Project Structure

```
ooda-flutter/
├── packages/
│   ├── ooda_shared/     # Shared types and models
│   ├── ooda_runner/     # CLI tool and control plane
│   └── ooda_flutter/    # In-app Flutter package
├── examples/
│   ├── ooda_showcase/   # Comprehensive demo app
│   └── minimal/         # Single-purpose test apps
│       ├── keyboard_app/
│       ├── scroll_app/
│       ├── dialog_app/
│       └── ...
└── pubspec.yaml         # Workspace configuration
```

### Package Overview

| Package | Description |
|---------|-------------|
| `ooda_shared` | Shared types: `Interaction`, `BarrierResult`, `SceneDefinition`, etc. |
| `ooda_runner` | CLI tool with ADB integration, barriers, observation, and scene execution |
| `ooda_flutter` | Optional in-app package for enhanced observation (Flutter-side) |

## How It Works

### The Two-Camera Model

OODA-Flutter captures two screenshots simultaneously:

1. **Device screenshot** (via ADB framebuffer): Shows exactly what's on screen, including system UI
2. **Flutter screenshot** (via VM service): Shows only what Flutter rendered

By comparing these two images, the framework detects **overlays**—system UI elements like the keyboard, dialogs, or notifications that appear on top of the Flutter app. This is crucial for AI agents to understand the true state of the UI.

### Scene Execution Flow

1. **Parse** the scene YAML file
2. **Setup** the app (hot restart, navigate to route, etc.)
3. **Execute steps** sequentially:
   - **Checkpoints**: Capture an `ObservationBundle` (screenshots, widget tree, semantics, logs)
   - **Interactions**: Execute device actions (tap, swipe, text, keys)
   - **Waits**: Block until a barrier condition is met
4. **Return** all captured observations for AI analysis

## Development

### Running Tests

```bash
# Run all tests
melos exec --scope="ooda_shared,ooda_runner" -- dart test

# Run tests for a specific package
cd packages/ooda_runner
dart test

# Run a specific test file
dart test test/barriers/barrier_test.dart
```

### Code Analysis

```bash
melos exec -- dart analyze .
```

### Formatting

```bash
melos exec -- dart format .
```

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
