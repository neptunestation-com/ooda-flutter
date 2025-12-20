import 'package:flutter/material.dart';

import '../app.dart';

/// Item list screen demonstrating scrolling and swipe gestures.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.variant});

  final AppVariant variant;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _scrollController = ScrollController();
  bool _isRefreshing = false;

  static const _itemCount = 100;

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item List')),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: widget.variant == AppVariant.polished
            ? _PolishedList(
                scrollController: _scrollController,
                itemCount: _itemCount,
              )
            : _MinimalList(
                scrollController: _scrollController,
                itemCount: _itemCount,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        },
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }
}

class _MinimalList extends StatelessWidget {
  const _MinimalList({
    required this.scrollController,
    required this.itemCount,
  });

  final ScrollController scrollController;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text('Item ${index + 1}'),
          subtitle: Text('Description for item ${index + 1}'),
          onTap: () {},
        );
      },
    );
  }
}

class _PolishedList extends StatelessWidget {
  const _PolishedList({
    required this.scrollController,
    required this.itemCount,
  });

  final ScrollController scrollController;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final colors = [
          colorScheme.primaryContainer,
          colorScheme.secondaryContainer,
          colorScheme.tertiaryContainer,
        ];
        final color = colors[index % colors.length];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text('${index + 1}'),
            ),
            title: Text('Item ${index + 1}'),
            subtitle: Text('This is a detailed description for item ${index + 1}'),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {},
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}
