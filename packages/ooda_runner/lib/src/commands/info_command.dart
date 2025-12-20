import 'dart:io';

import 'package:args/command_runner.dart';

/// Command to display documentation for AI agents and users.
class InfoCommand extends Command<int> {
  InfoCommand() {
    argParser.addFlag(
      'scene-yaml',
      help: 'Show scene YAML format reference.',
    );
    argParser.addFlag(
      'observations',
      help: 'Show observation bundle structure.',
    );
  }

  @override
  final String name = 'info';

  @override
  final String description = 'Display documentation and usage examples.';

  @override
  int run() {
    final showSceneYaml = argResults!['scene-yaml'] as bool;
    final showObservations = argResults!['observations'] as bool;

    if (showSceneYaml) {
      _printSceneYamlReference();
    } else if (showObservations) {
      _printObservationsReference();
    } else {
      _printFullInfo();
    }

    return 0;
  }

  void _printFullInfo() {
    stdout.writeln('''
OODA-Flutter: Control plane for AI agents to interact with Flutter apps.

QUICK START
-----------
1. Connect Android device, then:
   ooda devices                              # List devices
   ooda scene -s scene.yaml -p ./my_app      # Run scene

2. Observations saved to obs/<scene>/<checkpoint>/:
   device.png      What phone displays (keyboard, dialogs visible)
   flutter.png     What Flutter renders (app only)
   widget_tree.json   Widget hierarchy
   semantics.json     Accessibility tree (labels, roles, actions)

COMMANDS
--------
  devices              List connected Android devices
  screenshot -d DEV    Capture device screenshot
  scene -s FILE -p DIR Execute scene YAML, capture observations
  run -p DIR -d DEV    Start Flutter app with OODA control
  observe -d DEV       Capture observation from running app
  info                 Show this documentation
    --scene-yaml       Show scene YAML format
    --observations     Show observation file structure

SCENE YAML FORMAT (use --scene-yaml for full reference)
-------------------------------------------------------
name: my_scene
steps:
  - checkpoint: name           # Capture observation
  - tap: { x: 540, y: 400 }    # Tap coordinates
  - input_text: "hello"        # Type text
  - key: enter                 # enter, back, tab, home
  - wait: visual_stability     # Wait for screen to settle

NEW FLUTTER PROJECTS
--------------------
Enable semantics in lib/main.dart:

  import 'package:flutter/rendering.dart';
  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    SemanticsBinding.instance.ensureSemantics();
    runApp(const MyApp());
  }

MORE INFO
---------
  ooda info --scene-yaml       Full scene YAML reference
  ooda info --observations     Observation file details
''');
  }

  void _printSceneYamlReference() {
    stdout.writeln('''
SCENE YAML FORMAT
=================

name: my_scene                    # Required: scene identifier
description: Optional description

setup:                            # Optional: pre-execution setup
  hot_restart: true               # Restart app fresh
  navigate_to: /settings          # Deep link (app must support)
  setup_delay_ms: 500             # Wait after setup

steps:                            # Required: list of actions
  # Checkpoints - capture observation bundle
  - checkpoint: initial_state
    description: Optional note

  # Tap - touch at coordinates
  - tap: { x: 540, y: 400 }

  # Text input - type text (requires focused field)
  - input_text: "user@example.com"

  # Key events - special keys
  - key: enter    # Options: enter, back, tab, home, escape

  # Swipe - drag gesture
  - swipe:
      start_x: 540
      start_y: 1000
      end_x: 540
      end_y: 400
      duration_ms: 300            # Optional, default 300

  # Wait - pause until condition
  - wait: visual_stability        # Wait for screen to stop changing

barriers:                         # Optional: configure wait behavior
  visual_stability:
    timeout_ms: 5000
    consecutive_matches: 2

EXAMPLE
-------
name: login_flow
setup:
  hot_restart: true
steps:
  - checkpoint: initial
  - tap: { x: 540, y: 350 }       # Tap email field
  - input_text: "user@test.com"
  - key: tab                       # Move to password
  - input_text: "password123"
  - key: enter                     # Submit
  - wait: visual_stability
  - checkpoint: after_login

GETTING COORDINATES
-------------------
Run: ooda screenshot -d <device>
Then inspect the PNG to find tap coordinates.
''');
  }

  void _printObservationsReference() {
    stdout.writeln('''
OBSERVATION BUNDLE STRUCTURE
============================

Observations are saved to: obs/<scene_name>/<checkpoint_name>/

FILES
-----
device.png
  Screenshot from ADB framebuffer.
  Shows exactly what's on screen including:
  - System keyboard
  - System dialogs
  - Notifications
  - Status bar

flutter.png
  Screenshot from Flutter VM service.
  Shows only what Flutter rendered:
  - App UI content
  - NO system overlays

widget_tree.json
  Flutter widget hierarchy as JSON.
  Contains:
  - Widget types (Text, Container, etc.)
  - Widget properties
  - Hierarchy structure

semantics.json
  Accessibility tree dump.
  Contains:
  - Semantic labels ("Login", "Email")
  - Roles (button, textField, alertDialog)
  - Actions (tap, focus, scroll)
  - Flags (isEnabled, isFocused, isObscured)
  - Bounds (screen coordinates)

meta.json
  Capture metadata:
  - timestamp
  - overlayPresent (true if device != flutter)
  - checkpointName

logs.txt
  Flutter logs captured during observation.

OVERLAY DETECTION
-----------------
Compare device.png and flutter.png:
- If they differ, a system overlay is present
- Common overlays: keyboard, dialogs, date picker
- meta.json "overlayPresent" field indicates this

USING WITH AI PROMPTS
---------------------
"Look at obs/login_flow/email_entered/semantics.json - what fields exist?"
"Compare device.png and flutter.png - is the keyboard visible?"
"Based on widget_tree.json, what's the widget hierarchy?"
''');
  }
}
