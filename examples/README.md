# OODA-Flutter Examples

Example Flutter apps for testing and demonstrating the OODA-Flutter framework.

## Apps

### ooda_showcase

Comprehensive demo app with multiple screens demonstrating all framework capabilities.

**Run minimal variant:**
```bash
cd ooda_showcase
flutter run
```

**Run polished variant:**
```bash
cd ooda_showcase
flutter run -t lib/main_polished.dart
```

**Screens:**
- `/` - Home: Navigation to all features
- `/login` - Login: Form inputs, keyboard, validation
- `/items` - Item List: Scrolling with 100+ items
- `/dialogs` - Dialogs: AlertDialog, BottomSheet, overlays
- `/forms` - Forms: Validation, keyboard types
- `/navigation` - Navigation: Drawer, tabs, back button

**Run scenes:**
```bash
# From repo root
dart run packages/ooda_runner/bin/ooda.dart scene \
  -f examples/ooda_showcase/scenes/login_flow.yaml \
  -p examples/ooda_showcase
```

### minimal/

Single-purpose apps for focused testing:

| App | Purpose |
|-----|---------|
| keyboard_app | Keyboard visibility, text input, key events |
| scroll_app | ListView scrolling |
| dialog_app | Overlay detection |
| form_app | Form validation |
| gestures_app | Touch gestures |
| animation_app | Visual stability with animations |

## Development

These examples use path dependencies to the local `ooda_flutter` package:

```yaml
dependencies:
  ooda_flutter:
    path: ../../packages/ooda_flutter
```

Run `melos bootstrap` from the repo root to link all packages.
