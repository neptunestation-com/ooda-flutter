# OODA-Flutter Quickstart

## Setup (once)

```bash
# Install ooda CLI globally
dart pub global activate --source git https://github.com/neptunestation-com/ooda-flutter.git --git-path packages/ooda_runner

# Verify
ooda devices
```

## New Project

### 1. Create Flutter app

```bash
flutter create my_app
cd my_app
```

### 2. Enable semantics

Add to `lib/main.dart`:

```dart
import 'package:flutter/rendering.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const MyApp());
}
```

### 3. Create a scene

Create `scenes/home.yaml`:

```yaml
name: home_screen
steps:
  - checkpoint: initial
  - tap: { x: 540, y: 400 }
  - wait: visual_stability
  - checkpoint: after_tap
```

### 4. Run scene

```bash
# Connect your phone, then:
ooda scene -s scenes/home.yaml -p .
```

### 5. Use with Claude Code

Observations are saved to `obs/<scene>/<checkpoint>/`:
- `device.png` - What the phone displays
- `flutter.png` - What Flutter renders
- `widget_tree.json` - UI structure
- `semantics.json` - Accessibility tree

Ask Claude Code:
> "Look at obs/home_screen/initial/ and tell me what's on screen"

## Scene YAML Reference

```yaml
name: my_scene
setup:
  hot_restart: true        # Fresh app state
  navigate_to: /settings   # Deep link (requires GoRouter)

steps:
  - checkpoint: name       # Capture observation
  - tap: { x: 540, y: 400 }
  - input_text: "hello"
  - key: enter             # enter, back, tab, home
  - swipe: { start_x: 540, start_y: 1000, end_x: 540, end_y: 400 }
  - wait: visual_stability
```

## Tips

- Get tap coordinates: `ooda screenshot -d <device>` then inspect the PNG
- Overlay detection: Compare `device.png` vs `flutter.png` to spot keyboards/dialogs
- Scene iteration: Edit YAML, re-run scene, check observations
