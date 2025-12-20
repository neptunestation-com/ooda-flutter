import 'package:flutter/material.dart';

import '../app.dart';

/// Forms screen demonstrating validation and input types.
class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key, required this.variant});

  final AppVariant variant;

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedOption;
  bool _agreeToTerms = false;
  String? _submissionStatus;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        setState(() => _submissionStatus = 'Please agree to terms');
        return;
      }
      setState(() => _submissionStatus = 'Form submitted successfully!');
    } else {
      setState(() => _submissionStatus = 'Please fix validation errors');
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _messageController.clear();
    setState(() {
      _selectedOption = null;
      _agreeToTerms = false;
      _submissionStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forms'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: Form(
        key: _formKey,
        child: widget.variant == AppVariant.polished
            ? _PolishedForm(
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                messageController: _messageController,
                selectedOption: _selectedOption,
                agreeToTerms: _agreeToTerms,
                submissionStatus: _submissionStatus,
                onOptionChanged: (v) => setState(() => _selectedOption = v),
                onAgreeChanged: (v) =>
                    setState(() => _agreeToTerms = v ?? false),
                onSubmit: _submit,
              )
            : _MinimalForm(
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                messageController: _messageController,
                selectedOption: _selectedOption,
                agreeToTerms: _agreeToTerms,
                submissionStatus: _submissionStatus,
                onOptionChanged: (v) => setState(() => _selectedOption = v),
                onAgreeChanged: (v) =>
                    setState(() => _agreeToTerms = v ?? false),
                onSubmit: _submit,
              ),
      ),
    );
  }
}

class _MinimalForm extends StatelessWidget {
  const _MinimalForm({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.messageController,
    required this.selectedOption,
    required this.agreeToTerms,
    required this.submissionStatus,
    required this.onOptionChanged,
    required this.onAgreeChanged,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController messageController;
  final String? selectedOption;
  final bool agreeToTerms;
  final String? submissionStatus;
  final ValueChanged<String?> onOptionChanged;
  final ValueChanged<bool?> onAgreeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name *'),
          textInputAction: TextInputAction.next,
          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email *'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              v == null || !v.contains('@') ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedOption,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('General')),
            DropdownMenuItem(value: 'support', child: Text('Support')),
            DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
          ],
          onChanged: onOptionChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message *',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          validator: (v) =>
              v == null || v.isEmpty ? 'Message is required' : null,
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('I agree to the terms and conditions'),
          value: agreeToTerms,
          onChanged: onAgreeChanged,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onSubmit, child: const Text('Submit')),
        if (submissionStatus != null) ...[
          const SizedBox(height: 16),
          Text(submissionStatus!, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _PolishedForm extends StatelessWidget {
  const _PolishedForm({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.messageController,
    required this.selectedOption,
    required this.agreeToTerms,
    required this.submissionStatus,
    required this.onOptionChanged,
    required this.onAgreeChanged,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController messageController;
  final String? selectedOption;
  final bool agreeToTerms;
  final String? submissionStatus;
  final ValueChanged<String?> onOptionChanged;
  final ValueChanged<bool?> onAgreeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedOption,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(
                      value: 'feedback',
                      child: Text('Feedback'),
                    ),
                  ],
                  onChanged: onOptionChanged,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Message is required' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('I agree to the terms and conditions'),
          value: agreeToTerms,
          onChanged: onAgreeChanged,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.send),
          label: const Text('Submit'),
        ),
        if (submissionStatus != null) ...[
          const SizedBox(height: 16),
          Card(
            color: submissionStatus!.contains('success')
                ? colorScheme.primaryContainer
                : colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(submissionStatus!, textAlign: TextAlign.center),
            ),
          ),
        ],
      ],
    );
  }
}
