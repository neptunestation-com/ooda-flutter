import 'package:flutter/material.dart';

void main() {
  runApp(const GesturesApp());
}

class GesturesApp extends StatelessWidget {
  const GesturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestures Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const GesturesTestScreen(),
    );
  }
}

class GesturesTestScreen extends StatefulWidget {
  const GesturesTestScreen({super.key});

  @override
  State<GesturesTestScreen> createState() => _GesturesTestScreenState();
}

class _GesturesTestScreenState extends State<GesturesTestScreen> {
  String _lastGesture = 'None';
  Offset _lastPosition = Offset.zero;
  int _tapCount = 0;

  void _updateGesture(String gesture, [Offset? position]) {
    setState(() {
      _lastGesture = gesture;
      if (position != null) {
        _lastPosition = position;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestures Test')),
      body: GestureDetector(
        onTap: () {
          _tapCount++;
          _updateGesture('Tap #$_tapCount');
        },
        onDoubleTap: () => _updateGesture('Double Tap'),
        onLongPress: () => _updateGesture('Long Press'),
        onPanStart: (details) =>
            _updateGesture('Pan Start', details.localPosition),
        onPanUpdate: (details) =>
            _updateGesture('Pan Update', details.localPosition),
        onPanEnd: (_) => _updateGesture('Pan End'),
        child: Container(
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Last Gesture:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _lastGesture,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Position: (${_lastPosition.dx.toInt()}, ${_lastPosition.dy.toInt()})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                const Text('Try: tap, double-tap, long-press, or drag'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
