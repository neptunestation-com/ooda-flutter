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

Observations are saved to `obs/<scene_name>/<checkpoint_name>/`:

| File               | Contents                                                    |
|--------------------|-------------------------------------------------------------|
| `device.png`       | What the phone displays (includes keyboard, system dialogs) |
| `flutter.png`      | What Flutter renders (app content only)                     |
| `widget_tree.json` | Widget hierarchy with types and properties                  |
| `semantics.json`   | Accessibility tree with labels, roles, actions              |
| `meta.json`        | Timestamp, overlay detection result                         |
| `logs.txt`         | Flutter logs during capture                                 |

**Overlay detection**: If `device.png` differs from `flutter.png`, a system overlay (keyboard, dialog) is present.

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
| `run -p <project>`             | Start Flutter app with OODA control    |
| `observe`                      | Capture observation from running app   |
| `info`                         | Show built-in documentation            |
| `info --commands`              | Detailed options for all commands      |
| `info --scene-yaml`            | Full scene YAML format reference       |
| `info --observations`          | Observation file structure details     |

Run `ooda info --commands` for all options, or `ooda <command> --help` for specific command help.

## Scene YAML Format

```yaml
name: my_scene
setup:
  hot_restart: true              # Start fresh
  navigate_to: /settings         # Deep link (requires app support)

steps:
  - checkpoint: initial          # Capture observation
  - tap: { x: 540, y: 400 }      # Tap coordinates
  - input_text: "user@test.com"  # Type text
  - key: enter                   # Key event: enter, back, tab, home
  - swipe: { start_x: 540, start_y: 1000, end_x: 540, end_y: 400 }
  - wait: visual_stability       # Wait for screen to settle
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
- `keyboard_test.yaml` - Keyboard interactions

---

## Development Reference

### Requirements

- Dart SDK 3.10.0+ (required for pub workspaces)
- Flutter SDK 3.0.0+
- ADB (Android Debug Bridge) in PATH
- Connected Android device or emulator

### Build & Test

```bash
dart pub get                        # Get dependencies
dart pub global activate melos      # Install melos (one-time)
dart pub global run melos bootstrap # Bootstrap workspace

# Run tests
dart pub global run melos exec --scope="ooda_shared,ooda_runner" -- dart test

# Static analysis
dart pub global run melos exec -- dart analyze .

# Format code
dart pub global run melos exec -- dart format .
```

### Package Structure

| Package        | Purpose                                                          |
|----------------|------------------------------------------------------------------|
| `ooda_shared`  | Shared types: `Interaction`, `SceneDefinition`, `BarrierResult`  |
| `ooda_runner`  | CLI and control plane (pure Dart, no Flutter dependency)         |
| `ooda_flutter` | In-app package (placeholder for future Flutter-side integration) |

### Key Components

**Scene Execution** (`packages/ooda_runner/lib/src/scenes/`):
- `SceneParser` - Parses YAML scene definitions
- `SceneExecutor` - Runs steps, captures checkpoints

**Observation** (`packages/ooda_runner/lib/src/observation/`):
- `DeviceCamera` - ADB screenshots (shows system UI)
- `FlutterCamera` - VM service screenshots + widget tree + semantics
- `OverlayDetector` - Compares cameras to detect overlays

**Device Control** (`packages/ooda_runner/lib/src/adb/`):
- `AdbClient` - Tap, swipe, text, screenshots via ADB
- `DeviceManager` - Device discovery

**Barriers** (`packages/ooda_runner/lib/src/barriers/`):
- `VisualStabilityBarrier` - Wait for screen to stop changing
- `AppReadyBarrier` - Wait for app to start
- `HotReloadBarrier` - Wait for hot restart to complete

### Programmatic Usage

```dart
import 'package:ooda_runner/ooda_runner.dart';

final adb = AdbClient();
final devices = await DeviceManager(adb).listDevices();
final controller = InteractionController(adb, devices.first.id);
await controller.tap(540, 400);
```

### Tests

```bash
# All tests
dart pub global run melos exec --scope="ooda_shared,ooda_runner" -- dart test

# Single test file
dart test packages/ooda_runner/test/scenes/scene_parser_test.dart
```
