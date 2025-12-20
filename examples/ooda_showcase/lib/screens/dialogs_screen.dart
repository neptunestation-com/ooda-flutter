import 'package:flutter/material.dart';

import '../app.dart';

/// Dialogs screen demonstrating overlay detection.
class DialogsScreen extends StatelessWidget {
  const DialogsScreen({super.key, required this.variant});

  final AppVariant variant;

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alert Dialog'),
        content: const Text('This is an alert dialog. It appears as an overlay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bottom Sheet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('This is a modal bottom sheet overlay.'),
            const SizedBox(height: 24),
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

  void _showTimePicker(BuildContext context) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  void _showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This is a snackbar message'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dialogs')),
      body: variant == AppVariant.polished
          ? _PolishedDialogs(
              onAlertDialog: () => _showAlertDialog(context),
              onBottomSheet: () => _showBottomSheet(context),
              onDatePicker: () => _showDatePicker(context),
              onTimePicker: () => _showTimePicker(context),
              onSnackBar: () => _showSnackBar(context),
            )
          : _MinimalDialogs(
              onAlertDialog: () => _showAlertDialog(context),
              onBottomSheet: () => _showBottomSheet(context),
              onDatePicker: () => _showDatePicker(context),
              onTimePicker: () => _showTimePicker(context),
              onSnackBar: () => _showSnackBar(context),
            ),
    );
  }
}

class _MinimalDialogs extends StatelessWidget {
  const _MinimalDialogs({
    required this.onAlertDialog,
    required this.onBottomSheet,
    required this.onDatePicker,
    required this.onTimePicker,
    required this.onSnackBar,
  });

  final VoidCallback onAlertDialog;
  final VoidCallback onBottomSheet;
  final VoidCallback onDatePicker;
  final VoidCallback onTimePicker;
  final VoidCallback onSnackBar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton(
          onPressed: onAlertDialog,
          child: const Text('Show AlertDialog'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onBottomSheet,
          child: const Text('Show BottomSheet'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onDatePicker,
          child: const Text('Show DatePicker'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onTimePicker,
          child: const Text('Show TimePicker'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onSnackBar,
          child: const Text('Show SnackBar'),
        ),
      ],
    );
  }
}

class _PolishedDialogs extends StatelessWidget {
  const _PolishedDialogs({
    required this.onAlertDialog,
    required this.onBottomSheet,
    required this.onDatePicker,
    required this.onTimePicker,
    required this.onSnackBar,
  });

  final VoidCallback onAlertDialog;
  final VoidCallback onBottomSheet;
  final VoidCallback onDatePicker;
  final VoidCallback onTimePicker;
  final VoidCallback onSnackBar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DialogCard(
          icon: Icons.warning_amber_outlined,
          title: 'Alert Dialog',
          description: 'Standard modal dialog with actions',
          onTap: onAlertDialog,
        ),
        _DialogCard(
          icon: Icons.drag_handle,
          title: 'Bottom Sheet',
          description: 'Modal sheet from bottom',
          onTap: onBottomSheet,
        ),
        _DialogCard(
          icon: Icons.calendar_today,
          title: 'Date Picker',
          description: 'Material date selection',
          onTap: onDatePicker,
        ),
        _DialogCard(
          icon: Icons.access_time,
          title: 'Time Picker',
          description: 'Material time selection',
          onTap: onTimePicker,
        ),
        _DialogCard(
          icon: Icons.notifications_outlined,
          title: 'SnackBar',
          description: 'Temporary message at bottom',
          onTap: onSnackBar,
        ),
      ],
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
