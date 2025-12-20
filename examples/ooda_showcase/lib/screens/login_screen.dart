import 'package:flutter/material.dart';

import '../app.dart';

/// Login screen demonstrating form inputs and keyboard interactions.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.variant});

  final AppVariant variant;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _status;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _status = 'Logging in...');
      // Simulate login delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _status = 'Login successful!');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: widget.variant == AppVariant.polished
          ? _PolishedLoginForm(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              rememberMe: _rememberMe,
              obscurePassword: _obscurePassword,
              status: _status,
              onRememberMeChanged: (v) =>
                  setState(() => _rememberMe = v ?? false),
              onObscurePasswordToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onSubmit: _submit,
            )
          : _MinimalLoginForm(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              rememberMe: _rememberMe,
              obscurePassword: _obscurePassword,
              status: _status,
              onRememberMeChanged: (v) =>
                  setState(() => _rememberMe = v ?? false),
              onObscurePasswordToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onSubmit: _submit,
            ),
    );
  }
}

class _MinimalLoginForm extends StatelessWidget {
  const _MinimalLoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.obscurePassword,
    required this.status,
    required this.onRememberMeChanged,
    required this.onObscurePasswordToggle,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool obscurePassword;
  final String? status;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onObscurePasswordToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: onObscurePasswordToggle,
              ),
            ),
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            validator: (v) => v == null || v.length < 6
                ? 'Password must be 6+ characters'
                : null,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Remember me'),
            value: rememberMe,
            onChanged: onRememberMeChanged,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onSubmit, child: const Text('Login')),
          if (status != null) ...[
            const SizedBox(height: 16),
            Text(status!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: () {}, child: const Text('Forgot password?')),
        ],
      ),
    );
  }
}

class _PolishedLoginForm extends StatelessWidget {
  const _PolishedLoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.obscurePassword,
    required this.status,
    required this.onRememberMeChanged,
    required this.onObscurePasswordToggle,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool obscurePassword;
  final String? status;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onObscurePasswordToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
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
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: onObscurePasswordToggle,
                      ),
                    ),
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmit(),
                    validator: (v) => v == null || v.length < 6
                        ? 'Password must be 6+ characters'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Remember me'),
                    value: rememberMe,
                    onChanged: onRememberMeChanged,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSubmit,
                      child: const Text('Login'),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 16),
                    Text(status!, style: TextStyle(color: colorScheme.primary)),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
