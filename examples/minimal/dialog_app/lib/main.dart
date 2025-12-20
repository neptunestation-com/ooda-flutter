import 'package:flutter/material.dart';

void main() {
  runApp(const DialogApp());
}

class DialogApp extends StatelessWidget {
  const DialogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dialog Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const DialogTestScreen(),
    );
  }
}

class DialogTestScreen extends StatelessWidget {
  const DialogTestScreen({super.key});

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alert'),
        content: const Text('This is an alert dialog'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Bottom Sheet', style: TextStyle(fontSize: 20)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dialog Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showAlertDialog(context),
              child: const Text('Show AlertDialog'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showBottomSheet(context),
              child: const Text('Show BottomSheet'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showDatePicker(context),
              child: const Text('Show DatePicker'),
            ),
          ],
        ),
      ),
    );
  }
}
