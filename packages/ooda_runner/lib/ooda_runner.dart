/// CLI tool for AI-driven Flutter OODA loop - the control plane for automated UI testing.
library ooda_runner;

// Re-export shared types
export 'package:ooda_shared/ooda_shared.dart';

// ADB
export 'src/adb/adb_client.dart';
export 'src/adb/device_manager.dart';

// Barriers
export 'src/barriers/barrier.dart';
export 'src/barriers/device_ready_barrier.dart';
export 'src/barriers/app_ready_barrier.dart';
export 'src/barriers/visual_stability_barrier.dart';

// Daemon
export 'src/daemon/json_rpc_protocol.dart';
export 'src/daemon/flutter_daemon_client.dart';
export 'src/daemon/vm_service_client.dart';

// Runner
export 'src/runner/flutter_session.dart';

// Observation
export 'src/observation/device_camera.dart';
export 'src/observation/flutter_camera.dart';
export 'src/observation/image_utils.dart';
export 'src/observation/overlay_detector.dart';
export 'src/observation/observation_bundle.dart';

// Scenes
export 'src/scenes/scene_parser.dart';
export 'src/scenes/scene_executor.dart';

// Interaction
export 'src/interaction/interaction_controller.dart';
