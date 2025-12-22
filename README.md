# OODA-Flutter

An AI-driven OODA (Observe-Orient-Decide-Act) loop framework for automated Flutter UI testing on Android.

> **AI Coding Tools**: See [CLAUDE.md](CLAUDE.md) for quick-start instructions optimized for AI agents.

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
- Tap at coordinates or **by semantics label** (accessibility-based targeting)
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
  - tap_label: "Email"              # Tap by semantics label (recommended)
  - wait: visual_stability
  - input_text: "user@example.com"
  - tap_label: "Password"           # No need to hardcode coordinates
  - input_text: "password123"
  - tap_label: "Login"              # Works with buttons too
  - wait: visual_stability
  - checkpoint: after_login
    description: State after login attempt
barriers:
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 3
```

> **New in v0.3.0**: `tap_label` lets you tap elements by their accessibility label instead of coordinates. The framework captures the semantics tree, finds the matching label, and taps the center of that element's bounds.

**`tap_label` limitations:**
- Dialog content (AlertDialog, BottomSheet, DatePicker) uses overlay layers not in the semantics tree—use coordinates for dialog buttons
- Required form fields may include asterisks in labels (e.g., `"Name *"` not `"Name"`)
- Labels must match exactly (case-sensitive)

## Requirements

- **Dart SDK**: 3.10.0 or newer
- **Flutter SDK**: 3.0.0 or newer
- **Android**: Connected device or emulator with ADB access
- **ADB**: Android Debug Bridge installed and in PATH

## Installation

### Using in Your Flutter Project

**As a CLI tool** (recommended for AI agents):
```bash
# Install globally
dart pub global activate --source git \
  https://github.com/neptunestation-com/ooda-flutter.git \
  --git-path packages/ooda_runner

# Or use SSH URL if you have SSH keys configured
dart pub global activate --source git \
  git@github.com:neptunestation-com/ooda-flutter.git \
  --git-path packages/ooda_runner

# Now available as a global command
ooda devices
ooda screenshot -d <device_id>
ooda scene -f scene.yaml

# Update to latest version
ooda update
```

> **Automatic update checking**: When running in a terminal, ooda checks for new releases on startup and notifies you if an update is available.

**As a library dependency**:
```yaml
# In your pubspec.yaml
dependencies:
  ooda_runner:
    git:
      url: https://github.com/neptunestation-com/ooda-flutter.git
      path: packages/ooda_runner
      ref: v0.3.0  # Pin to a version tag
```

Or with SSH:
```yaml
dependencies:
  ooda_runner:
    git:
      url: git@github.com:neptunestation-com/ooda-flutter.git
      path: packages/ooda_runner
      ref: v0.3.0
```

```dart
import 'package:ooda_runner/ooda_runner.dart';

final adb = AdbClient();
final devices = await DeviceManager(adb).listDevices();
final controller = InteractionController(adb, devices.first.id);
await controller.tap(540, 400);
```

### Development Setup

For contributing or local development:

```bash
# Clone the repository
git clone https://github.com/neptunestation-com/ooda-flutter.git
cd ooda-flutter

# Install dependencies and bootstrap
dart pub global activate melos
dart pub get
dart pub global run melos bootstrap
```

## Usage

### CLI Commands

The `ooda` CLI tool is the main entry point. Run `ooda info --commands` for detailed options.

| Command      | Purpose                                                             |
|--------------|---------------------------------------------------------------------|
| `--version`  | Print ooda version                                                  |
| `devices`    | List connected Android devices                                      |
| `screenshot` | Capture device screenshot                                           |
| `scene`      | Execute scene YAML, capture observations                            |
| `run`        | Start Flutter app with OODA control                                 |
| `observe`    | Capture observation from running app                                |
| `info`       | Show documentation (`--commands`, `--scene-yaml`, `--observations`) |
| `update`     | Update ooda to latest version                                       |

**Quick examples:**
```bash
ooda --version                            # Print version
ooda devices                              # List devices
ooda screenshot -o screen.png             # Take screenshot
ooda scene -s login.yaml -p ./my_app      # Run scene
ooda run -p ./my_app -i                   # Run app interactively
ooda observe --start-app -p ./my_app      # Start app and capture observation
ooda info --commands                      # Show all command options
ooda update                               # Update to latest version
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

| Package        | Description                                                               |
|----------------|---------------------------------------------------------------------------|
| `ooda_shared`  | Shared types: `Interaction`, `BarrierResult`, `SceneDefinition`, etc.     |
| `ooda_runner`  | CLI tool with ADB integration, barriers, observation, and scene execution |
| `ooda_flutter` | Optional in-app package for enhanced observation (Flutter-side)           |

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
# All tests
dart pub global run melos exec --scope="ooda_shared,ooda_runner" -- dart test

# Single test file
dart test packages/ooda_runner/test/barriers/barrier_test.dart
```

### Code Analysis

```bash
dart pub global run melos exec -- dart analyze .
```

### Formatting

```bash
dart pub global run melos exec -- dart format .
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests and analysis
5. Commit your changes with a descriptive message
6. Push to your fork and open a Pull Request

### Code Style

- Format code before committing: `dart pub global run melos exec -- dart format .`
- Ensure analysis passes: `dart pub global run melos exec -- dart analyze .`
- Add tests for new functionality
