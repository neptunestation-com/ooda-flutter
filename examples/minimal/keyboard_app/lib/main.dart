import 'package:flutter/material.dart';

void main() {
  runApp(const KeyboardApp());
}

class KeyboardApp extends StatelessWidget {
  const KeyboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyboard Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const KeyboardTestScreen(),
    );
  }
}

class KeyboardTestScreen extends StatefulWidget {
  const KeyboardTestScreen({super.key});

  @override
  State<KeyboardTestScreen> createState() => _KeyboardTestScreenState();
}

class _KeyboardTestScreenState extends State<KeyboardTestScreen> {
  final _controller1 = TextEditingController();
  final _controller2 = TextEditingController();
  final _controller3 = TextEditingController();
  String _status = 'Ready';

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _status = 'Submitted: ${_controller1.text}, ${_controller2.text}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller1,
              decoration: const InputDecoration(
                labelText: 'Text field 1',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller2,
              decoration: const InputDecoration(
                labelText: 'Text field 2',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller3,
              decoration: const InputDecoration(
                labelText: 'Multiline field',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Submit')),
            const SizedBox(height: 16),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
