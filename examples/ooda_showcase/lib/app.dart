import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/dialogs_screen.dart';
import 'screens/forms_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/navigation_screen.dart';
import 'theme.dart';

/// App variant for styling.
enum AppVariant { minimal, polished }

/// Global navigator key for programmatic navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Main app widget.
class OodaShowcaseApp extends StatefulWidget {
  const OodaShowcaseApp({super.key, this.variant = AppVariant.minimal});

  final AppVariant variant;

  @override
  State<OodaShowcaseApp> createState() => _OodaShowcaseAppState();
}

class _OodaShowcaseAppState extends State<OodaShowcaseApp>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('ooda.showcase/navigation');
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupDeepLinkHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setupDeepLinkHandling() async {
    // Handle initial deep link (app started via deep link)
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null) {
        final route = _parseDeepLink(initialLink);
        if (route != null) {
          setState(() => _initialRoute = route);
        }
      }
    } on MissingPluginException {
      // Method channel not implemented on this platform, use platform default
      _initialRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (_initialRoute == '/') _initialRoute = null;
    }

    // Handle incoming deep links while app is running
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final link = call.arguments as String?;
        if (link != null) {
          final route = _parseDeepLink(link);
          if (route != null) {
            _navigateTo(route);
          }
        }
      }
      return null;
    });
  }

  String? _parseDeepLink(String link) {
    // Parse ooda://showcase/route format
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    if (uri.scheme == 'ooda' && uri.host == 'showcase') {
      // The path is the route (e.g., /login, /items)
      return uri.path.isNotEmpty ? uri.path : '/';
    }
    return null;
  }

  void _navigateTo(String route) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      // Clear stack and navigate to new route
      navigator.pushNamedAndRemoveUntil(route, (r) => false);
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    // Handle route pushed from platform
    final route = routeInformation.uri.path;
    if (route.isNotEmpty && route != '/') {
      _navigateTo(route);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'OODA Showcase',
      debugShowCheckedModeBanner: false,
      theme: widget.variant == AppVariant.polished
          ? OodaTheme.light
          : ThemeData.light(useMaterial3: true),
      darkTheme: widget.variant == AppVariant.polished
          ? OodaTheme.dark
          : ThemeData.dark(useMaterial3: true),
      initialRoute: _initialRoute ?? '/',
      onGenerateRoute: (settings) => _generateRoute(settings, widget.variant),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings, AppVariant variant) {
    final routes = <String, WidgetBuilder>{
      '/': (context) => HomeScreen(variant: variant),
      '/login': (context) => LoginScreen(variant: variant),
      '/items': (context) => ListScreen(variant: variant),
      '/dialogs': (context) => DialogsScreen(variant: variant),
      '/forms': (context) => FormsScreen(variant: variant),
      '/navigation': (context) => NavigationScreen(variant: variant),
    };

    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return null;
  }
}
