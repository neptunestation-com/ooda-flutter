# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this?

**ooda-flutter** is a control plane for AI agents to interact with and observe Flutter apps on Android. It runs scenes (scripted interactions), captures observations (screenshots, widget trees, semantics), and outputs structured data for AI analysis.

## Quick Start (Most Common Workflow)

### 1. Run a scene against a Flutter app

```bash
# From this repo root, with a phone connected:
dart run packages/ooda_runner/bin/ooda.dart scene \
  -s examples/ooda_showcase/scenes/login_flow.yaml \
  -p examples/ooda_showcase
```

### 2. Analyze the observations

Observations are saved to `obs/<scene_name>/<checkpoint_name>/` by default (override with `-o`):

| File               | Contents                                                    |
|--------------------|-------------------------------------------------------------|
| `device.png`       | What the phone displays (includes keyboard, system dialogs) |
| `flutter.png`      | What Flutter renders (app content only)                     |
| `widget_tree.json` | Widget hierarchy with types and properties                  |
| `semantics.json`   | Accessibility tree with labels, roles, actions              |
| `meta.json`        | Timestamp, overlay detection result                         |
| `logs.txt`         | Flutter logs during capture                                 |
| `diff.png`         | Visual diff (only generated when overlay detected)          |

**Overlay detection**: Compares `device.png` and `flutter.png` to detect system overlays:

| Detected as overlay | NOT detected (expected) |
|---------------------|-------------------------|
| Keyboard (IME)      | Flutter AlertDialog     |
| Permission dialogs  | Flutter BottomSheet     |
| System notifications| Flutter DatePicker      |
| Toast messages      | Any Flutter-rendered UI |

The comparison excludes top 5% (status bar) and bottom 12% (nav bar) to avoid false positives from system UI that differs between device and Flutter screenshots.

### 3. Use observations in prompts

```
Look at obs/login_flow/email_entered/ and describe what's on screen.
Based on the semantics.json, what form fields are available?
Compare device.png and flutter.png - is the keyboard visible?
```

## CLI Commands

Run from repo root with `dart run packages/ooda_runner/bin/ooda.dart <command>`, or if installed globally, just `ooda <command>`:

| Command                        | Purpose                                |
|--------------------------------|----------------------------------------|
| `devices`                      | List connected Android devices         |
| `screenshot`                   | Capture device screenshot              |
| `scene -s <yaml> -p <project>` | Execute scene and capture observations |
| `run -p <project> [-i]`        | Start Flutter app with OODA control (-i for interactive) |
| `observe`                      | Capture observation from running app   |
| `info`                         | Show built-in documentation            |
| `info --commands`              | Detailed options for all commands      |
| `info --scene-yaml`            | Full scene YAML format reference       |
| `info --observations`          | Observation file structure details     |
| `update`                       | Update ooda to latest version          |
| `update --ref <tag>`           | Install specific version               |

Run `ooda info --commands` for all options, or `ooda <command> --help` for specific command help.

## Scene YAML Format

```yaml
name: my_scene
setup:
  hot_restart: true              # Start fresh
  navigate_to: /settings         # Deep link (uses ooda://showcase/<route>)

steps:
  - checkpoint: initial          # Capture observation
  - tap: { x: 540, y: 400 }      # Tap coordinates
  - input_text: "user@test.com"  # Type text
  - key: enter                   # Key events: enter, back, tab, home, escape
  - swipe: { start_x: 540, start_y: 1000, end_x: 540, end_y: 400 }
  - wait: visual_stability       # Wait for screen to settle
  - wait: { type: delay, timeout: 500 }  # Fixed delay in ms
  - checkpoint: after_input      # Capture again

barriers:
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 2
```

## For New Flutter Projects

Add to `lib/main.dart` to enable semantics capture:

```dart
import 'package:flutter/rendering.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MyApp());
}
```

## Example Scenes

Located in `examples/ooda_showcase/scenes/`:
- `login_flow.yaml` - Form input, validation
- `dialog_test.yaml` - Dialog overlay detection
- `scroll_test.yaml` - List scrolling
- `form_validation.yaml` - Form validation scenarios
- `navigation_test.yaml` - Navigation and routing

---

## Development Reference

### Requirements

- Dart SDK 3.10.0+ (required for pub workspaces)
- Flutter SDK 3.0.0+
- ADB (Android Debug Bridge) in PATH
- Connected Android device or emulator

### Build & Test

```bash
dart pub get                     # Get dependencies (uses Dart 3.10+ pub workspaces)
dart pub global activate melos   # Install melos (one-time)
melos bootstrap                  # Bootstrap workspace

melos run test                   # Run all tests
melos run analyze                # Static analysis
melos run format                 # Format code
melos run clean                  # Clean build artifacts

# Single test file
dart test packages/ooda_runner/test/scenes/scene_parser_test.dart

# Tests for a specific package
dart test packages/ooda_runner/test/
dart test packages/ooda_shared/test/
```

### Package Structure

| Package        | Purpose                                                          |
|----------------|------------------------------------------------------------------|
| `ooda_shared`  | Shared types: `Interaction`, `SceneDefinition`, `BarrierResult`  |
| `ooda_runner`  | CLI and control plane (pure Dart, no Flutter dependency)         |
| `ooda_flutter` | In-app package (placeholder for future Flutter-side integration) |

### Architecture

**Data Flow**: Scene YAML → `SceneParser` → `SceneExecutor` → (`InteractionController` for actions, `ObservationBundle` for checkpoints) → Output to `obs/` directory

**Two-Camera Model**: `DeviceCamera` (ADB framebuffer) captures what's displayed including system UI. `FlutterCamera` (VM service) captures only Flutter-rendered content. `OverlayDetector` compares both to detect system overlays (keyboard, dialogs). Before comparison, screenshots are canonicalized to 1080x1920, and top 5% / bottom 12% are excluded to ignore status bar and nav bar differences.

**Barrier System**: Barriers block execution until conditions are met (e.g., `VisualStabilityBarrier` waits for animations to settle, `AppReadyBarrier` waits for app startup). `FlutterSession` manages app lifecycle via `flutter run --machine` JSON-RPC protocol.

**VM Service Integration**: `VmServiceClient` connects to the running Flutter app's Dart VM service to capture Flutter-only screenshots, widget trees, and semantics data.

### Key Source Locations

- **CLI Commands**: `packages/ooda_runner/lib/src/commands/`
- **Scene Execution**: `packages/ooda_runner/lib/src/scenes/` (`SceneParser`, `SceneExecutor`)
- **Observation**: `packages/ooda_runner/lib/src/observation/` (`DeviceCamera`, `FlutterCamera`, `OverlayDetector`)
- **Device Control**: `packages/ooda_runner/lib/src/adb/` (`AdbClient`, `DeviceManager`)
- **Barriers**: `packages/ooda_runner/lib/src/barriers/`
- **Flutter Session**: `packages/ooda_runner/lib/src/runner/flutter_session.dart`

### Programmatic Usage

```dart
import 'package:ooda_runner/ooda_runner.dart';

final adb = AdbClient();
final devices = await DeviceManager(adb).listDevices();
final controller = InteractionController(adb, devices.first.id);
await controller.tap(540, 400);
```
