# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OODA-Flutter is an AI-driven OODA (Observe-Orient-Decide-Act) loop framework for automated Flutter UI testing on Android. It provides a control plane for AI agents to build, run, observe, interact with, and capture structured observations from Flutter applications.

## Build & Test Commands

This is a Dart monorepo using [pub workspaces](https://dart.dev/go/pub-workspaces) (Dart 3.10+) and [melos](https://melos.invertase.dev/) for orchestration.

```bash
# Get dependencies for all packages (pub workspaces - run from root)
dart pub get

# Bootstrap with melos (generates IDE files)
melos bootstrap

# Run tests on specific packages (non-interactive)
melos exec --scope="ooda_shared,ooda_runner" -- dart test

# Run static analysis on all packages
melos exec -- dart analyze .

# Format all packages
melos exec -- dart format .
```

**Per-package commands** (run from within a package directory):

```bash
# Run all tests in a package
dart test

# Run a single test file
dart test test/path/to/test_file.dart

# Run tests with name filter
dart test --name "test description pattern"

# Analyze code (linting)
dart analyze
```

**CLI commands** (from `packages/ooda_runner`):

```bash
dart run bin/ooda.dart devices
dart run bin/ooda.dart screenshot -d <device_id>
dart run bin/ooda.dart run -p /path/to/flutter/project -d <device_id>
dart run bin/ooda.dart observe -d <device_id>
dart run bin/ooda.dart scene -f example/scenes/login_flow.yaml
```

**Running example apps**:

```bash
# Run the showcase app (minimal variant)
cd examples/ooda_showcase && flutter run

# Run the showcase app (polished variant)
cd examples/ooda_showcase && flutter run -t lib/main_polished.dart

# Run a scene against an example app
dart run packages/ooda_runner/bin/ooda.dart scene \
  -f examples/ooda_showcase/scenes/login_flow.yaml \
  -p examples/ooda_showcase
```

## Architecture

### Three-Package Structure

- **ooda_shared**: Shared types and models used by both runner and Flutter packages
  - Models: `AdbDevice`, `BarrierResult`, `Interaction`, `SceneDefinition`, `CheckpointDefinition`
  - Events: `LifecycleEvent`, `RunnerEvent`

- **ooda_runner**: CLI tool and control plane (pure Dart, no Flutter dependency)
  - Entry point: `bin/ooda.dart` - CLI with commands: `devices`, `screenshot`, `run`, `observe`, `scene`
  - Core components described below

- **ooda_flutter**: In-app Flutter package for enhanced observation (currently minimal)

Note: `ooda_runner` re-exports all types from `ooda_shared`, so you can import just `package:ooda_runner/ooda_runner.dart` to get all types.

### Key Components in ooda_runner

**ADB Layer** (`src/adb/`):
- `AdbClient`: Device communication - tap, swipe, text input, screenshots, shell commands
- `DeviceManager`: Device discovery and selection

**Barrier System** (`src/barriers/`):
- Abstract `Barrier<T>`, `PollingBarrier<T>`, and `EventBarrier<T>` base classes for condition-waiting
- `DeviceReadyBarrier`: Waits for device boot completion
- `AppReadyBarrier`: Waits for Flutter app to start (listens for `app.started` event)
- `HotReloadBarrier`: Waits for hot reload/restart to complete
- `VmServiceReadyBarrier`: Waits for VM service WebSocket URI to be available
- `VisualStabilityBarrier`: Waits for screen to stabilize (consecutive matching screenshots)

**Flutter Daemon** (`src/daemon/`):
- `JsonRpcProtocol`: Parses Flutter's `--machine` JSON-RPC output
- `FlutterDaemonClient`: Communicates with `flutter run --machine`
- `VmServiceClient`: Connects to VM service for widget tree access

**Session Management** (`src/runner/`):
- `FlutterSession`: Manages `flutter run` process lifecycle, hot reload/restart, app state tracking

**Observation System** (`src/observation/`):
- `DeviceCamera`: ADB framebuffer screenshots
- `FlutterCamera`: Flutter engine screenshots via VM service
- `OverlayDetector`: Compares Flutter vs Device screenshots to detect system overlays (keyboard, dialogs)
- `ObservationBundle`: Structured output containing both screenshots, widget tree, semantics tree, logs, metadata

**Scene Execution** (`src/scenes/`):
- `SceneParser`: Parses YAML scene definitions
- `SceneExecutor`: Orchestrates scene execution - runs steps, captures checkpoints, handles barriers
- Scene YAML format: `name`, `setup`, `steps` (checkpoints and interactions), `barriers` config

**Interactions** (`src/interaction/`):
- `InteractionController`: Executes device interactions (tap, swipe, text input, key events)

### Data Flow

1. `SceneExecutor` loads a scene YAML and starts execution
2. For each step: either execute an `Interaction` via `InteractionController` or capture a `CheckpointDefinition`
3. Barriers (e.g., `VisualStabilityBarrier`) ensure the UI is ready before observations
4. `ObservationBundle` captures: device screenshot, Flutter screenshot, widget tree, semantics, logs
5. Two-camera model enables overlay detection by comparing Flutter-rendered vs ADB-captured frames

### Scene YAML Format

```yaml
name: example_scene
setup:
  hot_restart: true
  navigate_to: /route
  setup_delay_ms: 500
steps:
  - checkpoint: initial_view
    description: Before interaction
  - tap: { x: 540, y: 400 }
  - wait: visual_stability
  - input_text: "text to type"
  - swipe: { start_x: 540, start_y: 1000, end_x: 540, end_y: 500, duration_ms: 300 }
  - key: back                    # or: enter, home, tab, escape
  - checkpoint: after_input
barriers:
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 3
```

### Interaction Types (ooda_shared)

The sealed `Interaction` class has these subtypes:
- `TapInteraction`: x, y coordinates
- `TextInputInteraction`: text string
- `SwipeInteraction`: start/end x/y, duration_ms
- `KeyEventInteraction`: keyCode (constants: keyBack=4, keyEnter=66, keyHome=3, keyTab=61, keyEscape=111)
- `WaitInteraction`: barrierType, optional timeoutMs
