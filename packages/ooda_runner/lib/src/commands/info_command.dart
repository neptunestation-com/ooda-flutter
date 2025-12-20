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
    argParser.addFlag(
      'commands',
      help: 'Show detailed CLI command reference.',
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
    final showCommands = argResults!['commands'] as bool;

    if (showSceneYaml) {
      _printSceneYamlReference();
    } else if (showObservations) {
      _printObservationsReference();
    } else if (showCommands) {
      _printCommandsReference();
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
  screenshot           Capture device screenshot
  scene                Execute scene YAML, capture observations
  run                  Start Flutter app with OODA control
  observe              Capture observation from running app
  info                 Show this documentation
    --commands         Show detailed command options
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
  ooda info --commands         All command options
  ooda info --scene-yaml       Scene YAML format reference
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

  void _printCommandsReference() {
    stdout.writeln('''
CLI COMMAND REFERENCE
=====================

DEVICES
-------
List connected Android devices.

  ooda devices [options]

Options:
  -r, --ready-only      Only show devices that are ready
  -e, --emulators-only  Only show emulators
  -j, --json            Output in JSON format

Examples:
  ooda devices
  ooda devices --json
  ooda devices -r

SCREENSHOT
----------
Capture a screenshot from an Android device.

  ooda screenshot [options]

Options:
  -d, --device DEV      Device ID (auto-selects if not specified)
  -o, --output FILE     Output file path (default: screenshot.png)
  -w, --wait-stable     Wait for screen to stabilize before capturing
  -t, --timeout SEC     Timeout in seconds for stability wait (default: 5)
  -r, --resize          Resize for AI API compatibility (default: true)
  -m, --max-dimension N Max dimension in pixels when resizing

Examples:
  ooda screenshot
  ooda screenshot -o login_screen.png
  ooda screenshot -w -t 10

SCENE
-----
Execute a scene from a YAML file and capture observations.

  ooda scene -s FILE [options]

Options:
  -s, --scene FILE      Path to scene YAML file (required)
  -p, --project DIR     Flutter project directory (default: .)
  -d, --device DEV      Device ID (auto-selects if not specified)
  -o, --output DIR      Output directory for observations (default: obs)
  -v, --verbose         Show detailed execution logs
      --keep-running    Keep app running after scene execution

Examples:
  ooda scene -s login_flow.yaml -p ./my_app
  ooda scene -s test.yaml -v --keep-running

RUN
---
Start a Flutter run session with OODA control.

  ooda run [options]

Options:
  -p, --project DIR     Flutter project directory (default: .)
  -d, --device DEV      Device ID (auto-selects if not specified)
  -t, --target FILE     Target file to run (default: lib/main.dart)
      --flavor NAME     Build flavor to use
  -r, --hot-reload      Trigger hot reload after app starts
  -s, --screenshot      Take screenshot after app starts
      --screenshot-output FILE  Output path for screenshot
  -w, --widget-tree     Dump widget tree after app starts
  -i, --interactive     Keep session running for interactive commands

Interactive mode keys:
  r - Hot reload
  R - Hot restart
  s - Take screenshot
  w - Dump widget tree
  q - Quit

Examples:
  ooda run -p ./my_app
  ooda run -i -w
  ooda run --flavor dev

OBSERVE
-------
Capture an observation bundle from a running Flutter app.

  ooda observe [options]

Options:
  -p, --project DIR     Flutter project directory (default: .)
  -d, --device DEV      Device ID (auto-selects if not specified)
  -s, --scene NAME      Scene name for the observation (default: manual)
  -c, --checkpoint NAME Checkpoint name (default: observation)
  -o, --output DIR      Output directory (default: obs)
  -w, --wait-stable     Wait for visual stability (default: true)
  -t, --timeout SEC     Timeout in seconds (default: 5)
      --start-app       Start the Flutter app if not running
      --[no-]widget-tree   Capture widget tree (default: true)
      --[no-]semantics     Capture semantics tree (default: true)
      --[no-]logs          Capture device logs (default: true)

Examples:
  ooda observe --start-app -p ./my_app
  ooda observe -c after_login -s login_flow
  ooda observe --no-logs --no-widget-tree

INFO
----
Display documentation and usage examples.

  ooda info [options]

Options:
      --commands       Show this detailed command reference
      --scene-yaml     Show scene YAML format reference
      --observations   Show observation bundle structure

Examples:
  ooda info
  ooda info --commands
  ooda info --scene-yaml
''');
  }
}
