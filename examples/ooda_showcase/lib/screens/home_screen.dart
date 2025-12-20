import 'package:flutter/material.dart';

import '../app.dart';

/// Home screen with navigation to all features.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.variant});

  final AppVariant variant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          variant == AppVariant.polished ? 'OODA Showcase' : 'Showcase',
        ),
      ),
      body: variant == AppVariant.polished ? _PolishedHome() : _MinimalHome(),
    );
  }
}

class _MinimalHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _NavButton(title: 'Login', route: '/login'),
        _NavButton(title: 'Item List', route: '/items'),
        _NavButton(title: 'Dialogs', route: '/dialogs'),
        _NavButton(title: 'Forms', route: '/forms'),
        _NavButton(title: 'Navigation', route: '/navigation'),
      ],
    );
  }
}

class _PolishedHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _NavCard(
          title: 'Login',
          subtitle: 'Form inputs & keyboard',
          icon: Icons.login,
          color: colorScheme.primaryContainer,
          route: '/login',
        ),
        _NavCard(
          title: 'Item List',
          subtitle: 'Scrolling & swipes',
          icon: Icons.list,
          color: colorScheme.secondaryContainer,
          route: '/items',
        ),
        _NavCard(
          title: 'Dialogs',
          subtitle: 'Overlays & modals',
          icon: Icons.chat_bubble_outline,
          color: colorScheme.tertiaryContainer,
          route: '/dialogs',
        ),
        _NavCard(
          title: 'Forms',
          subtitle: 'Validation & inputs',
          icon: Icons.edit_note,
          color: colorScheme.primaryContainer,
          route: '/forms',
        ),
        _NavCard(
          title: 'Navigation',
          subtitle: 'Drawer, tabs & back',
          icon: Icons.menu,
          color: colorScheme.secondaryContainer,
          route: '/navigation',
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, route),
        child: Text(title),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
